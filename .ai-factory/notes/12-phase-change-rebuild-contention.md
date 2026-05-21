# Breath Session — Phase-Change Render Contention

**Date:** 2026-05-21
**Source:** conversation context

## Key Findings

- After Phase 15 closed the per-tick rebuild path (filtered Riverpod publication, stable `timelineSteps` reference, `remainingTicksNotifier` sibling channel), a residual stutter remains on **every phase boundary** — the morph animation drops 2–3 frames at the exact moment the new phase starts.
- Two compounding causes, verified with `[BREATH-PROBE]` instrumentation and `WidgetsBinding.instance.addTimingsCallback`:
  1. **`resetReason` is in `equalsIgnoringTickFields`** but is consumed only by raw-stream animation coordinators — so the state machine's emit of `resetReason=null` one tick after a reset triggers a **second** full screen rebuild on every cycle/exercise boundary.
  2. **`BreathSessionScreen.build()` does `ref.watch(breathViewModelProvider)` at the root** — so every PUBLISH rebuilds the whole Scaffold subtree, including the `Stack` with the Orb and `BreathShapeWidget` which depend only on `state.loadState` and never need to react to phase/step.
- Each PUBLISH costs ~30–55 ms of build time on a debug build — at a 16.6 ms frame budget that consumes 2–3 frames during which the morph animation freezes.

## Details

### Probe results

Logged on a real session run via:
- `BreathSessionViewModel.set state` — prints `PUBLISH` or `SKIP` with field snapshot.
- `BreathSessionScreen.build` — counter and field snapshot.
- `Builder` wrappers around each subtree (ShapeStack, Timeline, ControlButton, BottomBar) — per-subtree counter.
- `BreathShapeWidget.build` — outer build (catches parent rebuild).
- `BreathAnimationCoordinator._handleReset` — morph trigger marker.
- `BreathSessionScreen._scrollToActive` — scroll animation kickoff.
- `WidgetsBinding.instance.addTimingsCallback` — frames with build > 16 ms or raster > 16 ms.

Observed cadence on a `4-2 inhale-exhale` session with a 15-s inter-exercise rest:

| Event | What logs show |
|---|---|
| Plain tick within a phase (ticks=14→13→…) | one line: `set state SKIP` — no rebuild |
| Simple phase change `inhale→exhale` (no reset) | one `PUBLISH` → Screen + all 4 subtrees rebuild → next frame `FRAME SLOW build=47.7 ms` |
| Cycle/exercise boundary (`resetReason=newCycle` or `exerciseChange`) | **two** `PUBLISH` ~1 s apart: first with `resetReason=newCycle` (real boundary), second with `resetReason=null` and `ticks` decremented by 1 (the engine "clears" the reason one tick later). Both rebuild the whole Scaffold. Two consecutive `FRAME SLOW` events, ~40–55 ms each. |

The second PUBLISH on cycle boundaries is the surprise — `equalsIgnoringTickFields` includes `resetReason`, so a clear-emit (`newCycle → null`) is classified as structural change, even though nothing the screen renders has changed.

### Cause 1 — `resetReason` is in the publication-equality check but no Riverpod consumer reads it

In `Models/BreathSessionState.dart`:

```dart
bool equalsIgnoringTickFields(BreathSessionState other) {
  return loadState == other.loadState &&
      status == other.status &&
      phase == other.phase &&
      …
      resetReason == other.resetReason &&   // ← this line
      …
      identical(timelineSteps, other.timelineSteps);
}
```

Subscriber audit for `resetReason`:

| Subscriber | Channel | Reads `resetReason`? |
|---|---|---|
| `BreathAnimationCoordinator._onStateChanged` | raw `viewModel.listen(...)` stream | yes — decides whether to `morphTo(...)` |
| `OrbAnimationCoordinator._onStateChanged` | raw `viewModel.listen(...)` stream | yes — `_handleReset` |
| `BreathSessionScreen.build` (Riverpod) | `ref.watch(provider)` | **no** — never reads `state.resetReason` |
| Anything else | — | no (grep is clean) |

So `resetReason` is a **transient signal** for raw-stream consumers — same category as `remainingTicks` and `currentIntervalMs`. It should be excluded from `equalsIgnoringTickFields` to suppress the gratuitous second PUBLISH.

The raw `_stateController.add(value)` continues firing on both emits — animation coordinators are unaffected (they're already idempotent on the second emit because `_handleReset` only runs when `resetReason != null`).

### Cause 2 — `ref.watch(breathViewModelProvider)` at the screen root rebuilds subtrees that don't care

Today `BreathSessionScreen.build()` has:

```dart
final state = ref.watch(breathViewModelProvider);
```

at the top — so any structural PUBLISH rebuilds the whole `Scaffold > SafeArea > Column` tree. The subtrees and their actual data dependencies:

| Subtree | Fields it reads from `state` | Should rebuild on phase change? |
|---|---|---|
| `Padding > SizedBox > Stack` (Orb + `BreathShapeWidget`) | `state.loadState` (only — drives `AnimatedOpacity`) | **no** — shape is driven by `_motionEngine` + `_shapeShifter` listenables; the `AnimationCoordinator` triggers morphs via raw stream |
| `BreathTimelineWidget` | `timelineSteps`, `activeStepId`, `status` | yes — `activeStepId` and possibly `status` change |
| `_buildControlButton` | `status`, `loadState` | only when status flips (pause↔breath↔rest↔complete) — not on inhale→exhale |
| `SessionBottomBar` actions | `canStar`, `isStarred` | no |

The Stack rebuild on every phase change is pure overhead — and it lands in the same frame as the morph animation start, so it directly steals the frame budget the morph needs.

### Frame-timing correlation

Sampled cycle from logs:

```
422  PUBLISH (resetReason=exerciseChange, ticks=5)
424  morph trigger reason=exerciseChange
433  Screen.build #4 + ShapeStack #4 + ShapeWidget OUTER + Timeline + ControlButton + BottomBar
443  FRAME SLOW build=56.1 ms     ← rebuild competes with morph start

447  PUBLISH (resetReason=null, ticks=4)   ← gratuitous "clear" emit
448  Screen.build #5 + ShapeStack #5 + ShapeWidget OUTER + Timeline + ControlButton + BottomBar
454  FRAME SLOW build=42.5 ms     ← second rebuild during the same morph
```

Two `FRAME SLOW` events within ~1 s on every cycle/exercise boundary, both correlated with full subtree rebuilds.

### The fix

Two coupled changes, applied together because they target the same symptom:

**(1) Exclude `resetReason` from `equalsIgnoringTickFields`** in `packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart`. Drop the `resetReason == other.resetReason &&` line. Update the doc comment to list `resetReason` alongside `remainingTicks`/`currentIntervalMs` as transient signals consumed only by raw-stream animation coordinators — *not* a structural property of the screen.

**(2) Replace the single root `ref.watch(breathViewModelProvider)` in `BreathSessionScreen.build()`** with narrow `Consumer` widgets per subtree using `.select(...)`:

| Subtree | `.select` projection |
|---|---|
| Stack with Orb + `BreathShapeWidget` | `(s) => s.loadState` |
| `BreathTimelineWidget` | `(s) => (s.timelineSteps, s.activeStepId, s.status)` — record so `==` short-circuits on identical refs |
| `_buildControlButton` | `(s) => (s.status, s.loadState)` |
| `SessionBottomBar` actions block | `(s) => (s.canStar, s.isStarred)` |

The non-Consumer parts of `build()` (`MediaQuery`, `BreathSessionLayout.compute`) should still run only on real layout-driving changes — those don't depend on `state` so move out of any Consumer.

`ref.listenManual<BreathSessionState>` for `_scrollToActive` stays as-is — it doesn't trigger rebuilds, it just reacts to `activeStepId` transitions.

### Expected outcome

After the fix, on a simple phase change (`inhale→exhale`):
- `BreathSessionState` PUBLISH fires once.
- Only the Timeline Consumer rebuilds (its `.select` tuple changes via `activeStepId`).
- The Stack Consumer's `.select((s) => s.loadState)` returns the same value → Riverpod short-circuits → **no rebuild of the shape subtree**.
- ControlButton's `.select` short-circuits unless status flipped.
- BottomBar's `.select` short-circuits.

On a cycle/exercise boundary:
- One PUBLISH only (the resetReason-clear emit is now filtered as a SKIP).
- Same subtree behavior as above.

The morph animation gets the full ~16 ms frame budget at the moment it starts.

### Probes to remove on cleanup

The instrumentation added during diagnosis lives across five files, all tagged `[BREATH-PROBE]` for grep-clean:

- `BreathSessionViewModel.dart` — `debugPrint` block inside `set state`.
- `BreathSessionScreen.dart` — `_screenBuildCount`, `_shapeStackBuildCount`, `_bottomBarBuildCount`, `_controlButtonBuildCount` fields; `_onFrameTimings` method; `addTimingsCallback` / `removeTimingsCallback` calls; `debugPrint` in `build()` and `_scrollToActive`; the three `Builder` wrappers around ShapeStack / ControlButton / BottomBar subtrees (unwrap them when the real `Consumer` wrappers are introduced).
- `BreathTimelineWidget.dart` — `debugPrint` at the top of `build()`.
- `BreathShapeWidget.dart` — `debugPrint` inside `build()`.
- `BreathAnimationCoordinator.dart` — `debugPrint` inside `_handleReset()`.

The `Builder` wrappers in `BreathSessionScreen` get **replaced** by `Consumer`, not just removed — that's the substantive part of the fix; the probe counters and `debugPrint` lines inside them are the throwaway part.
