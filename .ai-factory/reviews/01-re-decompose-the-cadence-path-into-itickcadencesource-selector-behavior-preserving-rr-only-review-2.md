# Code Review 2: Re-decompose the cadence path into `ITickCadenceSource` + selector

**Plan:** `.ai-factory/plans/01-re-decompose-the-cadence-path-into-itickcadencesource-selector-behavior-preserving-rr-only.md`
**Scope reviewed (git diff HEAD):** `ITickCadenceSource.dart`, `RrTickCadenceSource.dart`, `TickCadenceSelector.dart`, `HeartRateTickService.dart`, `BreathModule.dart`, `Fakes/FakeSmoothedRrSource.dart`, `heart_rate_tick_service_test.dart`, `rr_tick_cadence_source_test.dart`, `tick_cadence_selector_test.dart`
**Risk Level:** 🟢 Low — no correctness, security, or runtime-breaking issues. Behavior-preserving for the single RR source.

## Build / test status (verified, not assumed)
- `flutter test test/BreathModule/`: **281/281 pass**, including the new `tick_cadence_selector_test.dart` (selector unit tests + the cold-path/warm-path integration tests).
- `flutter analyze lib/BreathModule test/BreathModule`: **no errors/warnings**. The 7 reported items are all pre-existing **info**-level style lints in test files (`no_leading_underscores_for_local_identifiers`, `unnecessary_underscores`, `prefer_function_declarations_over_variables`) — none in the new production code, none introduced as regressions.

## Resolution of review-1 findings
All three findings from `review-1.md` are addressed:
1. **(was LOW) Misleading "synchronous replay" comment** — fixed. `TickCadenceSelector.dart:27-32` now correctly states the `BehaviorSubject` replay is delivered asynchronously and explains why pre-`_reSelect` correctness holds (direct `_anyUsable()` seed + `currentPeriodMs` fallback to `_sources.first`).
2. **(was MEDIUM) Untested behavior-preservation linchpin / no selector test** — resolved. `tick_cadence_selector_test.dart` adds construction, `smoothedPeriodMs` forwarding (subscribe/cancel on usable transitions), `usableChanges`, and dispose coverage, plus a full-chain **integration test** (`FakeSmoothedRrSource → RrTickCadenceSource → TickCadenceSelector → HeartRateTickService`) asserting the cold-path first beat updates the metronome period before its next fire, and a warm-path test asserting the synchronous seed.
3. **(was LOW, forward-looking) `currentPeriodMs` fallback** — a `TODO(note-164)` (`TickCadenceSelector.dart:57-59`) now documents that the `_sources.first` fallback must be revisited when the HR source is added.

## Correctness re-verification
I re-traced the async wiring against the old monolith; equivalence holds with one RR source:
- **Disposal chain** (`HeartRateTickService.dart:91` → `TickCadenceSelector.dispose` → `RrTickCadenceSource.dispose`) is single-owner, disposes children, cancels the selector's pipe subscription to the App-singleton stream first, and never disposes `SmoothedRrSource`. No per-session leak. `BreathModule.dart:35-37` wires this correctly and leaves `SwitchableTickService` and the `App.dart` singletons untouched.
- **Warm-path seed**: `_currentPeriodMs = cadence.currentPeriodMs ?? 1000` resolves synchronously to `smoothedRrSource.smoothedIntervalMs` via the selector's null-active fallback — identical to the old `:46` seed. Confirmed by the warm-path integration test (first tick = 500).
- **Cold-path period delivery**: first genuine beat flips `isUsable` → `_reSelect` pipes to the RR `BehaviorSubject`, whose late-subscribe replay forwards the latest value to the metronome before the next fire. Now covered by an explicit integration test (first tick = 600).
- **Replay guard / grace / fallback** in `RrTickCadenceSource` are copied verbatim and covered by `rr_tick_cadence_source_test.dart`.

## Notes (no action required)
- `dispose()` on both `TickCadenceSelector` and `RrTickCadenceSource` is not idempotent (`_isUsable.close()` is unguarded — a second call would throw). This is unreachable given the strict single-owner chain and is consistent with the pre-existing `HeartRateTickService.dispose()` behavior, so it is not a regression.
- The selector pipe and `RrTickCadenceSource._smoothedSub` are two independent listeners on the shared App-singleton `smoothedIntervalStream` (broadcast `BehaviorSubject`); both are cancelled on dispose. Safe and intentional.

## Verdict
The implementation is correct and behavior-preserving, the prior review's issues are fully resolved, tests pass, and analyze is clean. No findings.

REVIEW_PASS
