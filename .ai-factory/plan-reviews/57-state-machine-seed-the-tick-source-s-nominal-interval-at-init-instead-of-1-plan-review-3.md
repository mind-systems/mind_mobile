# Plan Review 3: State machine — seed the tick source's nominal interval at init

**Plan:** `57-state-machine-seed-the-tick-source-s-nominal-interval-at-init-instead-of-1.md`
**Files Reviewed:** 6 plan tasks against 5 production files + 7 test files
**Risk Level:** 🟢 Low — the blocking issue from plan-review-1 and plan-review-2 is now resolved.

## Context Gates

- **ARCHITECTURE.md:** No boundary violation. `nominalIntervalMs` is declared on the package-side interface `ITickService` (`packages/breath_module/`) and implemented by the concrete services in `lib/BreathModule/`. Package declares the contract, app implements it — correct dependency direction. ✅
- **RULES.md:** No conflict. The tick services legitimately own `StreamController`s; adding a pure getter changes nothing about their statefulness or boundary role. ✅
- **ROADMAP.md:** Milestone tracked (note 122 + roadmap entry line 179). Linkage present. ✅

## Verified Correct (against the code)

- **Resolution of the prior blocker.** Plan-review-1 and plan-review-2 both flagged that widening `ITickService` breaks every explicit fake (none use `noSuchMethod`), leaving `flutter test` non-compiling. This revision adds **Task 6**, which enumerates all affected fakes. Verified the enumeration is exhaustive and correct:
  - `test/BreathModule/switchable_tick_service_test.dart` — `_FakeClockTickService` (line 18, `implements ClockTickService`) and `_FakeHeartRateTickService` (line 47, `implements HeartRateTickService`). These implement the *concrete* classes, which also gain the getter via Tasks 2–3, so they correctly need it too.
  - `test/BreathModule/Presentation/BreathSession/breath_session_state_machine_test.dart` — `FakeTickService` (line 10)
  - `test/BreathModule/Presentation/BreathSession/breath_session_enriched_state_test.dart` — `FakeTickService` (line 19)
  - `test/BreathModule/Presentation/BreathSession/breath_view_model_publication_test.dart` — `_FakeTickService` (line 25)
  - `test/BreathModule/Presentation/BreathSession/breath_session_star_toggle_test.dart` — `_FakeTickService` (line 11)
  - `test/BreathModule/Presentation/BreathSession/breath_animation_coordinator_restart_test.dart` — `_FakeTickService` (line 21)
  - `test/BreathModule/Presentation/BreathSession/orb_animation_coordinator_resume_test.dart` — `_ManualTickService` (line 11)

  A repo-wide grep confirms these 8 classes across 7 files are the *only* implementers of `ITickService` / `ClockTickService` / `HeartRateTickService` outside the three production classes. No implementer is missed.
- **All production implementers covered.** Only `ClockTickService`, `HeartRateTickService`, and `SwitchableTickService` implement `ITickService` in `lib/`. Tasks 2–4 cover all three. No other caller reads `nominalIntervalMs` (it is new), so no other site needs touching.
- **`tickService` is in scope** in both initial builders — `BreathSessionStateMachine` holds `final ITickService tickService` (line 77), reachable from `_initialRestState`/`_initialBreathState`.
- **File paths & line numbers accurate.** `currentIntervalMs: -1` sits at line 127 (`_initialRestState`) and line 151 (`_initialBreathState`) of `BreathSessionStateMachine.dart`, exactly as Task 5 states.
- **`ClockTickService` value (1000)** matches `Timer.periodic(Duration(milliseconds: 1000))` and the `TickData(1000)` it emits (lines 16–17).
- **`SwitchableTickService` delegation is safe** — `_activeSource` is `late`-initialized to `TickSource.timer` in the constructor body (line 14) before any external read; the getter's ternary cannot hit an uninitialized `late`.
- **`equalsIgnoringTickFields` excludes `currentIntervalMs`** (lines 95–109), so seeding a real value does not perturb structural-change detection. Note 50 holds.
- **Leaving `BreathSessionState.initial()` at `-1`** (Models line 66) is correct — it is the pre-load Riverpod loading state with no cadence consumer, distinct from the state-machine builders.
- **No `build_runner` / Drift / proto impact** — confirmed; no generated code or schema is touched.

## Critical Issues

None.

## Minor Notes

- **Task numbering is non-sequential in document order** (Task 6 appears in Phase 1 before Task 5 in Phase 2). Dependencies are stated explicitly (`Task 6 depends on Task 1`, `Task 5 depends on Tasks 2–4`), so execution order is unambiguous — cosmetic only.
- **Task 5's parenthetical line numbers pair method names with field-line numbers** (e.g. "`_initialRestState()` (line 127)" — 127 is the `currentIntervalMs` line, not the method def at 114). The intent is clear and the target field lines are correct; no action needed.
- **Task 3 (`HeartRateTickService` => 1000)** bakes in a one-frame visible correction: a session starting on the heartbeat source seeds `1000 ms`, then snaps to the real RR interval on the first beat. This matches the spec's stated intent; the coordinators already tolerate per-tick cadence changes, so there is no regression. The plan already requires the clarifying placeholder comment.

## Positive Notes

- Clean separation of *nominal/configured* cadence (`nominalIntervalMs`) from *measured* per-tick delta (`TickData.intervalMs`), with an explicit doc-comment instruction (Task 1) to prevent future confusion.
- Tightly scoped: edits only the two initial builders and explicitly enumerates what NOT to touch (`resume`/`pause`, the tick folders, `BreathSessionState.initial()`), keeping blast radius small.
- The previously-blocking test-fake compilation issue is now fully and accurately addressed — the verified fake list matches the codebase exactly.

---

**Verdict:** The single blocking issue carried across plan-reviews 1 and 2 is now resolved by Task 6, with a complete and verified fake enumeration. All file paths, line numbers, scope boundaries, and architectural direction check out. No migrations, no security concerns, no contract impact. Ready to implement.

PLAN_REVIEW_PASS
