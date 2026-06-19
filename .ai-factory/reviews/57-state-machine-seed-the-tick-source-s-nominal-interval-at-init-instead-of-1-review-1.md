# Code Review: State machine — seed the tick source's nominal interval at init

**Scope:** `git diff HEAD` — 5 production/test source files + 8 test fakes.
**Risk Level:** 🟢 Low — change is small, faithful to the plan, and self-consistent.

## What was changed

- `packages/breath_module/lib/src/ITickService.dart` — added `int get nominalIntervalMs;` to the interface with a doc comment distinguishing it from the per-tick measured `TickData.intervalMs`.
- `lib/BreathModule/ClockTickService.dart` — `nominalIntervalMs => 1000` (matches the existing 1000 ms timer period).
- `lib/BreathModule/HeartRateTickService.dart` — `nominalIntervalMs => 1000` placeholder with an explanatory comment.
- `lib/BreathModule/SwitchableTickService.dart` — delegates to the active source (`_clock`/`_heart`).
- `packages/breath_module/lib/src/BreathSession/BreathSessionStateMachine.dart` — both `_initialRestState()` and `_initialBreathState()` now seed `currentIntervalMs: tickService.nominalIntervalMs` instead of `-1`.
- 8 test fakes across 7 files gained `@override int get nominalIntervalMs => 1000;`.

## Verification performed

- **Compilation completeness.** Grepped all `implements ITickService|ClockTickService|HeartRateTickService|SwitchableTickService` — exactly 11 implementers (3 production, 8 test fakes), all updated. No `noSuchMethod`-based or mocktail mocks of the interface remain unimplemented. `flutter test` will compile.
- **Constructor ordering is safe.** `tickService` is a `required this.tickService` field-initializing parameter (`BreathSessionStateMachine.dart:99`), so it is assigned before the constructor body calls `_initialRestState()`/`_initialBreathState()` (lines 103–106). No read-before-init.
- **`SwitchableTickService` delegation is safe.** `_activeSource` is `late`-initialized to `TickSource.timer` in the constructor body before the object is reachable; `nominalIntervalMs` is a pure getter with no lifecycle/disposal concern.
- **Seed reaches the UI as intended.** `BreathSessionViewModel._buildInitialState` reads `_stateMachine.currentState.currentIntervalMs` (line 149/160), which now carries `1000`. The two origin consumers — `BreathAnimationCoordinator` (`if (state.currentIntervalMs > 0)`, line 110) and `BreathSoundCoordinator` (`state.currentIntervalMs > 0 ? ... : 1000`, line 69) — both gate on `> 0`, so seeding `1000` makes them fire from construction. This is the milestone goal, with no behavioral regression for the `1000` path (it was already the audio fallback).
- **No `-1` sentinel was broken.** The only remaining `== -1` dependency is `breath_module_state_channel_test.dart` (lines 892–903), which deliberately constructs a state with `currentIntervalMs: -1` to assert that `tickCount` derives from `currentPhaseTotalDuration` (note 121) — independent of this change and still valid.
- **`BreathSessionState.initial()` left at `-1`** (Models line 66) — correct per plan; it is the pre-load Riverpod state with no cadence consumer.
- **Structural-change detection unperturbed.** `equalsIgnoringTickFields` excludes `currentIntervalMs`, so seeding a real value does not alter Riverpod publication behavior.
- **No codegen impact.** No Drift/proto/generated files touched.

## Findings

None. The implementation matches the plan exactly, all interface implementers are updated, and the seeded value flows correctly to the origin consumers without regressing any existing path.

REVIEW_PASS
