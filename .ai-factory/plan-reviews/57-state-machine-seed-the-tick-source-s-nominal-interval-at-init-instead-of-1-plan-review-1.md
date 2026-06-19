# Plan Review: State machine — seed the tick source's nominal interval at init

**Plan:** `57-state-machine-seed-the-tick-source-s-nominal-interval-at-init-instead-of-1.md`
**Files Reviewed:** 5 plan tasks against 8 codebase files
**Risk Level:** 🟡 Medium — the core design is correct, but one omission breaks the test build.

## Context Gates

- **ARCHITECTURE.md:** No boundary violation. `nominalIntervalMs` is added to the package-side interface `ITickService` and implemented by the concrete services in `lib/BreathModule/`, which is the correct direction (package declares contract, app implements). ✅
- **RULES.md:** The "Module Services must be stateless" rule (line 7) targets `IXxxService` implementations bridging notifiers, not the tick services (which legitimately own `StreamController`s). No conflict. ✅ `WARN` only: none.
- **ROADMAP.md:** Milestone is tracked (note 122 / roadmap entry exist). Linkage present. ✅

## Verified Correct

- **File paths & line numbers are accurate.** `currentIntervalMs: -1` is at line 127 (`_initialRestState`) and line 151 (`_initialBreathState`) exactly as stated. The three production implementers are `ClockTickService`, `HeartRateTickService`, `SwitchableTickService` — all in `lib/BreathModule/`.
- **`ClockTickService` value (1000)** matches the existing `Timer.periodic(Duration(milliseconds: 1000))` and the `TickData(...1000)` it emits. Consistent.
- **`SwitchableTickService` delegation** is sound — `_activeSource` is `late`-initialized to `TickSource.timer` in the constructor body before any external access, so `nominalIntervalMs` reading it is safe.
- **Production consumers benefit as intended.** `BreathSoundCoordinator` (`state.currentIntervalMs > 0 ? ... : 1000`) and `BreathAnimationCoordinator` (`if (state.currentIntervalMs > 0)`) both gate on `> 0`. Seeding `1000` at the origin makes these branches fire from construction — exactly the milestone goal. No regression.
- **Note 40 is correct.** Instruction sending no longer derives `durationMs` from `currentIntervalMs` (per review note 56, the `-1` poisoning was removed; `tickCount` now comes from `currentPhaseTotalDuration`). So seeding does not affect the wire contract.
- **`equalsIgnoringTickFields` claim is correct** — it excludes `currentIntervalMs`, so structural-change detection is unperturbed.
- **Leaving `BreathSessionState.initial()` at `-1`** (Models, line 66) is the right call — it is the pre-load Riverpod state with no cadence consumer.
- **No test asserts on `currentIntervalMs`/`-1`**, so changing the seeded value from `-1` to `1000` breaks no assertions.

## Critical Issues

### 1. Adding `nominalIntervalMs` to the interface breaks every test fake — `flutter test` will not compile

Dart's `implements` requires every interface member to be implemented. Adding `int get nominalIntervalMs` to `ITickService` (Task 1) — and to the concrete `ClockTickService` / `HeartRateTickService` (Tasks 2–3) — makes all existing fake implementations non-compiling, because none of them use `noSuchMethod`; they implement each member explicitly.

Affected fakes (8 classes across 7 files), none mentioned in the plan:

- `test/BreathModule/switchable_tick_service_test.dart` — `_FakeClockTickService implements ClockTickService` **and** `_FakeHeartRateTickService implements HeartRateTickService` (these implement the *concrete* classes, which now also gain the getter — so they break too)
- `test/BreathModule/Presentation/BreathSession/breath_session_state_machine_test.dart` — `FakeTickService`
- `test/BreathModule/Presentation/BreathSession/breath_session_enriched_state_test.dart` — `FakeTickService`
- `test/BreathModule/Presentation/BreathSession/breath_view_model_publication_test.dart` — `_FakeTickService`
- `test/BreathModule/Presentation/BreathSession/breath_session_star_toggle_test.dart` — `_FakeTickService`
- `test/BreathModule/Presentation/BreathSession/breath_animation_coordinator_restart_test.dart` — `_FakeTickService`
- `test/BreathModule/Presentation/BreathSession/orb_animation_coordinator_resume_test.dart` — `_ManualTickService`

**Impact:** The whole `flutter test` build fails to compile until every fake adds `@override int get nominalIntervalMs => 1000;`. The plan's `Testing: no` setting means "do not write new tests" — it does **not** excuse breaking the existing suite's compilation. A widening of an implemented interface is inherently a breaking change for all implementers, test fakes included.

**Required fix:** Add a Task 6 (Phase 1, depends on Task 1) to add the `nominalIntervalMs` getter to all 8 fakes above. A constant `=> 1000` is sufficient for each; the `BreathSessionStateMachine` reads it once at construction, so a literal value is fine. Without this task the milestone cannot be marked done with a passing build.

## Minor Notes

- **Task 3 (`HeartRateTickService` = 1000)** is a reasonable placeholder, but note the asymmetry it bakes in: a session that starts on the heartbeat source will seed `1000 ms` and visibly correct to the real RR interval on the first beat. This matches the spec's stated intent ("overwritten on first real RR tick") and the existing coordinators already tolerate cadence changes, so it is acceptable — just worth the comment the plan already requests.
- **`SwitchableTickService.dispose()` disposes `_clock` and `_heart`**, but `nominalIntervalMs` is a pure getter with no lifecycle — no disposal concern. No action needed.

## Positive Notes

- Clean separation of *nominal/configured* cadence (`nominalIntervalMs`) from *measured* per-tick delta (`TickData.intervalMs`) — the plan explicitly calls this out and instructs a clarifying doc comment, which prevents future confusion (the same confusion documented in handoff 01).
- Correctly scopes the edit to the two state-machine initial builders and explicitly enumerates what NOT to touch (`resume`/`pause`/tick folders, `BreathSessionState.initial()`), reducing blast radius.
- Correctly identifies no `build_runner` / Drift / proto impact.

---

**Verdict:** Resolve Critical Issue #1 (add the fake-update task) and the plan is ready. As written, implementing it verbatim leaves the test suite non-compiling.
