# Plan Review (Round 2): Re-decompose the cadence path into `ITickCadenceSource` + selector

**Plan:** `.ai-factory/plans/01-re-decompose-the-cadence-path-into-itickcadencesource-selector-behavior-preserving-rr-only.md`
**Spec note:** `.ai-factory/notes/01-tick-cadence-source-contract.md`
**Round-1 review:** `.ai-factory/plan-reviews/...-plan-review-1.md`
**Files Reviewed:** 7 (plan, spec note, round-1 review, `HeartRateTickService.dart`, `SmoothedRrSource.dart`, `BreathModule.dart`, `SwitchableTickService.dart`, `heart_rate_tick_service_test.dart`, `RULES.md`, `ROADMAP.md`)
**Risk Level:** 🟢 Low

This round-2 plan resolves **all three** round-1 issues and every minor item, with accurate line-level citations. I re-verified the disposal chain, the warm-path seeding fix, and the entire test-disposition table against the actual source and test files. The design is genuinely behavior-preserving for the single-RR-source scope. No blocking defects remain.

---

## Context Gates

- **ROADMAP** — `PASS`. Exact match to Phase 57, task 1 (`ROADMAP.md:7`): `ITickCadenceSource` in `lib/BreathModule/TickCadence/`, `RrTickCadenceSource` absorbs the full `_effectiveActive`/`_droppedReplay`/`_armGrace`/`_onGraceExpired` + 10 s grace machinery, `TickCadenceSelector(List)` pass-through, gutted metronome, RR-only byte-equivalence, `ActiveRrSource`/`App.dart:225-226` untouched. Strong linkage.
- **RULES** — `PASS` (round-1 `WARN` cleared). `RULES.md:3` ("the class that needs a dependency manages its subscription lifecycle") is now honored: Task 4 makes `HeartRateTickService.dispose()` own the injected cadence's disposal, yielding `SwitchableTickService.dispose() → _heart.dispose() → selector.dispose() → rrCadence.dispose()`. No external wiring; no leaked owner.
- **ARCHITECTURE** — `PASS`. New `TickCadence/` classes are pure Dart in the `lib/BreathModule/` domain layer, no Flutter/Riverpod imports — consistent with the layered architecture.

---

## Round-1 Issue Resolution (verified)

- **Issue 1 (BLOCKING — disposal owner):** RESOLVED. Task 4 now explicitly disposes the injected `cadence` and cites the concrete chain; Task 5 confirms "no teardown changes needed" and removes the contradictory "do not dispose cadence" instruction. The per-session lifetime makes heart-owns-cadence safe (each session builds a fresh selector + RR cadence). `SmoothedRrSource` is correctly left undisposed. Verified against `SwitchableTickService.dart:73` (`_heart.dispose()` already on the teardown path).
- **Issue 2 (warm-path seeding):** RESOLVED via option (b). The contract now carries a synchronous `int? get currentPeriodMs`; Task 4 seeds `_currentPeriodMs = cadence.currentPeriodMs ?? 1000` at construction, preserving `HeartRateTickService.dart:46` byte-for-byte. With a single pass-through source, `selector.currentPeriodMs` resolves to `rrCadence.currentPeriodMs == smoothedRrSource.smoothedIntervalMs`, so warm (500/600) and cold (`null → 1000`) seeds both match today. The two affected tests (`:187`, `:207`) are now correctly **rewritten** in the heart test against `FakeTickCadenceSource(currentPeriodMs: …)`, not blindly relocated.
- **Issue 3 (test split ambiguity):** RESOLVED. Task 6 contains a full per-test disposition table (move / rewrite / split / drop) covering all 21 tests. I checked each cited line against `heart_rate_tick_service_test.dart` — every reference is accurate (`:123`, `:139`, `:153`, `:172`, `:187`, `:207`, `:230`–`:391`, `:399`, `:431`, `:463`, `:495`, `:535`, `:558`, `:586`, `:614`–`:651`, `:658`, `:678`, `:696`, `:717`, `:736`, `:755`). The mixed-assertion cases (`:431`, `:463`, `:696`) are correctly marked **split**.
- **Minor (`_coastGraceWindow` name):** RESOLVED. Task 2 explicitly flags that the live symbols are `graceWindow`/`_graceWindow` and there is no `_coastGraceWindow` in `HeartRateTickService.dart` — matches `:31`/`:56`.
- **Minor (shared fake):** RESOLVED. Task 6 adds `test/BreathModule/Fakes/FakeSmoothedRrSource.dart` (extracting the file-private `_FakeSmoothedRrSource` at `:16`) plus a `FakeTickCadenceSource`.
- **Minor (selector seeded replay):** RESOLVED. Task 3 specifies `usableChanges` is a **seeded** `BehaviorSubject<bool>`, mirroring `_effectiveActive` (`HeartRateTickService.dart:35`) so `SwitchableTickService.dart:16` keeps its seeded-replay contract.

---

## Critical Issues

None.

---

## Minor Issues / Observations (non-blocking)

These are clarifications for the implementer, not defects. The plan is implementable as written.

- **Selector initial selection should be computed synchronously at construction.** Task 3 phrases selection as "re-select on any child `usableChanges` event." Because `usableChanges` is a seeded `BehaviorSubject`, the *first* selection could land in an async handler rather than at construction. This does **not** cause a divergence here: the synchronous `currentPeriodMs` seed (Issue 2 fix) covers the metronome's first period regardless, and re-subscribing to a child's `BehaviorSubject` `smoothedPeriodMs` always re-delivers the latest value, so no period is lost. Still, the cleanest implementation reads each child's synchronous `isUsable` getter at construction and establishes the initial inner pipe immediately. Worth stating so the implementer doesn't defer all selection into the async handler.
- **No dedicated `TickCadenceSelector` tests.** The Settings block scopes testing to "relocated assertions, no new coverage," and Task 6 adds none for the selector. That is a conscious choice consistent with the pass-through-for-one-source design, but the selector's re-selection / inner-pipe-cancel logic is genuinely new code. A single smoke test (one source flips usable → period pipes through; flips unusable → `usableChanges` emits false) would be cheap insurance. Optional given the stated scope.
- **`FakeTickCadenceSource.dispose()` must close its `usableChanges` subject** for the `:736` rewrite ("after `dispose()` … `usableChanges` is done") to pass. Implementation detail; flagging so it isn't missed when authoring the fake.
- **Selector adds one extra microtask hop** on the grace→fallback path (`rrCadence` subject → selector re-select → selector subject → `SwitchableTickService`) versus today's single `_effectiveActive` hop. Observably identical (eventual `false` delivery) and no relocated test depends on the exact hop count (RR tests target `RrTickCadenceSource` directly; switchable tests use a fake heart). Noted only for completeness.

---

## Positive Notes

- **Every test line reference is accurate.** I cross-checked all 21 entries in the disposition table against `heart_rate_tick_service_test.dart` — titles and line numbers all line up, including the group spans `:230`–`:391` and `:614`–`:651`.
- **Behavior preservation holds under scrutiny.** The metronome no longer needs the replay-drop guard because the warm replay value equals the synchronous seed (both from `smoothedIntervalMs`), so re-applying it is a no-op; the replay-drop semantics that *do* matter (grace/`isUsable` activation) move intact into `RrTickCadenceSource`. Cold-path first-emission-genuine is preserved by the unseeded `BehaviorSubject`. Verified against `_onSmoothed` (`:133-146`) and the construction seeds (`:39,43,46,49`).
- **Disposal chain is concrete and correct.** Maps cleanly onto the existing `SwitchableTickService.dispose()` (`:67-74`) without touching `SwitchableTickService` or `buildSession` teardown, and preserves the "never dispose the App-owned `SmoothedRrSource`" contract (`SmoothedRrSource.dart:76`, `HeartRateTickService.dart:107`).
- **Byte-for-byte note is precise** about the microtask-ordering hazard it closes (sync `..start()` vs async `BehaviorSubject` replay) and why the sync accessor is required.
- **Scope discipline intact.** `ActiveRrSource` out of scope, singletons untouched, HR source deferred to ROADMAP task 2.

---

## Verdict

The plan resolved all blocking and important findings from round 1, with verified-accurate citations and a behavior-preserving design for the single-RR-source milestone. The remaining items are optional clarifications, not defects. Ready to implement.

PLAN_REVIEW_PASS
