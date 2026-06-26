# Code Review: Re-decompose the cadence path into `ITickCadenceSource` + selector

**Plan:** `.ai-factory/plans/01-re-decompose-the-cadence-path-into-itickcadencesource-selector-behavior-preserving-rr-only.md`
**Scope reviewed (git diff HEAD):** `ITickCadenceSource.dart`, `RrTickCadenceSource.dart`, `TickCadenceSelector.dart`, `HeartRateTickService.dart`, `BreathModule.dart`, `Fakes/FakeSmoothedRrSource.dart`, `heart_rate_tick_service_test.dart`, `rr_tick_cadence_source_test.dart`
**Risk Level:** 🟢 Low — no correctness bugs found; the refactor is behavior-preserving.

## Build / test status (verified, not assumed)
- `flutter test` for all three tick suites: **50/50 pass**.
- `flutter analyze` on the changed `lib/` + test files: **clean** apart from 4 pre-existing `no_leading_underscores_for_local_identifiers` info lints on the `_timerByDelay` / `_fireByDelay` test helpers — these are carried over verbatim from the original `heart_rate_tick_service_test.dart` and are not introduced by this change.

## Correctness assessment

I traced the full async wiring for both the warm and cold paths against the old monolithic `HeartRateTickService` to confirm byte-for-byte equivalence with a single RR source. It holds:

- **Disposal (was the blocking plan-review issue):** correctly implemented. `HeartRateTickService.dispose()` calls `_cadence.dispose()` (`HeartRateTickService.dart:91`), giving the concrete chain `SwitchableTickService.dispose → _heart.dispose → selector.dispose → rrCadence.dispose`. `RrTickCadenceSource.dispose()` (`:80-85`) cancels the smoothed sub + grace timer + closes the subject and explicitly does **not** dispose the App-owned `SmoothedRrSource`. No per-session leak.
- **Warm-path seed:** `HeartRateTickService` seeds `_currentPeriodMs = cadence.currentPeriodMs ?? 1000` synchronously at construction (`:32`). `selector.currentPeriodMs` falls back to `_sources.first.currentPeriodMs` while `_activeSource` is still null, which for the single RR source resolves to `smoothedRrSource.smoothedIntervalMs` — identical to the old `:46` seed. The async `_reSelect` wiring the pipe later does not affect this.
- **Replay guard relocated verbatim:** `RrTickCadenceSource._onSmoothed` (`:89-101`) preserves the warm/cold `_droppedReplay` semantics exactly. The one warm-path replay value equals the construction seed, so even though the selector pipe now forwards that replay to the metronome (the old code dropped it), `_currentPeriodMs` is numerically unchanged — no divergence.
- **Grace / activation / fallback:** seeding `BehaviorSubject<bool>.seeded(hasActiveSource)`, arm-on-warm-construction, re-arm-on-genuine-beat, and grace-expiry → `isUsable=false` are copied faithfully and verified by the relocated RR tests.
- **Cold-path first-beat period delivery:** works because `SmoothedRrSource.smoothedIntervalStream` is a `BehaviorSubject` — when the selector pipe subscribes *after* the first beat flips the source usable, it receives the latest value as a replay and forwards it to the metronome before the next wall-clock fire. (See Finding 2 — this linchpin is correct but untested.)

## Findings (all non-blocking)

### 1. (LOW) Misleading comment claims synchronous `BehaviorSubject` replay — `TickCadenceSelector.dart:27-33`
The constructor comment states: *"BehaviorSubject replays the current value synchronously on listen, so `_reSelect` is called once per source during construction and the `_activeSource` / pipe subscription are wired up before the constructor returns."*

This is inaccurate. Dart delivers stream events (including rxdart's seeded replay) **asynchronously** — never during the `.listen()` call. In practice `_reSelect` first runs in a later microtask, so `_activeSource` is `null` and `_activePipeSub` is `null` when the constructor returns. The code is nonetheless correct because `_isUsable` is seeded directly via `_anyUsable()` (`:25`) and `currentPeriodMs` falls back to `_sources.first` (`:55`), covering the pre-`_reSelect` window. Recommend rewording the comment so a future maintainer doesn't rely on synchronous wiring that doesn't exist.

### 2. (MEDIUM) Test gap: the behavior-preservation linchpin and the selector itself are untested
The "byte-for-byte" guarantee for the **cold path** rests on a subtle async interaction: first genuine beat → `RrTickCadenceSource` flips usable → `TickCadenceSelector._reSelect` subscribes its pipe → relies on the `SmoothedRrSource` BehaviorSubject **replaying the latest value to the late subscriber** → metronome `_currentPeriodMs` updates. None of the tests exercise this:
- `heart_rate_tick_service_test.dart` drives a `FakeTickCadenceSource` that emits directly on its own controller — it bypasses the real selector/RR glue.
- `rr_tick_cadence_source_test.dart` never touches the metronome.
- There is **no `TickCadenceSelector` test at all** (no pass-through, re-selection, late-subscribe-replay, or dispose-fans-to-children coverage), and no integration test wiring `rrCadence → selector → heart`.

The production path is correct, but the milestone's central claim hinges on untested code. Recommend adding (a) a `TickCadenceSelector` unit test (single-source pass-through, `currentPeriodMs` fallback, re-selection on `usableChanges`, dispose disposes children), and (b) a small integration test asserting that a cold-path first beat reaches the metronome period. This does not block the current change but should be folded in before relying on the selector for the HR source (note 164).

### 3. (LOW, forward-looking) `currentPeriodMs` fallback is only correct for a single source — `TickCadenceSelector.dart:55`
`(_activeSource ?? _sources.first).currentPeriodMs` returns the first source's snapshot whenever no source is usable, ignoring priority/usability. Harmless for the RR-only scope (one source), but when the HR source is added this fallback should be revisited (e.g. prefer the highest-priority source that has a non-null snapshot). Worth a `TODO` referencing note 164.

## Notes (no action required)
- Two subscribers now listen to the shared App-singleton `smoothedIntervalStream` (`RrTickCadenceSource._smoothedSub` and the selector pipe). This is safe — it is a broadcast `BehaviorSubject`, both are cancelled on dispose, and the extra warm-replay forwarding is value-identical to the old behavior.
- `BreathModule.dart` wiring (`:35-37`) matches the plan exactly; `SwitchableTickService`, `App.dart` singletons, and the `switchable_tick_service_test.dart` fake are correctly left untouched (its `implements HeartRateTickService` fake is unaffected since no public getter names changed).
- Doc comments in `ITickCadenceSource.dart` / `RrTickCadenceSource.dart` reference unimported symbols (`[BehaviorSubject]`, `[HeartRateTickService]`, etc.). `comment_references` is not enabled in `analysis_options.yaml`, so analyze stays clean — no action needed.

## Verdict
No correctness, security, or runtime-breaking issues. The disposal defect and warm-path seeding concern from the plan review are both correctly resolved. The findings above are quality/coverage improvements, with Finding 2 (test gap on the behavior-preservation linchpin) the most worth addressing before the HR source builds on this seam.
