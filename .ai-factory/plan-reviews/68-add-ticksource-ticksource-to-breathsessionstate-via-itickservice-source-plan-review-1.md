# Plan Review: Add `tickSource: TickSource` to `BreathSessionState` via `ITickService.source`

## Code Review Summary

**Files Reviewed:** 4 plan-targeted files + 5 existing test files that implement `ITickService`
**Risk Level:** 🟡 Medium — plan is technically correct for the production path but skips a required cleanup that will break the test suite at compile time.

### Context Gates
- **ARCHITECTURE.md**: No conflicts — the change stays inside the existing layering (interface in the package, concrete impl in `lib/BreathModule/`, DTO-style enum already exported via `breath_module.dart`).
- **RULES.md**: No conflicts — no Service statefulness, App.dart, or DI rule is touched.
- **ROADMAP.md (12.5)**: Plan matches the roadmap entry verbatim. ROADMAP 12.6 (`BreathSoundCoordinator`) consumes `state.tickSource`, which this plan introduces. **WARN**: the roadmap entry also omits any mention of test fakes, so it carries forward the same gap noted below.

### Critical Issues

1. **Missing task: update existing `ITickService` fakes** (blocks `flutter test`)
   Adding an abstract getter `TickSource get source;` to `ITickService` makes every existing `implements ITickService` declaration a compile error until the getter is implemented. The plan only updates `ClockTickService` and silently relies on `Testing: no`, but the failing classes are *pre-existing* test doubles — not new tests:

   - `test/BreathModule/Presentation/BreathSession/orb_animation_coordinator_resume_test.dart:11` — `class _ManualTickService implements ITickService`
   - `test/BreathModule/Presentation/BreathSession/breath_session_star_toggle_test.dart:11` — `class _FakeTickService implements ITickService`
   - `test/BreathModule/Presentation/BreathSession/breath_animation_coordinator_restart_test.dart:21` — `class _FakeTickService implements ITickService`
   - `test/BreathModule/Presentation/BreathSession/breath_session_state_machine_test.dart:10` — `class FakeTickService implements ITickService`
   - `test/BreathModule/Presentation/BreathSession/breath_session_enriched_state_test.dart:19` — `class FakeTickService implements ITickService`

   Fix: add a **Task 5** that adds
   ```dart
   @override
   TickSource get source => TickSource.timer;
   ```
   to each of these five fakes, plus the `show ITickService, TickData` clauses where applicable (need to be extended to include `TickSource`). Without this, running `flutter test` after the patch will fail to compile, regardless of the “Testing: no” setting.

### Non-Blocking Notes

- **Initial-emission ordering in `_setupEngine`.** The new `_onEngineState` carries `tickSource: state.tickSource` forward. If `_stateMachine!.stateStream.listen(...)` ever emits synchronously before the `state = BreathSessionState(...)` line a few lines below, the carried value would be whatever was on the *previous* state (i.e. `BreathSessionState.initial()` on first run → defaults to `TickSource.timer`). Today only `ClockTickService` exists, so the value coincidentally matches — but once `HeartbeatTickService` is wired in milestone 12.x, this ordering could silently emit `timer` for the very first frame on heartbeat sessions. Optional safeguard: in `_onEngineState`, fall back to `tickService.source` instead of `state.tickSource`, or just be aware when 12.x lands.
- **Default value choice.** Defaulting `tickSource` to `TickSource.timer` in both the constructor and `BreathSessionState.initial()` is fine but couples the default to the current tick service. A neutral default (or marking the field `required`) would force every constructor site to be explicit. Acceptable as-is given there are only two construction sites and both will pass `tickSource` explicitly after this plan.
- **Import path verification (passes).** `import 'CommonModels/TickSource.dart';` from `packages/breath_module/lib/src/ITickService.dart` and `import '../../CommonModels/TickSource.dart';` from `BreathSessionState.dart` are both correct relative paths; the file exists at `packages/breath_module/lib/src/CommonModels/TickSource.dart` and contains the enum (`heartbeat`, `timer`).
- **`show` clause in `ClockTickService` (passes).** `package:breath_module/breath_module.dart` already re-exports `TickSource` (see `breath_module.dart:34`), so extending the `show` clause to `show ITickService, TickData, TickSource` is valid.
- **No state-machine changes (passes).** The state machine does not need updating — the plan is correct that tick source is stable per session and only changes when `_setupEngine` runs, so carrying it forward in `_onEngineState` is the right pattern.

### Positive Notes

- Tasks are properly sequenced via dependency annotations (Task 2 → Task 1; Task 3 → Task 1; Task 4 → Tasks 1 & 3).
- The plan correctly identifies that `copyWith` cannot clear nullable fields and therefore uses the full constructor in `_setupEngine` and `_onEngineState`, matching the pattern already established for `resetReason` / `currentExerciseShape` / `nextExerciseShape`.
- Reuse of the existing `TickSource` enum (already public via `breath_module.dart` export) avoids any new public-API decisions.
- Plan is small, file-scoped, and gives exact placement guidance (which named-argument cluster each new line goes into).

### Required Plan Edits

1. Add **Task 5: Update existing `ITickService` test fakes** with the five file paths listed above and the `@override TickSource get source => TickSource.timer;` snippet. Mark it as depending on Task 1.
2. Optional: add a one-line note to Task 4 about the initial-emission ordering concern for future heartbeat support.

Once Task 5 is added, the plan is ready to implement.
