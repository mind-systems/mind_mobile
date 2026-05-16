# Plan Review: Wire BreathSoundCoordinator into BreathSessionScreen

**Plan:** `.ai-factory/plans/67-wire-in-packages-breath-module-lib-src-breathsession-breathsessionscreen-dart.md`
**Risk Level:** 🟢 Low

## Context Gates
- **Architecture:** N/A — pure presentation-layer wiring inside `packages/breath_module/`; no boundary crossings, no DI changes in `lib/`. Aligns with the existing coordinator pattern (`OrbAnimationCoordinator`, `BreathAnimationCoordinator`).
- **Rules:** N/A — plan explicitly preserves existing style (no extra trailing commas, comments stay in original language). Matches user feedback `feedback_app_dart_style.md` (irrelevant here — this is not `App.dart`).
- **Roadmap:** N/A — minor wiring fix, no milestone linkage expected.

## Verification of Plan Specifics Against Codebase

Cross-checked every line reference in `BreathSessionScreen.dart` against the current source:

| Plan claim | Source line | Status |
|---|---|---|
| Line 11: `import 'Animation/OrbAnimationCoordinator.dart';` | L11 | ✅ Matches |
| Line 35: `late final OrbAnimationCoordinator _orbCoordinator;` | L35 | ✅ Matches |
| Line 61: `_orbCoordinator = OrbAnimationCoordinator(...);` | L61 | ✅ Matches |
| Line 69: `_orbCoordinator.initialize(initialState);` | L69 | ✅ Matches |
| Line 72: `viewModel.initState();` | L72 | ✅ Matches |
| Line 95: `_orbCoordinator.dispose();` | L95 | ✅ Matches |
| Lines 251–253: restart `onPressed` with `_coordinator.reset(); _orbCoordinator.reset();` | L251–253 | ✅ Matches |

`BreathSoundCoordinator` API surface (read from `Audio/BreathSoundCoordinator.dart`):
- Constructor `BreathSoundCoordinator({required this.viewModel})` → matches plan's `BreathSoundCoordinator(viewModel: viewModel)`.
- `void initialize(BreathSessionState initialState)` → plan calls `_soundCoordinator.initialize(initialState)`. Note: the coordinator does not actually use `initialState` internally (subscribes via `viewModel.listen`), but the signature is honored.
- `void reset()` and `void dispose()` → both exist and are called correctly.

`viewModel` passed is `ref.read(breathViewModelProvider.notifier)` which is a `BreathViewModel` (Notifier subclass) — matches `BreathSoundCoordinator.viewModel: BreathViewModel`. `just_audio: ^0.10.5` is already in `packages/breath_module/pubspec.yaml`, so no dependency addition is needed.

### Critical Issues
None.

### Minor Observations (non-blocking)
1. **Ordering of `_soundCoordinator.initialize` before `viewModel.initState()`** is correct — it registers the listener via `viewModel.listen(...)` before the state machine starts emitting, avoiding a missed first transition.
2. **Restart sequence** ends up as: `_coordinator.reset() → _orbCoordinator.reset() → _soundCoordinator.reset() → viewModel.restartEngine()`. This is the right order — audio is silenced before the engine re-emits new phases. ✅
3. **Dispose order**: `_coordinator → _orbCoordinator → _soundCoordinator → _motionEngine → _shapeShifter → _scrollController`. Safe — `_soundCoordinator.dispose()` first invokes its own listener-unsubscribe (`_stateListener?.call()`), so no late state-callbacks can fire after the viewModel is torn down.
4. The plan does not call `_soundCoordinator.reset()` when the session naturally completes (the coordinator handles that internally via `BreathSessionStatus.complete → _fadeTo(0.0, 500ms)`), so the wiring is sufficient as-is.
5. Asset existence (`assets/audio/ohm_inhale.wav` etc.) is out of scope for this plan — it's the coordinator's responsibility, and a failure at runtime would surface from `just_audio`, not from the wiring itself.

### Positive Notes
- Plan is surgical and self-contained — six well-located insertions, each anchored to a specific existing line.
- Verification step (`flutter analyze packages/breath_module`) is included.
- Style preservation explicitly called out (no extra trailing commas, comment language preserved).
- Plan matches the existing coordinator-lifecycle convention used by `OrbAnimationCoordinator` and `BreathAnimationCoordinator`, keeping the file uniform.

PLAN_REVIEW_PASS
