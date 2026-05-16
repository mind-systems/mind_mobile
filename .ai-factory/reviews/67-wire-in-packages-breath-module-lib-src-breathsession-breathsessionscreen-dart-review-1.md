# Code Review: Wire BreathSoundCoordinator into BreathSessionScreen

**Plan:** `.ai-factory/plans/67-wire-in-packages-breath-module-lib-src-breathsession-breathsessionscreen-dart.md`
**Diff scope:** `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart` (6 inserted lines), plus already-tracked `pubspec.lock` (transitive `just_audio` deps — pre-existing milestone 66 commit, not part of this change).
**Risk level:** 🟢 Low — pure presentation wiring, no boundary crossings.

## Verification

Read the full modified file and `BreathSoundCoordinator.dart`. Cross-checked the API surface and lifecycle ordering against the existing `OrbAnimationCoordinator` pattern.

| Aspect | Verdict |
|---|---|
| Import path `Audio/BreathSoundCoordinator.dart` | ✅ resolves to `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart` |
| `late final BreathSoundCoordinator _soundCoordinator;` | ✅ assigned exactly once in `initState()` before any read |
| Constructor `BreathSoundCoordinator(viewModel: viewModel)` | ✅ matches `BreathSoundCoordinator({required this.viewModel})` |
| `viewModel` type (`BreathViewModel` from `ref.read(breathViewModelProvider.notifier)`) | ✅ matches constructor field type |
| `initialize(initialState)` call site | ✅ signature `void initialize(BreathSessionState)` — initialState read on line 67 |
| `dispose()` call site | ✅ exists, idempotent (early-returns on null `_player`) |
| `reset()` call site | ✅ exists, cancels fade timer and stops player without unsubscribing the listener — correct for restart |

## Lifecycle ordering

1. **Listener registration vs first state emit.** `_soundCoordinator.initialize(initialState)` runs inside `addPostFrameCallback` immediately before `viewModel.initState()`. The coordinator's `initialize` registers `viewModel.listen(_onStateChanged)` (`BreathSoundCoordinator.dart:30`), which subscribes to `_stateController.stream` *before* `viewModel.initState()` triggers any state transitions. No missed first transition. ✅

2. **Restart sequence** — `_coordinator.reset() → _orbCoordinator.reset() → _soundCoordinator.reset() → viewModel.restartEngine()`. `_soundCoordinator.reset()` clears `_currentPhase` / `_currentStatus` and silences the player; subsequent state emissions from the restarted engine are handled correctly because the listener subscription is preserved. ✅

3. **Dispose ordering** — `_coordinator → _orbCoordinator → _soundCoordinator → _motionEngine → _shapeShifter → _scrollController`. `_soundCoordinator.dispose()` first invokes `_stateListener?.call()` to unsubscribe, then disposes the player asynchronously via `unawaited(player.dispose())`. No callbacks can fire on a destroyed view-model. The `_soundCoordinator` doesn't depend on `_motionEngine` or `_shapeShifter`, so the order is safe. ✅

## Runtime concerns considered

- **Asset resolution.** `BreathSoundCoordinator._switchToPhase` calls `player.setAsset('assets/audio/ohm_inhale.wav')` etc. Assets are declared in the root app's `pubspec.yaml` (line 104: `assets/audio/`) and the WAV files exist (`ohm_inhale.wav`, `ohm_exhale.wav`, `ohm_hold.wav`). `just_audio.setAsset` without a `package` parameter resolves against the root bundle, so this works when the package is consumed from the main app. Out of scope for this plan, but verified.
- **Type/null safety.** `late final` fields are assigned in `initState` before any access; no risk of `LateInitializationError`.
- **No race conditions.** `_player` is created synchronously in `initialize`; the only async work is `unawaited(...)` calls that are guarded by null checks inside the coordinator.
- **Hot-reload.** No state file outside of the widget — `late final` fields are re-initialized when the widget is rebuilt from scratch, but a hot-reload preserves State, which is normal and acceptable.

## Style

- Original Russian comments preserved (matches plan instructions).
- No trailing commas introduced on the new lines, consistent with surrounding style.
- New import placed adjacent to other Animation-folder imports as specified.

## Findings

None.

REVIEW_PASS
