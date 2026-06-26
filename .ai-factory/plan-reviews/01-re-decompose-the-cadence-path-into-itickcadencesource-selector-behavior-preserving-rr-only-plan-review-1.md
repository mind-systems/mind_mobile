# Plan Review: Re-decompose the cadence path into `ITickCadenceSource` + selector

**Plan:** `.ai-factory/plans/01-re-decompose-the-cadence-path-into-itickcadencesource-selector-behavior-preserving-rr-only.md`
**Spec note:** `.ai-factory/notes/01-tick-cadence-source-contract.md`
**Files Reviewed:** 6 (plan, spec note, `HeartRateTickService.dart`, `SmoothedRrSource.dart`, `BreathModule.dart`, `SwitchableTickService.dart`, `BreathSessionViewModel.dart`, both tick-service tests)
**Risk Level:** 🟡 Medium

The plan is well-researched and almost implementable: line-level citations are accurate, the RR-staleness machinery is correctly relocated verbatim, and `ActiveRrSource` / `SmoothedRrSource` singletons are correctly left untouched. However there is **one blocking defect** (per-session resource leak from an unresolved disposal owner) plus a **behavior-preservation gap** that contradicts the stated "byte-for-byte equivalent" goal and breaks two tests the plan intends to keep.

---

## Context Gates

- **ROADMAP** — `PASS`. This plan is exactly Phase 57, task 1 (`ROADMAP.md:7`). Wording, file locations, and scope (RR-only, behavior-preserving, `ActiveRrSource` out of scope) all match. Good linkage.
- **RULES** — `WARN`. `RULES.md:9` mandates: *"Never wire a class from the outside by calling its methods or subscribing to streams on its behalf — if a class needs a dependency, pass it in the constructor and let the class manage the subscription itself."* This rule directly bears on the disposal defect below: whoever owns the injected `selector` must also own its disposal. The plan leaves that owner undefined.
- **ARCHITECTURE** — `PASS`. New `TickCadence/` classes are pure Dart in the `lib/BreathModule/` domain layer with no Flutter/Riverpod imports — consistent with the layered architecture.

---

## Critical Issues

### 1. Disposal owner of `selector` / `rrCadence` is undefined → per-session leak on the App singleton (BLOCKING)

The plan contradicts both its own spec note and itself on who disposes the per-session cadence objects:

- **Spec note (`01-tick-cadence-source-contract.md:68`):** *"the metronome must dispose the selector, which disposes the RR cadence source."*
- **Plan Task 4:** `dispose()` *"Does **not** dispose the injected `cadence` (the selector is disposed by the owner — see Task 5)."*
- **Plan Task 5 (header):** *"`SwitchableTickService.dispose()` → `_heart.dispose()` → must dispose the selector (which disposes `rrCadence`)."* — then immediately: *"Since Task 4 made the metronome **not** dispose its injected cadence, dispose the `selector` wherever the per-session tick services are torn down (follow the existing teardown path for `tickService`)."*

These cannot all hold. The "existing teardown path" does **not** reach the selector. I traced it:

```
BreathSessionViewModel.dispose()      packages/breath_module/.../BreathSessionViewModel.dart:87
  → tickService.dispose()             (SwitchableTickService)
      → _clock.dispose()              SwitchableTickService.dart:72
      → _heart.dispose()              SwitchableTickService.dart:73
```

`buildSession()` (`BreathModule.dart:31-54`) creates `selector` and `rrCadence` as **local variables** and passes only `tickService` into the ViewModel. There is no teardown hook in `buildSession` and the ViewModel has no reference to the selector. So if Task 4 is followed literally (heart does not dispose cadence), **nothing ever disposes the selector or `rrCadence`.**

Consequence — a real leak that grows per session:
- `RrTickCadenceSource` subscribes to `App.shared.smoothedRrSource.smoothedIntervalStream` (the App-lifetime singleton). An undisposed source leaves a dangling subscription on the singleton on every session open/close.
- The grace `Timer` and the `BehaviorSubject<bool>` inside `RrTickCadenceSource`, plus the selector's subscriptions and subject/controller, also leak.

**Fix (recommended): follow the spec note, not Task 4.** Make `HeartRateTickService.dispose()` dispose its injected `cadence`. This yields a clean, concrete chain:

```
SwitchableTickService.dispose() → _heart.dispose() → cadence(selector).dispose() → rrCadence.dispose()
                                                                                    (does NOT dispose SmoothedRrSource)
```

This matches `RULES.md:9` (the class that received the dependency manages its lifecycle), requires no change to `SwitchableTickService` or `buildSession`, and is byte-compatible with the current ownership model (today `heart.dispose()` is the per-session teardown for the heart path). Update Task 4's bullet accordingly and delete the contradictory "does not dispose cadence" instruction. The `_FakeHeartRateTickService` in `switchable_tick_service_test.dart` is unaffected (its `dispose()` just sets a flag).

> Note: each session builds a fresh `selector` + `rrCadence` dedicated to that session's `heart` (confirmed by the spec note's "stay per-session" decision), so heart-owns-cadence creates no shared-ownership hazard.

---

## Important Issues

### 2. Warm-path metronome seeding changes — violates "byte-for-byte equivalent" and breaks two kept tests

Today (`HeartRateTickService.dart:46`) the metronome seeds `_currentPeriodMs = smoothedRrSource.smoothedIntervalMs ?? 1000` **synchronously at construction**, before `start()`. On the warm path (a live cadence already present, e.g. 500 ms) the very first metronome interval is the smoothed period.

Under the plan:
- Task 4 seeds `_currentPeriodMs` from a fixed default (1000) and receives the period only via `cadence.smoothedPeriodMs`.
- `RrTickCadenceSource.smoothedPeriodMs` is `smoothedRrSource.smoothedIntervalStream`, a `BehaviorSubject` whose replay is delivered **asynchronously** (next microtask).
- `buildSession` calls `..start()` synchronously right after construction.

So on the warm path, `start()` runs while `_currentPeriodMs` is still 1000; the smoothed value (500) arrives one microtask later. **The first metronome interval becomes 1000 ms instead of the smoothed period** — a behavioral divergence from today, contradicting the milestone's core "byte-for-byte equivalent" guarantee.

This also invalidates two tests the plan's Task 6 intends to relocate rather than rewrite:
- `heart_rate_tick_service_test.dart:187` *"should seed the metronome period from smoothedIntervalMs when available"* (expects metronome timer at 600 ms).
- `heart_rate_tick_service_test.dart:207` *"should default the metronome period to 1000 ms when smoothedIntervalMs is null"*.

These are **metronome** assertions (not RR-staleness ones), so the plan's instruction to move the whole "construction & seeding" group into `rr_tick_cadence_source_test.dart` mis-files them, and their assertions no longer hold against the new seam.

**Resolution options (pick one and state it in the plan):**
- (a) Accept and document the one-tick warm-path difference as negligible (sessions usually start cold), and explicitly mark the two tests above as **dropped/rewritten**, not relocated.
- (b) Preserve the behavior by giving `ITickCadenceSource` a synchronous current-period accessor (e.g. `int? get currentPeriodMs`) that the metronome reads to seed `_currentPeriodMs` at construction. This keeps "byte-for-byte" literally true but widens the contract beyond the note.

Either way the plan must stop claiming unconditional byte-for-byte equivalence while silently changing the seed path.

### 3. Test split under-specifies the mixed-assertion cases

Several existing tests assert **both** RR-staleness and metronome behavior in one test and cannot be cleanly "moved" wholesale:
- `:463` *"should treat the first emission as genuine on the cold path"* asserts `hasActiveSource` (RR concern → RR test) **and** that the metronome emits at the updated period 600 (metronome concern → heart test).
- `:431` *"should drop the first replay … treat the second as genuine"* likewise couples the replay-drop (RR) to a metronome emission.

The plan should enumerate, per test, whether it is moved, split into two, rewritten, or dropped — otherwise the "split the suite" instruction is ambiguous for exactly the tests that encode the load-bearing warm/cold replay semantics.

---

## Minor Issues / Nitpicks

- **Stale symbol name `_coastGraceWindow`.** The plan (Task 2, Task 4) and the note cite `_coastGraceWindow` at `:31`/`:54`/`:56`, but no such symbol exists in the current `HeartRateTickService.dart`. The real names are the constructor param `graceWindow` (`:31`) and field `_graceWindow` (`:56`). The line numbers are right; the name is a holdover. Use the actual names to avoid confusing the implementer. (Task 2 does correctly say "mirroring today's `graceWindow` default", so this is just internal inconsistency.)
- **Shared test fake.** Task 6 says reuse "the existing `_FakeSmoothedRrSource`" in the new `rr_tick_cadence_source_test.dart`, but that fake is currently file-private to `heart_rate_tick_service_test.dart` (`:16`). It must be extracted into a shared test helper (or duplicated) before it can be imported by the new file — call this out as a concrete step.
- **Selector re-pipe loses replay semantics.** Task 3 re-exposes `smoothedPeriodMs` via a plain broadcast `StreamController`, which (unlike the underlying `BehaviorSubject`) does not replay. For the single synchronous subscriber (the metronome) this is harmless, but the plan should specify that the selector's `usableChanges` **is a seeded `BehaviorSubject`** mirroring today's `_effectiveActive` (`:35`), since `HeartRateTickService.hasActiveSourceStream` delegates to it and `SwitchableTickService` (`:16`) subscribes expecting the seeded-replay behavior of the current `_effectiveActive.stream`.

---

## Positive Notes

- **Accurate, surgical citations.** Line references into `HeartRateTickService.dart` (`_effectiveActive` `:59`, `_droppedReplay` `:63`, `_armGrace` `:150`, `_onGraceExpired` `:155`, clamps `:115-116`, metronome `:118-129`) are correct, making the relocation low-risk.
- **Correctly identified that RR activation does not subscribe to `hasActiveSourceStream`.** Today's machinery only seeds from `hasActiveSource` at construction and drives activation from smoothed emissions + grace timer. Task 2 mirrors this exactly and does not erroneously add a `hasActiveSourceStream` subscription.
- **Singleton ownership respected.** `RrTickCadenceSource.dispose()` explicitly does not dispose `SmoothedRrSource`, matching the existing `HeartRateTickService.dart:107` contract and the App-singleton model (`App.dart:225-226` left untouched).
- **Scope discipline.** `ActiveRrSource` is correctly out of scope, and the per-session vs App-singleton placement decision is explicit and consistent with the existing tick-service lifetime.
- **Clear two-commit plan** aligned to the phase boundaries.

---

## Verdict

Do not implement as written. Resolve **Issue 1** (assign a concrete disposal owner — recommend the spec note's "heart disposes cadence") and **Issue 2** (reconcile the warm-path seeding change with the byte-for-byte claim and the two affected tests). Issue 3 and the minor items should be folded in for a clean implementation. Once Task 4's disposal bullet is corrected to dispose the injected cadence and the seeding/testing divergence is addressed, the plan is solid.
