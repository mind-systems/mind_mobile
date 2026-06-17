# Plan Review: BreathSession state equality and ViewModel publication tests (Review 2)

**Plan:** `33-breathsession-state-equality-and-viewmodel-publication-tests.md`
**Risk Level:** 🟢 Low — the plan is accurate, well-scoped, and now resolves every blocking and clarifying item raised in review 1.

## Verification performed

Re-traced every claim against the source under test:

- **`equalsIgnoringTickFields` field set** (`BreathSessionState.dart:95–110`) — confirmed. Excluded: `remainingTicks`, `currentIntervalMs`, `resetReason`. `timelineSteps` uses `identical(...)`. Task 2's 13 included scalars (`loadState`, `status`, `phase`, `exerciseIndex`, `activeStepId`, `isStarred`, `canStar`, `totalPhases`, `currentPhaseIndex`, `currentPhaseTotalDuration`, `currentExerciseShape`, `nextExerciseShape`, `tickSource`) match the method 1:1.
- **`copyWith`** carries `timelineSteps` by reference (`:140`) and cannot clear `resetReason` (`:144`, `??`). The plan's helper notes and the "build via full constructor for resetReason" workaround are correct.
- **`_state` helper defaults** are all non-default and observable on flip; `currentExerciseShape: circle` / `nextExerciseShape: square` differ so each can be flipped independently. `activeStepId: 'step-x'` is non-null, flippable via `copyWith`.
- **Barrel** (`breath_module.dart`) exports every type imported: `BreathSessionState`, `TimelineStep` (`:29`), `SetShape` (`:33`), `TickSource` (`:34`), `TickData`/`ITickService` (`:36`), `BreathSessionStatus`/`BreathPhase`/`ResetReason`/`SessionLoadState` (via `BreathSessionState.dart`), VM/DTO/service interfaces. Barrel-only import is viable.
- **`TimelineStep`** has a public const constructor and `.separator()` (`TimelineStep.dart:10–16`), so Task 3 can build two distinct lists with element-equal content.
- **Tick cadence** re-traced through `BreathSessionStateMachine._onBreathTick` for the `inhale 2 / exhale 2, cycleDuration 4, repeatCount 1, restDuration 0` DTO: tick1 inhale `2→1` (tick-only), tick2 `inhale→exhale` (structural), tick3 exhale `2→1` (tick-only), tick4 → `_advanceExercise` → `complete` (structural). Matches the plan's table exactly.
- **Paused early-return** (`_onTick`, `:230`) confirmed — `resume()` after `initState()` is genuinely required before any tick has effect.
- **`resume()` is a structural emit** (`status: pause→breath`, state machine `:181–199`) → one Riverpod publication + one raw-stream emit; `_setupEngine` at init adds the other raw-stream emit. The plan's "establish baseline after `resume()` settles" instruction is correct.
- **Dual-channel `set state`** (`:96–103`) and `_remainingTicks` lockstep (`:138`, `:167`) confirmed: Riverpod skipped on tick-only updates, raw stream + `remainingTicksNotifier` fire every tick.
- **Target dir** `test/BreathModule/Presentation/BreathSession/` exists; the reference fake file `breath_session_star_toggle_test.dart` exists and matches the plan's description (`observeSession(id) => Stream.value(dto)` at `:63`, `TickData(intervalMs)` fake, `_makeDTO`/`_makeContainer`).

## Resolution of Review 1 findings

- **Critical #1 (observeSession re-runs `_setupEngine`):** Resolved. The plan now carries a dedicated "Critical — neutralize the `observeSession` re-setup" note instructing the implementer to override `observeSession` to `const Stream.empty()` in the copied fake, with a precise explanation of why (new `timelineSteps` reference, fresh paused machine, offset baseline). This is the simplest of the two fixes review 1 offered and is correct.
- **Critical #2 (Task 6 test 2 compared against wrong channel):** Resolved. Task 6's second case now explicitly compares `notifier.value` against the **latest `vm.stream` emission's** `remainingTicks`, and calls out that `vm.currentState.remainingTicks` is intentionally stale on tick-only ticks.
- **Clarification — Task 4 listener ordering:** Resolved via the explicit "Canonical ordering" block (`initState → pump → resume → pump → attach listener/reset → drive ticks`), referenced from Task 4.
- **Clarification — `resume()` is structural:** Resolved; called out in Implementation Notes and used to justify the post-resume baseline.
- **Clarification — `pumpEventLoop` is not a real symbol:** Resolved; the plan now specifies `pumpEventQueue()` (from `flutter_test`) and `await Future(() {})` as the pure-Dart alternative, explicitly flagging `pumpEventLoop` as non-existent.
- **Clarification — Task 5 baseline:** Resolved; the per-tick collection baseline is established after `resume()` settles.

## Context Gates

- **Architecture** (`.ai-factory/ARCHITECTURE.md` present): `WARN`: none. Tests live in the app `test/` tree, import only the package barrel, and reuse the established fake pattern — consistent with the "ViewModel is the module boundary" rule. No cross-boundary imports introduced.
- **Rules** (`.ai-factory/RULES.md` present): No violations. Test command uses the required absolute Flutter path (`/usr/local/bin/flutter`), matching the project memory rule. The plan touches only test files — no Module Service / App.dart / DI rules are in scope.
- **Roadmap** (`.ai-factory/ROADMAP.md` present): `WARN`: no roadmap milestone linkage. Acceptable — this is a `test`-type task pinning existing invariants, not `feat`/`fix`/`perf` work, so milestone linkage is not expected.
- No `skill-context/aif-review/SKILL.md` present — no project-specific review overrides to apply.

## Minor observations (non-blocking)

- **Task 4, third case ("status transitions to complete"):** driving ticks 1–4 from a post-resume baseline yields **two** publications (tick 2 phase flip + tick 4 complete). The case is worded as "a structural publication occurs," which is satisfied; if the implementer asserts an exact count, it should be 2, not 1. Worth keeping in mind but the looser wording is acceptable for this assertion.
- **`pumpEventQueue()` in a plain `test()`:** it works without a `WidgetsBinding` (it drains the microtask/event queue), so no `TestWidgetsFlutterBinding` setup is required — consistent with how the reference file runs plain `test()` bodies.

## Positive Notes

- The two blocking items from review 1 are addressed at the exact right altitude — the `observeSession → const Stream.empty()` override is the cleanest fix and is explained with the precise failure modes it prevents (Tasks 4/5/6/7).
- The "Canonical ordering" block turns the previously-ambiguous setup sequence into a single reusable recipe applied across all publication tasks — this is the highest-leverage clarification.
- Field-by-field equality coverage (Tasks 1/2) mirrors `equalsIgnoringTickFields` 1:1, and the shared-`timelineSteps`-reference requirement for scalar comparisons (the single biggest pitfall for the equality file) is correctly captured.
- Task 3's intent — pinning `identical(...)` so a `listEquals` refactor fails loudly — matches the load-bearing doc comment in the source exactly.
- Tick-cadence table is accurate down to per-tick `remainingTicks` values.

---

The plan is solid: every claim verified against source, all review-1 blockers resolved, and the remaining notes are non-blocking. Ready for implementation.

PLAN_REVIEW_PASS
