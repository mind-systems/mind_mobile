# Plan Review: Fix two confirmed silence bugs in BreathSoundCoordinator

**Plan file:** `.ai-factory/plans/04-fix-two-confirmed-silence-bugs-in-packages-breath-module-lib-src-breathsession-audio-breathsoundcoordinator-dart.md`
**Target file:** `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
**Risk Level:** 🟡 Medium

## Context Gates

- **Architecture (.ai-factory/ARCHITECTURE.md):** Not consulted as part of this review (audio coordinator is internal to `packages/breath_module`, no module boundary or domain layer touched). No alignment risk. — **WARN: skipped**
- **Rules (.ai-factory/RULES.md):** File not present. — **WARN: missing**
- **Roadmap (.ai-factory/ROADMAP.md):** Plan is a bug fix; explicit roadmap linkage not provided. Not blocking. — **WARN: no roadmap link**

## Verification Performed

- Read `BreathSoundCoordinator.dart` end-to-end and confirmed the current `_onTick` guard misses `BreathSessionStatus.rest` (only `pause` and `breath+rest-phase` allowed) — Task 1 is correctly scoped.
- Read `BreathSessionState.dart`. `BreathSessionStatus.rest` and `BreathPhase.rest` are distinct enum entries; the plan correctly distinguishes them.
- Inspected `just_audio` **0.10.5** (pubspec.lock confirms version) in pub cache.

## Critical Issues

### 1. `ConcatenatingAudioSource` is deprecated in just_audio 0.10.5

In `~/.pub-cache/hosted/pub.dev/just_audio-0.10.5/lib/just_audio.dart:2921`:

```dart
@Deprecated('Use AudioPlayer.setAudioSources instead')
class ConcatenatingAudioSource extends AudioSource { ... }
```

The plan instructs Task 2 to build:

```dart
ConcatenatingAudioSource(children: _phaseOrder.map((p) => AudioSource.asset(...)).toList())
```

…and pass it to `setAudioSource(...)`. This will compile but **emit `deprecated_member_use` warnings**, which conflicts with Task 3's "fix any warnings introduced by the change."

**Recommendation:** Use the non-deprecated `setAudioSources` API instead. It takes the children directly:

```dart
unawaited(_loopPlayer!.setAudioSources(
  _phaseOrder.map((p) => AudioSource.asset(_phaseAssets[p]!)).toList(),
  preload: true,
));
```

The semantics (preloaded playlist, indexed seek) are identical and no `ConcatenatingAudioSource` symbol is needed. Update Task 2's bullet points and Task 3's "Confirm the existing import exposes `AudioSource` and `ConcatenatingAudioSource`" accordingly — only `AudioSource` needs to be re-confirmed.

## Important Issues

### 2. Initial-load race is documented but not guarded

`setAudioSources(..., preload: true)` is left unawaited with the rationale that "the 15s inter-exercise rest covers buffering." This is a reasonable assumption for the *normal* session start path (pause → rest → breath), but:

- A session that resumes mid-exercise (status pause → breath with no rest between) could call `_switchToPhase` before the playlist is ready.
- On Android, ExoPlayer initialization on a cold start can exceed 15 s on slow devices.
- After app cold-start, the first user interaction may skip rest entirely (depends on session flow — worth confirming with `BreathSessionViewModel`).

If `seek(Duration.zero, index: index)` is called before the playlist is loaded, `just_audio` will either throw `PlayerException` or silently no-op (depends on platform), leaving the player at volume 0 with no audio.

**Recommendation:** Either (a) store the load future as a field (e.g. `Future<void>? _loadFuture`) and `await _loadFuture` at the top of `_switchToPhase`, or (b) gate the seek on `player.processingState == ProcessingState.ready`. Option (a) is simpler and preserves the "fire-and-forget on init" semantics while guaranteeing correctness. Add this as a sub-bullet in Task 2.

### 3. `_currentPhase` accounting after the new switch flow

Currently `_currentPhase` is tracked in two places inside `_onStateChanged`: section 3 (status case `breath`) and section 4 (phase change). With the new playlist flow that doesn't change. **However**, the plan's Task 2 description for `reset()` explicitly says "keep `_currentPhase = null` and `_currentStatus = null`." This matches existing code (lines 61–62) — confirm this is meant as a no-op clarification rather than implying additional changes. Worth a single-line note in the plan to avoid Phase 2 inadvertently moving these assignments.

## Minor Issues / Nits

### 4. `LoopMode.one` with playlist

`LoopMode.one` repeats the currently active item in a playlist, not the whole playlist — this is the desired behavior for per-phase looping, so the plan is correct. Worth a one-line comment in the code change (not in the plan) confirming the intent for future readers, since it's a non-obvious interaction.

### 5. `setLoopMode` ordering

The plan keeps `setLoopMode(LoopMode.one)` from line 39 in place and adds `setVolume(0.0)` and `setAudioSources(...)` after it. Order is fine — `setLoopMode` does not depend on a loaded source. No change needed; flagging only because Task 2's bullet order is "after setLoopMode → set audio source → set volume," whereas the cleaner order is mute first, then load (to remove any chance of a brief audible blip from the platform default volume during load). Either works; the difference is sub-perceptual.

### 6. Task 1 description count

Task 1 says "widen the guard so ticks fire in **three** cases." The three cases listed are correct, but the current code expresses two boolean conditions (`isInPause`, `isRestPhase`). When implementing, the cleanest form is:

```dart
final allowTick = _currentStatus == BreathSessionStatus.pause ||
    _currentStatus == BreathSessionStatus.rest ||
    (_currentStatus == BreathSessionStatus.breath && _currentPhase == BreathPhase.rest);
if (!allowTick) return;
```

Worth showing this snippet inline in the plan so implementer does not introduce a typo (e.g. accidentally `&&`-ing the status checks).

## Positive Notes

- Root-cause analysis is precise and matches the code: tick guard misses `BreathSessionStatus.rest`, and per-switch `setAsset` is what burns the 4-tick window on Android ExoPlayer.
- Switching to a preloaded playlist + `setCurrentIndex`/`seek(zero, index:)` is the textbook just_audio idiom for low-latency phase swaps.
- Phase ordering (`_phaseOrder` constant, `rest` intentionally absent) is well-defined and the index-lookup approach is correct.
- `reset()` semantics are preserved (player.stop() + setVolume(0.0), no re-init) — this is the right tradeoff: cached playlist survives session restarts, no ExoPlayer re-init cost.
- `dispose()` is correctly left alone; `AudioPlayer.dispose` drops the playlist.
- Plan correctly notes no signature change to `_switchToPhase`, so the call sites in `_onStateChanged` need no edits.

## Required Plan Edits

1. **Task 2:** Replace `ConcatenatingAudioSource` with `setAudioSources([...])` (non-deprecated API). Update Task 3's import-confirmation note accordingly.
2. **Task 2:** Add a sub-bullet for guarding `_switchToPhase` against the unawaited-load race (store and await `_loadFuture`, or gate on `processingState == ProcessingState.ready`).
3. **Task 1:** Include the boolean expression form inline (or a short snippet) to prevent operator-precedence mistakes.

After these edits, the plan is solid and ready to implement.

---

Once the three plan edits above are applied, the plan can be considered review-passed. As written, the plan is **not** PLAN_REVIEW_PASS — Issue #1 (deprecated API) directly conflicts with Task 3's "fix any warnings" exit criterion.
