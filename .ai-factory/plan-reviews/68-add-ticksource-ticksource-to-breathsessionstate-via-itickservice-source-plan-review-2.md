# Plan Review: Add `tickSource: TickSource` to `BreathSessionState` via `ITickService.source` (Iteration 2)

## Code Review Summary

**Files Reviewed:** 4 plan-targeted files + 5 existing test files that implement `ITickService` + plan v2 + previous review v1
**Risk Level:** 🟢 Low — all critical feedback from review v1 has been addressed; the plan is internally consistent, path-correct, and compile-safe.

### Context Gates

- **ARCHITECTURE.md**: No conflicts. Interface stays in `packages/breath_module/lib/src/ITickService.dart`; concrete impl stays in `lib/BreathModule/ClockTickService.dart`; `TickSource` is already re-exported from `packages/breath_module/lib/breath_module.dart:34`. Layering is preserved.
- **RULES.md**: No conflicts. The plan does not introduce any Service-side state, does not touch `App.dart`, and all dependencies remain constructor-injected (`tickService` continues to be passed into `BreathViewModel`).
- **ROADMAP.md**: Plan implements milestone **12.5** verbatim and is a hard prerequisite for **12.6** (`BreathSoundCoordinator` tick-source dispatch). No drift from the roadmap entry.

### Critical Issues

None.

### Verification Against Review v1 Findings

1. **Test-fake compile breakage (critical in v1) — RESOLVED.** Plan v2 adds **Task 5** covering all five `implements ITickService` fakes:
   - `test/BreathModule/Presentation/BreathSession/orb_animation_coordinator_resume_test.dart:11` (`_ManualTickService`)
   - `test/BreathModule/Presentation/BreathSession/breath_session_star_toggle_test.dart:11` (`_FakeTickService`)
   - `test/BreathModule/Presentation/BreathSession/breath_animation_coordinator_restart_test.dart:21` (`_FakeTickService`)
   - `test/BreathModule/Presentation/BreathSession/breath_session_state_machine_test.dart:10` (`FakeTickService`)
   - `test/BreathModule/Presentation/BreathSession/breath_session_enriched_state_test.dart:19` (`FakeTickService`)

   Each existing `show` clause was confirmed to list `ITickService, TickData` but not `TickSource` — the plan correctly instructs to extend the `show` clause where applicable. Override snippet (`@override TickSource get source => TickSource.timer;`) is correct and matches the file's existing test-double style.

2. **Initial-emission ordering note (non-blocking in v1) — ADDRESSED.** Task 4 now includes an explicit caveat that, once `HeartbeatTickService` lands, falling back to `tickService.source` is the safer pattern. The current plan keeps `state.tickSource` carry-forward — acceptable today because `BreathSessionStateMachine.stateStream.listen(...)` does not emit synchronously before `_setupEngine` finishes (`state` is assigned on the line immediately after), so any inherited value would be `BreathSessionState.initial()`'s `TickSource.timer` default, which matches `ClockTickService.source` anyway. The note is a future-proofing flag, not a blocker.

### Path / API Verification

- `packages/breath_module/lib/src/ITickService.dart` → `import 'CommonModels/TickSource.dart';` — sibling import correct (file exists at `packages/breath_module/lib/src/CommonModels/TickSource.dart`, contains `enum TickSource { heartbeat, timer }`).
- `packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart` → `import '../../CommonModels/TickSource.dart';` — relative path matches the existing `SetShape` import on line 1 (two levels up: `Models/` → `BreathSession/` → `src/`, then into `CommonModels/`). Correct.
- `lib/BreathModule/ClockTickService.dart` — `show ITickService, TickData` clause exists at line 3; extending to `show ITickService, TickData, TickSource` is valid because `TickSource` is re-exported from `package:breath_module/breath_module.dart`.
- `BreathSessionViewModel._setupEngine` and `_onEngineState` — both already use the full `BreathSessionState(...)` constructor (lines 106–123 and 145–162), confirming the plan's rationale that nullable enriched fields can't be cleared via `copyWith` and that adding `tickSource` to both call sites is the correct shape.

### Architectural Soundness

- Tick source is a property of the engine, not of per-tick state — making it stable per `_setupEngine` invocation and carrying it forward from `state` instead of from `engineState` is the right design.
- `BreathSessionStateMachine` is correctly left untouched (engine state has no business knowing about its tick source).
- Default value `TickSource.timer` couples the default to the only currently existing implementation, but with only two construction sites (both explicit after this plan) and a future `HeartbeatTickService` that will assign explicitly, this is acceptable. The previous-review suggestion to make the field `required` is not necessary.

### Sequencing & Dependencies

- Task 2 depends on Task 1 ✓
- Task 3 depends on Task 1 ✓
- Task 4 depends on Tasks 1 and 3 ✓
- Task 5 depends on Task 1 ✓ (and conceptually must precede `flutter test` regardless of `Testing: no`, since fakes are pre-existing compile units)
- Commit plan groups production change separately from state/VM/test-fake changes — both commits compile independently.

### Positive Notes

- Plan v2 is a tight, surgical patch: 4 source files + 5 test files, no migration footprint, no public-API churn (the `TickSource` enum was already exported).
- Each task gives precise placement guidance (which named-argument cluster, which `show` clause, exact override snippet) — minimal interpretation room for the implementer.
- The forward-looking note about `tickService.source` fallback for milestone 12.x is a good documentation breadcrumb that should not be erased even after this plan is merged.
- Both `BreathSessionState` constructor call sites in the view-model already use the full constructor pattern (not `copyWith`) — so adding the new field at both sites is the natural, low-risk shape.

PLAN_REVIEW_PASS
