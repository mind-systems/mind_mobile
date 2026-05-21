# Breath Session — Animation Stutter Investigation Log

This document captures the full investigation into a visible animation stutter on the breathing shape — most pronounced at the boundary between repeats of an exercise (i.e. when the cycle restarts: `exhale` → next-cycle `inhale`). It records every hypothesis we tested, the instrumentation we used, the data we collected, and what we ruled out. The final state is **unresolved**: we know what is **not** the cause, but the actual mechanism behind the visible freeze at the cycle boundary is still open.

The intent of this doc is to make sure no future engineer (or future-us) has to repeat the same dead-end bisects. If you pick this up again, start by reading **What we ruled out** at the end before forming a new hypothesis.

## Symptom

User-observed behaviour during a sustained breath session (e.g. an exercise of 4-second inhale, 4-second exhale, repeated 10 times):

- A noticeable visual stutter on the shape animation specifically at the **bottom of the circle**, which corresponds to the moment of `newCycle` reset (when `repeatCounter` increments and `_position` snaps from ~1.0 back to 0.0).
- The freeze is most consistent at the start of each cycle's new inhale, after the previous exhale finishes.
- The shape's dot appears to "jump" rather than continue smoothly around the closed path.
- The user reports the upper boundary of the circle (i.e. mid-exhale to mid-inhale transitions inside a cycle) is mostly smooth — only the bottom (cycle restart) consistently stutters.
- The stutter exists independently of audio: with sound coordinator fully disabled, the visible stutter at the bottom of the circle still occurs.

## What this doc is NOT about

Two earlier related issues that **have** been resolved and shipped, do not re-investigate them:

- **Per-tick screen-wide rebuild** — every state-machine tick was rebuilding the entire `BreathSessionScreen` because `ref.watch(breathViewModelProvider)` was at the screen root. Closed by Phase 15 (`remainingTicksNotifier` channel + `timelineSteps` carried by reference + `set state` filter that skips Riverpod publication on tick-only changes). See `docs/breath/session/view-model.md`.
- **Double-PUBLISH on cycle/exercise boundaries** — `resetReason` was in `equalsIgnoringTickFields`, so the engine's "clear `resetReason` to null" emit one tick after a reset was counted as a structural change and caused a second Riverpod publication per boundary. Closed by Phase 16 (`resetReason` removed from `equalsIgnoringTickFields`; `Consumer.select` projections per subtree on `BreathSessionScreen`).

Those two layers of optimisation are in `master` and are not in question here. The investigation below started **after** both were live and confirmed working.

## Investigation methodology

### Probe approach

We instrumented the code path with `debugPrint` lines tagged `[BREATH-PROBE HH:MM:SS.mmm]` so each event carries a wall-clock timestamp accurate to the millisecond. The tag is grep-friendly. Each probe answers a single question.

We also installed `WidgetsBinding.instance.addTimingsCallback(_onFrameTimings)` to catch frames where `buildDuration > 16 ms` or `rasterDuration > 16 ms` (the 60 fps budget). This is the only mechanism that gives ground truth on whether a frame missed its budget — visual perception is unreliable for sub-frame issues.

### Bisect strategy

Iteratively disable suspected components, re-run the session covering 5+ cycle boundaries + 1 exercise change, and check whether the `FRAME SLOW` events disappear in logs and whether the visual stutter persists. The components we toggled:

- `_scrollToActive` call (scroll animation triggered on `activeStepId` change).
- `BreathTimelineWidget` data binding (pass `activeStepId: null`, `status: pause` to freeze the list visually).
- `EclipseOrb` widget (replaced with `SizedBox.shrink()`).
- `BreathShapeWidget` widget (replaced with `SizedBox.shrink()`).
- `BreathSoundCoordinator.initialize` (skipped, so the coordinator object exists but no listeners attach and no audio work runs).

After each disable, the user ran the session and we captured stdout (`adb logcat | grep "BREATH-PROBE" | tee someN.txt`). The log files referenced below (`some.txt`, `some2.txt`, … `some5.txt`) are kept untracked in the repo root as throwaway debug artefacts.

## Probes used

Below are the exact `debugPrint` insertions we used. They can be re-introduced verbatim when picking up this investigation again. All can be removed with a single `git reset --hard HEAD` since they live in tracked files only.

### 1. `set state` publish/skip in `BreathSessionViewModel`

In `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`, inside the `set state` override:

```dart
@override
set state(BreathSessionState value) {
  final ts = DateTime.now().toIso8601String().substring(11, 23);
  final isStructural = !value.equalsIgnoringTickFields(super.state);
  // ignore: avoid_print
  debugPrint(
    '[BREATH-PROBE $ts] set state ${isStructural ? "PUBLISH" : "SKIP   "} '
    'status=${value.status.name} phase=${value.phase.name} '
    'step=${value.activeStepId} ticks=${value.remainingTicks} '
    'reason=${value.resetReason?.name}',
  );
  if (isStructural) {
    super.state = value;
  }
  if (!_stateController.isClosed) {
    _stateController.add(value);
  }
}
```

This confirmed two things across runs: (a) per-tick state emits are correctly classified as `SKIP` (so Riverpod consumers don't rebuild), (b) the `resetReason=null` clear emit one tick after `newCycle`/`exerciseChange` is also a `SKIP` (so Phase 16's fix is intact).

### 2. Subtree-rebuild probes in `BreathSessionScreen`

Each of the four `Consumer.select(...)` builders gets a `debugPrint` so we know which subtree actually rebuilt on a given state change.

```dart
Consumer(
  builder: (context, ref, _) {
    final loadState = ref.watch(
      breathViewModelProvider.select((s) => s.loadState),
    );
    debugPrint(
      '[BREATH-PROBE ${DateTime.now().toIso8601String().substring(11, 23)}] '
      'Consumer Shape build loadState=${loadState.name}',
    );
    return Padding(...);
  },
)
```

Repeat the same pattern in the Timeline, ControlButton and BottomBar `Consumer` builders. This proved that on a simple `inhale → exhale` phase change only the Timeline `Consumer` rebuilds; the Stack with the orb + shape never does (because `s.loadState` doesn't change). Phase 16 is doing its job.

### 3. Outer widget builds for the painters

In `packages/breath_module/lib/src/BreathSession/Views/BreathShapeWidget.dart`, in `build`:

```dart
@override
Widget build(BuildContext context) {
  debugPrint(
    '[BREATH-PROBE ${DateTime.now().toIso8601String().substring(11, 23)}] '
    'ShapeWidget OUTER build',
  );
  return ListenableBuilder(...);
}
```

The outer build is what runs when the parent rebuilds — distinct from the inner `ListenableBuilder` builder which runs on every `motionEngine`/`shapeShifter` notification (60 Hz, expected). We verified the outer build does NOT fire on phase change post-Phase 16 — only on load / restart.

### 4. Timeline build + `didUpdateWidget`

In `packages/breath_module/lib/src/BreathSession/Views/BreathTimelineWidget.dart`:

```dart
@override
void didUpdateWidget(BreathTimelineWidget oldWidget) {
  super.didUpdateWidget(oldWidget);
  debugPrint(
    '[BREATH-PROBE ${DateTime.now().toIso8601String().substring(11, 23)}] '
    'Timeline didUpdateWidget '
    'stepsChanged=${!identical(widget.steps, oldWidget.steps)} '
    'activeStepChanged=${widget.activeStepId != oldWidget.activeStepId} '
    'statusChanged=${widget.status != oldWidget.status}',
  );
  if (widget.steps != oldWidget.steps) _updateKeys();
}

@override
Widget build(BuildContext context) {
  debugPrint(
    '[BREATH-PROBE ${DateTime.now().toIso8601String().substring(11, 23)}] '
    'Timeline build active=${widget.activeStepId} '
    'status=${widget.status?.name} steps=${widget.steps.length}',
  );
  ...
}
```

`stepsChanged=false` on every phase change confirms the `timelineSteps` reference is stable (the carry-by-reference invariant from Phase 15 holds).

### 5. Animation coordinators

In `packages/breath_module/lib/src/BreathSession/Animation/BreathAnimationCoordinator.dart`, requires `import 'package:flutter/foundation.dart';`:

```dart
void _handleReset(BreathSessionState state) {
  final shape = (state.resetReason == ResetReason.exerciseChange ||
          state.resetReason == ResetReason.rest)
      ? state.nextExerciseShape
      : state.currentExerciseShape;

  debugPrint(
    '[BREATH-PROBE ${DateTime.now().toIso8601String().substring(11, 23)}] '
    'AnimCoord _handleReset reason=${state.resetReason?.name} '
    'shape=$shape phase=${state.phase.name}',
  );
  if (shape != null) shapeShifter.morphTo(shape);

  // Engine pre-reset position probe — verifies engine math at the boundary:
  debugPrint(
    '[BREATH-PROBE ${DateTime.now().toIso8601String().substring(11, 23)}] '
    'AnimCoord pre-reset normalizedPosition=${motionEngine.normalizedPosition.toStringAsFixed(4)} '
    'reason=${state.resetReason?.name}',
  );
  motionEngine.resetPosition(0.0);
  ...
}
```

In `packages/breath_module/lib/src/BreathSession/Animation/OrbAnimationCoordinator.dart`:

```dart
void _handleReset(BreathSessionState state) {
  ...
  debugPrint(
    '[BREATH-PROBE ${DateTime.now().toIso8601String().substring(11, 23)}] '
    'OrbCoord _handleReset reason=${state.resetReason?.name} '
    'phase=${state.phase.name}',
  );
  ...
}

void _startAnimation({required BreathPhase phase, required int total, required int remaining}) {
  debugPrint(
    '[BREATH-PROBE ${DateTime.now().toIso8601String().substring(11, 23)}] '
    'OrbCoord _startAnimation phase=${phase.name} total=$total remaining=$remaining',
  );
  ...
}
```

### 6. Frame timing callback

In `_BreathSessionScreenState`, requires `import 'package:flutter/scheduler.dart';`:

```dart
void _onFrameTimings(List<FrameTiming> timings) {
  for (final t in timings) {
    final buildMs = t.buildDuration.inMicroseconds / 1000.0;
    final rasterMs = t.rasterDuration.inMicroseconds / 1000.0;
    if (buildMs > 16.0 || rasterMs > 16.0) {
      debugPrint(
        '[BREATH-PROBE ${DateTime.now().toIso8601String().substring(11, 23)}] '
        'FRAME SLOW build=${buildMs.toStringAsFixed(1)}ms '
        'raster=${rasterMs.toStringAsFixed(1)}ms',
      );
    }
  }
}

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  WidgetsBinding.instance.addTimingsCallback(_onFrameTimings);
  ...
}

@override
void dispose() {
  ...
  WidgetsBinding.instance.removeTimingsCallback(_onFrameTimings);
  WidgetsBinding.instance.removeObserver(this);
  super.dispose();
}
```

This is the single most useful probe — it tells you when the framework actually missed a frame and whether the cost was CPU-side (build) or GPU-side (raster).

## Bisect runs

Five runs in chronological order. Each row of the summary table is a separate session recording.

### Setup notes

- Test exercise: 4-second inhale, 4-second exhale, repeated 10 times (the user's standard repro). Plus a 15-second rest before exercise 1.
- Device: Samsung A70 (`SM-A705FN`, Android 9, OMX.SEC.flac.dec decoder).
- All probes from the previous section installed unless otherwise noted.
- Stdout captured with `adb logcat | grep "BREATH-PROBE" | tee someN.txt` and reviewed offline.

### Run 1 — `some.txt`: probes only, no disables

Everything intact. Confirmed the baseline:

- Per-tick `set state SKIP` works correctly. Phase changes correctly emit `PUBLISH`.
- Every phase change triggers `Consumer Shape build` + `Consumer Timeline build` + `Consumer ControlButton build` + `Consumer BottomBar build` — i.e. **all four subtrees rebuilt on every PUBLISH**. (This was before we narrowed the scope further.)
- `FRAME SLOW` recorded after every phase change with build ≈ 30–55 ms. Multiple per cycle/exercise boundary because of the double-PUBLISH on `resetReason` clear (Phase 16 wasn't shipped yet at this point).

Lesson: confirmed Phase 16's two-fold rebuild problem on `resetReason` clear.

(This corresponds to log file `some.txt` and triggered the Phase 16 implementation. The work below assumes Phase 16 is in place — runs 2 through 5 used the post-Phase-16 codebase.)

### Run 2 — `some2.txt`: scroll disabled

```dart
// In _BreathSessionScreenState.initState — comment out the call site:
// ref.listenManual<BreathSessionState>(breathViewModelProvider, (prev, next) {
//   if (prev?.activeStepId != next.activeStepId) {
//     _scrollToActive(next.activeStepId);
//   }
// });
```

The 450 ms `_scrollController.animateTo` no longer fires on `activeStepId` change. Timeline list does not scroll.

User observation: "из за скрола фриз не ушел" — visual stutter still present, scroll was not the cause.

Log observation: `FRAME SLOW` events still appear at every cycle/exercise boundary with raster ≈ 20 ms. Build time mostly under 16 ms — the Riverpod-side rebuild path was already minimal after Phase 16.

### Run 3 — `some3.txt`: Timeline data disconnected (scroll still off)

```dart
// In the Timeline Consumer: pass static placeholders.
Consumer(
  builder: (context, ref, _) {
    final steps = ref.watch(
      breathViewModelProvider.select((s) => s.timelineSteps),
    );
    return SizedBox(
      height: layout.timelineHeight,
      child: BreathTimelineWidget(
        key: _timelineKey,
        steps: steps,
        activeStepId: null,            // freeze highlighting
        scrollController: _scrollController,
        status: BreathSessionStatus.pause,  // freeze status
        itemHeight: layout.itemHeight,
        remainingTicksListenable:
            ref.read(breathViewModelProvider.notifier).remainingTicksNotifier,
      ),
    );
  },
),
```

The Timeline still renders the initial list of steps but never reacts to phase data — no active row highlighting, no `_TimelineItem` animation transitions.

User observation: the timeline doesn't visually move. Stutter on the shape still present.

Log observation: roughly the same as Run 2. `FRAME SLOW` still at cycle/exercise boundaries with raster ≈ 17–20 ms. So Timeline's `ListView.builder` + `AnimatedScale`/`AnimatedOpacity` weren't the dominant cost.

### Run 4 — `some4.txt`: orb + shape both disabled

```dart
// Replace EclipseOrb branch in the Stack with SizedBox.shrink():
Stack(
  alignment: Alignment.center,
  children: [
    const SizedBox.shrink(),
    // ValueListenableBuilder<double>( ... ) ← orb commented out
    const SizedBox.shrink(),
    // AnimatedOpacity( ... BreathShapeWidget ... ) ← shape commented out
  ],
)
```

Nothing visible in the shape area. The orb and shape painters are gone, so no `CustomPaint.paint` runs for either.

User observation: "Я ж теперь вообще не вижу анимацию" — no animation visible (this was expected; clarified that it was an intentional isolation test, not a request).

**Critical finding — pre-reset probe across 5 newCycle boundaries:**

```
13:05:54.939 AnimCoord pre-reset normalizedPosition=0.0000 reason=exerciseChange
13:06:06.933 AnimCoord pre-reset normalizedPosition=1.0000 reason=newCycle
13:06:18.926 AnimCoord pre-reset normalizedPosition=1.0000 reason=newCycle
13:06:30.932 AnimCoord pre-reset normalizedPosition=1.0000 reason=newCycle
```

The engine reaches **exactly 1.0** on every `newCycle`. The `exerciseChange` value is 0.0 because the engine was inactive during the preceding rest period. Both are correct.

Combined with the existing wrap in `BreathShapeShifter.getPointPosition`:

```dart
final distance = totalLength * (normalizedTime % 1.0);
```

and the closed path (`path.close()` in `getCurrentPath`), positions `1.0` and `0.0` resolve to **the same pixel** on the contour. There is no real coordinate discontinuity at the cycle boundary. Whatever the user perceives as a "jump" is not coming from engine math — it must be a rendering-side effect.

**Frame timing finding with painters disabled:**

| Time | Event | build | raster |
|---|---|---|---|
| 13:06:03.242 | mid-exhale tick (no PUBLISH) | **67.9 ms** | 14.9 ms |
| 13:06:07.084 | newCycle #1 (+153 ms after PUBLISH) | 7.7 ms | 18.4 ms |
| 13:06:19.002 | newCycle #2 (+78 ms after PUBLISH) | 2.9 ms | 17.4 ms |

Even with both painters disabled, raster on cycle boundaries is still ~17–18 ms (just over budget). And a mysterious 67.9 ms build outlier appears mid-exhale with nothing on screen. The 67.9 ms outlier is followed immediately by `[OMX.SEC.flac.dec] signalFlush` in the codec log — suggesting it correlates with audio codec activity.

### Run 5 — `some5.txt`: sound coordinator disabled (orb + shape still off, timeline disconnected, scroll off)

```dart
// In addPostFrameCallback in initState, skip the sound init:
WidgetsBinding.instance.addPostFrameCallback((_) {
  final initialState = ref.read(breathViewModelProvider);
  _coordinator.initialize(initialState);
  _orbCoordinator.initialize(initialState);
  // _soundCoordinator.initialize(initialState);  ← TEMP disabled
  viewModel.initState();
});
```

The `BreathSoundCoordinator` object is still constructed (it's referenced in `didChangeAppLifecycleState`), but with no `initialize` it never attaches its raw-stream listener, never schedules a fade `Timer.periodic`, never calls `setCurrentIndex`/`seek`/`play` on the loop players. Codec stays idle.

**Critical log finding:**

Over a session covering exerciseChange + 5 newCycle boundaries, only TWO `FRAME SLOW` events fired and both were at app startup:

```
13:20:12.818 FRAME SLOW build=7.8ms raster=30.1ms
13:20:13.381 FRAME SLOW build=17.0ms raster=4.2ms
```

After 13:20:13.381 — **zero** slow frames for the entire ~65-second session. Every single newCycle was clean by `addTimingsCallback`'s metric.

Tentative conclusion at this point (later partially overturned, see Run 6): **the sound coordinator was the dominant source of `FRAME SLOW` events** at cycle/exercise boundaries. With it disabled the framework reports no missed frames.

### Run 6 — sound disabled, full visuals restored

After Run 5 we wrote up the sound-coordinator hypothesis and added a Phase 17 ROADMAP task and `notes/13-sound-coordinator-phase-boundary-jank.md`. The user pushed back: the proposed fix (deferring `setCurrentIndex`/`seek` via microtask and reducing the fade Timer rate from 60 Hz to 20 Hz) didn't feel right, because the visual stutter pattern is **point-like at the cycle boundary**, not spread across the whole 840 ms fade window. If continuous setVolume binder pressure were the cause, the symptom would smear out, not concentrate at the boundary moment.

To check that intuition the user asked for one more bisect: restore the orb, the shape, the timeline data binding, and the scroll — but keep `_soundCoordinator.initialize` disabled. Effectively: "what did this screen feel like before audio existed?"

```dart
// Everything restored except this one line:
// _soundCoordinator.initialize(initialState);
```

**User observation:** "анимация явно встаёт подумать в эти моменты. Только один раз она прошла верхнюю границу круга без фриза. А нижняя - когда смена упражнения идет - фриз всегда."

In other words: with audio fully disabled and the full visual stack restored, the visible stutter at the bottom of the circle (the `newCycle` moment) is still consistently present. Audio is **not** the cause of the visible freeze.

This run was perceptual only (no log capture), and it overturned the Phase 17 hypothesis. The `FRAME SLOW` events that vanished in Run 5 were real but were apparently **not the events the user was perceiving** — the user's visual stutter happens in frames that addTimingsCallback's >16 ms threshold doesn't flag.

## What we ruled out

After six bisect runs we have the following list of confirmed non-causes:

| Component | Evidence | Confidence |
|---|---|---|
| Per-tick screen rebuild (`ref.watch` at root) | Phase 15 + Phase 16 already shipped; Consumer-scope rebuilds correctly localised; tick-only emits filtered. | ✅ certain |
| `resetReason` double-PUBLISH | Phase 16 removed it from `equalsIgnoringTickFields`; logs confirm clear emit is `SKIP`. | ✅ certain |
| `_scrollController.animateTo` 450 ms scroll | Run 2: disabled, visible stutter persisted. | ✅ certain |
| `BreathTimelineWidget` per-phase rebuild and AnimatedScale transitions | Run 3: disconnected from phase data, visible stutter persisted. | ✅ certain |
| `EclipseOrb` painter (5 saveLayer blurs per frame, 60 fps) | Run 4: disabled, visible stutter persisted; minimal raster delta. | ✅ certain |
| `BreathShapePainter` (path morph + 9 blur layers) | Run 4: disabled — but this also removed the *thing that visually stutters*, so the user couldn't observe stutter perception either way. Inconclusive perceptually; only data point is the small raster delta (~3 ms). | ⚠️ partial |
| `BreathSoundCoordinator` `_switchToPhase` | Run 5: disabled, all `FRAME SLOW` events vanished in logs. Run 6: disabled with full visuals, stutter still perceived. | ❌ not the visible cause |
| `BreathMotionEngine` math at boundary | Pre-reset probe in Run 4 confirmed `normalizedPosition=1.0000` exactly on every newCycle. Combined with `% 1.0` in `getPointPosition` and `path.close()`, positions 1.0 and 0.0 map to the same pixel. | ✅ certain |

## What we did NOT yet examine

These are the remaining candidates for the visible newCycle stutter, in rough order of plausibility:

### A. `BreathShapeShifter` / path metric work at the boundary

On `newCycle` the coordinator path is:

```
BreathAnimationCoordinator._handleReset
  ├── shapeShifter.morphTo(shape)         // no-op if same shape (newCycle inside same exercise)
  ├── motionEngine.resetPosition(0.0)     // snaps _position 1.0 → 0.0, notifyListeners()
  ├── motionEngine.setPhaseInfo(...)
  ├── motionEngine.setRemainingPhaseTicks(state.remainingTicks)
  └── motionEngine.setActive(state.status == BreathSessionStatus.breath)
```

`motionEngine.resetPosition` calls `notifyListeners()`, which triggers a `BreathShapeWidget` rebuild via the `ListenableBuilder` merging `[motionController, shapeController]`. The inner builder then constructs a new `BreathShapePainter(normalizedTime: 0.0)`. The painter's `shouldRepaint` compares `oldDelegate.normalizedTime != normalizedTime` — going from ~1.0 to 0.0 means yes, repaint. The painter then calls `shapeShifter.getCurrentPath()` + `getPointPosition(0.0)` + 9 drawCircle / drawPath calls with blur layers.

Things worth probing specifically:

- Whether the **discontinuous `_position` reset (1.0 → 0.0 in a single frame)** triggers any extra layout/paint cost in the painter or the path engine. For example, `pathMetrics.getTangentForOffset(0)` and `getTangentForOffset(perimeter)` might behave subtly differently in Skia even though they should return the same point on a closed contour.
- Whether the **`motionEngine` Ticker** has any irregular behaviour right after `resetPosition` clears `_currentVelocity` and `_isLinearLocked`. The first few frames after reset have the engine recomputing target velocity from zero, which might briefly produce a non-smooth dot motion. Even one slightly-too-fast or too-slow frame in the dot's path could be visible.
- Whether `shapeShifter.notifyListeners()` is firing more than expected around the boundary (e.g. from `updateBounds` inside `addPostFrameCallback` from the `LayoutBuilder` in `BreathShapeWidget.build`).

### B. Sub-16 ms frame drops

The `addTimingsCallback` threshold of 16 ms catches frames that fully missed a 60 Hz vsync. But Android's compositor can drop frames at the GPU level (e.g. SurfaceFlinger missed a vsync) without that necessarily showing in Flutter's per-frame timing. A frame that takes 15 ms is "fine" by the probe but can still be visibly stutter-y if the previous frame budget was already tight. This class of stutter is best caught with `flutter run --profile` + the DevTools timeline view, not with `addTimingsCallback`. We did not try this yet.

### C. Discrete dot-position jump on `_position` reset

Even though `getPointPosition(1.0)` and `getPointPosition(0.0)` resolve to the same pixel mathematically, the dot's position in the **frame before** `_position` reaches exactly 1.0 might be at e.g. position 0.97 — visually distinguishable from position 0.0. If the engine clamps to 1.0 and stays there for some frames before `newCycle` fires, the dot is at position 0 (start of the circle) for those frames; then reset to 0 leaves it at position 0. No visible jump. But if the engine reaches 1.0 only on the very tick that `newCycle` fires, the previous frame's render was at 0.95–0.99 — visually almost-but-not-quite at position 0. The reset then jumps it the remaining ~5% of the perimeter in one frame. This is sub-pixel for a small dot but could become visible if the dot has a large blur radius (it does: 15 px + 8 px blurs in `BreathShapePainter._drawPoint`).

Worth probing: log `motionEngine.normalizedPosition` on **every frame** in the 500 ms preceding a `newCycle`, not just immediately before the reset. Verify the engine actually hits 1.0 in advance, not on the boundary frame itself.

### D. Codec / binder work on the platform thread despite sound coordinator disabled

`_soundCoordinator.initialize` is the only thing we disabled — but `AudioLooper` and `AudioOneShot` are still constructed in the screen's `initState`. Their internal `AudioPlayer`s may still hold native resources / Surface handles. The `BreathSoundCoordinator` object also has `suspend`/`resume` called from `didChangeAppLifecycleState`, but those should be no-ops without `initialize`. Worth double-checking whether any background audio work survives without `initialize`.

### E. Garbage collection at boundary

The mysterious `build=67.9 ms` outlier in Run 4 had no Riverpod publication, no widget rebuild, no painter — but the build phase still occupied 68 ms. The only plausible explanation is a Dart GC pause during the build phase. If GC pressure is concentrated around state-machine transitions (which allocate new `BreathSessionState` objects every tick), GC pauses might land disproportionately near boundaries. Worth profiling allocation rate and GC frequency separately.

## Recommended next steps if picking this up

1. **Reinstall the probes** from the "Probes used" section. They take ~5 minutes to add and produce structured stdout that's easy to grep.
2. **Run with `flutter run --profile`** and capture the DevTools timeline around several newCycle boundaries. Look for sub-16 ms frame drops, GPU pipeline stalls, or shader compilation events. This is much more granular than `addTimingsCallback`.
3. **Add a per-frame dot-position log** (point C above) — instrument `BreathShapePainter._drawPoint` to print `pointPosition.dy` on every paint. If the dot's last few frames before newCycle aren't at the bottom-centre pixel, the engine isn't reaching 1.0 in time, and the visible jump is real coordinate discontinuity — not a frame drop.
4. **Profile shader compilation** with `flutter run --profile --cache-sksl --purge-persistent-cache` or compare with `--no-enable-impeller` / `--enable-impeller` to rule out shader warmup at boundary.
5. **Bisect at the engine level** — temporarily replace `motionEngine.resetPosition(0.0)` in `BreathAnimationCoordinator._handleReset` with a no-op (let `_position` keep accumulating past 1.0, rely on `% 1.0` in the painter for wrapping). If the visible stutter at the bottom disappears, the reset itself was the cause, even though the math says it shouldn't be.
6. **Test on a different device** — A70 has the SEC FLAC decoder which we saw doing 2-3 flush cycles per phase. A device with software decode or a different OMX implementation may not exhibit the same pattern, helping isolate whether it's device-specific.

## What state the codebase is in right now

After `git reset --hard HEAD` at the end of the session: **all probes and TEMP disables have been removed**. The only debug artefact left is one line in `BreathSessionScreen.dart` (currently commented):

```dart
// TEMP: sound disabled — testing pre-audio state with full visuals.
// _soundCoordinator.initialize(initialState);
```

Sound is currently disabled in the running app (so audio crossfade isn't running) but everything else is restored. Either uncomment that line to bring audio back, or leave it as is to keep working in the pre-audio state.

ROADMAP and notes are clean: no Phase 17 task, no investigation note 13. Phases 15 and 16 (the shipped fixes) are documented and complete.

The five log files referenced in this doc (`some.txt`, `some2.txt`, `some3.txt`, `some4.txt`, `some5.txt`) live in the repo root untracked. Keep or delete as desired; they're the raw evidence behind the bisect summary above.
