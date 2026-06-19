# Plan Review 2: State machine — seed the tick source's nominal interval at init

**Plan:** `57-state-machine-seed-the-tick-source-s-nominal-interval-at-init-instead-of-1.md`
**Files Reviewed:** 5 plan tasks against 8 codebase files + 7 test files
**Risk Level:** 🔴 High — the blocking issue raised in plan-review-1 is still **unresolved** in this revision.

## Context Gates

- **ARCHITECTURE.md:** No boundary violation. `nominalIntervalMs` is declared on the package-side interface (`ITickService`) and implemented by the concrete services in `lib/BreathModule/` — package declares the contract, app implements it. Correct direction. ✅
- **RULES.md:** The "Module Services must be stateless" rule targets `IXxxService` implementations that bridge notifiers, not the tick services (which legitimately own `StreamController`s). No conflict. ✅
- **ROADMAP.md:** Milestone tracked (note 122 + roadmap entry). Linkage present. ✅

## Verified Correct (re-confirmed against the code)

- **File paths & line numbers are accurate.** `currentIntervalMs: -1` sits at line 127 (`_initialRestState`) and line 151 (`_initialBreathState`) of `BreathSessionStateMachine.dart`, exactly as the plan states.
- **`tickService` is in scope** in both builders — `BreathSessionStateMachine` holds `final ITickService tickService` (line 77), so `tickService.nominalIntervalMs` is reachable from the initial builders.
- **`ClockTickService` value (1000)** matches the existing `Timer.periodic(Duration(milliseconds: 1000))` and the `TickData(...1000)` it emits.
- **`SwitchableTickService` delegation is safe** — `_activeSource` is `late`-initialized to `TickSource.timer` in the constructor body before any external read.
- **`equalsIgnoringTickFields` excludes `currentIntervalMs`** (line 95–109), so seeding a real value does not perturb structural-change detection. Note 39 holds.
- **Leaving `BreathSessionState.initial()` at `-1`** (Models line 66) is correct — it is the pre-load Riverpod state with no cadence consumer.
- **No `build_runner` / Drift / proto impact** — confirmed.

## Critical Issues

### 1. [UNRESOLVED from plan-review-1] Adding `nominalIntervalMs` to the interface breaks every test fake — `flutter test` will not compile

Plan-review-1 (Critical Issue #1) required a new task to update the test fakes. **This revision of the plan still contains only Tasks 1–5 and adds no such task.** The blocking problem is therefore unchanged.

Dart's `implements` requires every interface member to be implemented explicitly (none of these fakes use `noSuchMethod`). Adding `int get nominalIntervalMs` to `ITickService` (Task 1), and to the concrete `ClockTickService` / `HeartRateTickService` (Tasks 2–3), makes all existing fakes non-compiling. Verified affected fakes — 8 classes across 7 files:

- `test/BreathModule/switchable_tick_service_test.dart` — `_FakeClockTickService implements ClockTickService` **and** `_FakeHeartRateTickService implements HeartRateTickService` (these implement the *concrete* classes, which now also gain the getter, so they break too)
- `test/BreathModule/Presentation/BreathSession/breath_session_state_machine_test.dart` — `FakeTickService`
- `test/BreathModule/Presentation/BreathSession/breath_session_enriched_state_test.dart` — `FakeTickService`
- `test/BreathModule/Presentation/BreathSession/breath_view_model_publication_test.dart` — `_FakeTickService`
- `test/BreathModule/Presentation/BreathSession/breath_session_star_toggle_test.dart` — `_FakeTickService`
- `test/BreathModule/Presentation/BreathSession/breath_animation_coordinator_restart_test.dart` — `_FakeTickService`
- `test/BreathModule/Presentation/BreathSession/orb_animation_coordinator_resume_test.dart` — `_ManualTickService`

**Impact:** Widening an implemented interface is a breaking change for *all* implementers, test fakes included. The whole `flutter test` build fails to compile until every fake adds the getter. The `Testing: no` setting means "write no new tests" — it does not license leaving the existing suite non-compiling.

**Required fix:** Add a Task 6 (Phase 1, depends on Task 1) that adds `@override int get nominalIntervalMs => 1000;` to all 8 fakes listed above. A constant is sufficient — `BreathSessionStateMachine` reads the value once at construction. Until this task exists in the plan, the milestone cannot be completed with a passing build.

## Minor Notes

- **Task 3 (`HeartRateTickService` = 1000)** bakes in a visible correction: a session starting on the heartbeat source seeds `1000 ms` and snaps to the real RR interval on the first beat. This matches the spec's stated intent and the coordinators already tolerate cadence changes — acceptable, and the plan already asks for the clarifying comment.
- The production consumers benefit as intended: `BreathSoundCoordinator` and `BreathAnimationCoordinator` both gate on `currentIntervalMs > 0`, so seeding `1000` makes those branches fire from construction — the milestone goal — with no regression.

## Positive Notes

- Clean separation of *nominal/configured* cadence from *measured* per-tick delta, with an explicit doc-comment instruction to prevent future confusion.
- Tightly scoped: edits only the two initial builders and explicitly enumerates what NOT to touch (`resume`/`pause`/tick folders, `BreathSessionState.initial()`), keeping blast radius small.

---

**Verdict:** The single blocking issue from plan-review-1 (update the test fakes) was **not** incorporated into this revision. Implementing the plan verbatim still leaves the test suite non-compiling. Add the Task 6 described above, then the plan is ready. Not a pass in its current form.
