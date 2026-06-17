# Plan Review: BreathSession state equality and ViewModel publication tests

**Plan:** `33-breathsession-state-equality-and-viewmodel-publication-tests.md`
**Risk Level:** 🟡 Medium — plan is accurate and well-scoped, but misses one runtime confounder in the copied fakes that can silently break (or make flaky) the publication/identity tests.

## Verification performed

I cross-checked every claim in the plan against the source under test:

- `equalsIgnoringTickFields` field set (`BreathSessionState.dart:95-110`) — **confirmed**. Excluded fields are exactly `remainingTicks`, `currentIntervalMs`, `resetReason`; `timelineSteps` uses `identical(...)`. The 13 included scalars in Task 2 match the method 1:1.
- `copyWith` carries `timelineSteps` by reference (`:140`) and cannot clear `resetReason` (`:144`, `??`). Plan's helper notes are correct.
- Barrel (`breath_module.dart`) exports every type the plan imports (`BreathSessionState`, `TimelineStep`, `SetShape`, `TickSource`, `TickData`, `BreathSessionStatus`, `BreathPhase`, `ResetReason`, `SessionLoadState`, VM/DTO/service interfaces). Barrel-only import is viable.
- Tick cadence (Task 4–7) traced through `BreathSessionStateMachine._onBreathTick` for the `inhale 2 / exhale 2, cycleDuration 4, repeatCount 1` DTO — **all four ticks match the plan exactly**: tick1 inhale `2→1` (tick-only), tick2 `inhale→exhale` (structural), tick3 exhale `2→1` (tick-only), tick4 → `_advanceExercise` → `complete` (structural).
- Paused early-return (`_onTick`, `:230`) — confirmed; `resume()` after `initState()` is genuinely required.
- Dual-channel `set state` (`:96-103`) and `_remainingTicks` lockstep (`:167`, `:138`) — confirmed.
- Target dir `test/BreathModule/Presentation/BreathSession/` exists; reference fake file exists and matches the plan's description.

## Critical Issues

**1. `observeSession()` in the copied fake re-runs `_setupEngine` after `initState()` — unaddressed.**
The plan tells the implementer to copy `_FakeSessionService` verbatim from `breath_session_star_toggle_test.dart`. That fake returns `observeSession(id) => Stream.value(dto)` (reference file `:63`). In `initState` (`BreathSessionViewModel.dart:115-118`) this subscription fires once, asynchronously, and calls `_setupEngine(dto)` a **second time**. That second setup:
- builds a **new** `timelineSteps` list (new reference), and
- constructs a **new** `BreathSessionStateMachine` in `status: pause`, discarding the first one.

Consequences the plan does not account for:
- **Task 7 (timelineSteps identity):** capturing `vm.currentState.timelineSteps` immediately after `await vm.initState()` may capture the *first* list, which the `observeSession` re-setup then replaces — so `identical(...)` fails before any tick is driven (flaky, depends on microtask ordering of `Stream.value`).
- **Tasks 4/5/6 (driving ticks):** if `resume()` runs *before* the `observeSession` microtask, the re-setup creates a fresh paused state machine and `resume()` is silently negated → ticks hit a paused machine → no emissions → tests fail.
- **Task 4 (publication count):** the re-setup emits a structural `set state` (new `timelineSteps` reference ⇒ `equalsIgnoringTickFields` false ⇒ Riverpod publishes). If the listener is attached before this settles, the baseline count is offset and `count == 0` assertions break.

**Fix (pick one), and state it in the plan:**
- Simplest: in the copied `_FakeSessionService`, override `observeSession` to `const Stream.empty()` for these tests (the star-toggle behavior isn't needed here), **or**
- After `await vm.initState()`, pump the event loop (`await pumpEventQueue()` / a couple of `await Future(() {})`) so the re-setup settles, and only *then* capture `timelineSteps`, attach the Riverpod listener, and call `resume()`.

**2. Task 6 test 2 compares against the wrong channel.**
The case is worded "after each tick, `notifier.value` equals **the published state's** `remainingTicks`." On tick-only ticks the Riverpod-published state (`vm.currentState`) is intentionally **stale** (publication suppressed), while `remainingTicksNotifier` tracks the engine value. So `notifier.value == vm.currentState.remainingTicks` will **fail** on exactly the tick-only ticks this suite exists to verify. The notifier is in sync with the **engine / raw-stream** `remainingTicks`, not the Riverpod state. Reword the case to compare `notifier.value` against the latest `vm.stream` emission's `remainingTicks` (the title already says "the engine remainingTicks" — make the parenthetical match it).

## Minor Issues / Clarifications

- **Task 4 listener ordering is ambiguous.** "Attach `container.listen(...)`; `await initState()` then `resume()` first" can be read either way. For a clean `count == 0` baseline the listener must be attached (or its counter reset) **after** `initState` + `observeSession` settle + `resume`. Make the order explicit: `initState → pump → resume → pump → attach listener (or reset count) → drive ticks`.
- **`resume()` itself is a structural publication** (`status: pause→breath`). Any test attaching the Riverpod listener or subscribing to `vm.stream` before `resume()` must account for the resume emit (and the setup emit on the raw stream). The plan's per-tick counts assume a clean baseline — subscribe/reset after `resume()` settles.
- **"pumpEventLoop" is not a real symbol.** flutter_test exposes `pumpEventQueue()`; pure-Dart pumping is `await Future(() {})` / `await Future.delayed(Duration.zero)`. Use the correct name to avoid a compile error.
- **Task 5 test 1 baseline:** `_setupEngine` emits one raw-stream event at init and `resume()` emits another. "One stream event per processed tick" holds only if the subscription starts (or the collected list is reset) after `resume()` settles. Worth a one-line note.

## Context Gates

- **Architecture** (`.ai-factory/ARCHITECTURE.md` present): No boundary concerns — tests live in the app `test/` tree, import only the package barrel, and reuse the established fake pattern. Consistent with the "ViewModel is the module boundary" rule. `WARN`: none.
- **Rules** (`.ai-factory/RULES.md` present): Test command uses the required absolute Flutter path (`/usr/local/bin/flutter`), matching the project memory rule. No violations observed.
- **Roadmap** (`.ai-factory/ROADMAP.md` present): This is a `test`-type task (pinning existing invariants), so roadmap milestone linkage is not expected. `WARN`: no roadmap linkage, acceptable for test-hardening work.
- No `skill-context/aif-review/SKILL.md` present — no project-specific review overrides to apply.

## Positive Notes

- Field-by-field equality coverage (Task 1/2) exactly mirrors `equalsIgnoringTickFields`; the shared-`timelineSteps`-reference requirement for scalar comparisons is correctly identified and is the single most important pitfall for the equality file — well captured.
- The `resetReason` copyWith limitation and the "build via full constructor" workaround are correct and precisely explained.
- The intent behind Task 3 (pinning `identical(...)` so a `listEquals` refactor fails loudly) is exactly right and matches the load-bearing doc comment in the source.
- Tick-cadence table is accurate down to per-tick `remainingTicks` values — verified against the state machine.
- Reusing the proven fake harness instead of importing across test files is the right call.

---

The plan is fundamentally sound and the test design is correct. Issues #1 and #2 must be resolved before implementation — otherwise the publication and identity tests will be flaky or assert against the wrong channel. Address the two critical items and the clarifications, and this is ready.
