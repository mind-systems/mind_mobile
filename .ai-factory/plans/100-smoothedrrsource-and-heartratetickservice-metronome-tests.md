# Test Plan: SmoothedRrSource and HeartRateTickService metronome tests

## Context
`lib/Biometrics/SmoothedRrSource.dart` has zero test coverage, and the existing `test/BreathModule/switchable_tick_service_test.dart` only exercises a hand-written fake of `HeartRateTickService` — never the real free-running metronome, grace window, or replay-dropping logic introduced in the Jun-20 rewrite. This plan adds two new spec files that exercise the real implementations directly via the already-injectable `timerFactory` and `graceWindow` constructor parameters.

## Settings
- Testing: yes
- Logging: minimal
- Docs: no

## Test Command
`/usr/local/bin/flutter test test/Biometrics/smoothed_rr_source_test.dart test/BreathModule/heart_rate_tick_service_test.dart`

## Target Spec Files
- `test/Biometrics/smoothed_rr_source_test.dart`
- `test/BreathModule/heart_rate_tick_service_test.dart`

## Reference Patterns (read before writing)
- `test/Biometrics/active_rr_source_test.dart` — provides the `_FakeTimer implements Timer` + `spyFactory` harness that captures `(delay, cb)` tuples so timers fire manually. Reuse this verbatim for `heart_rate_tick_service_test.dart` (both `_metronome` and `_graceTimer` go through the injected `timerFactory`).
- `test/BreathModule/switchable_tick_service_test.dart` — shows the Dart implicit-interface fake pattern (`class _Fake implements ConcreteClass`). Use this to fake `SmoothedRrSource` in the HeartRateTickService tests and `ActiveRrSource` in the SmoothedRrSource tests.

### Fakes to build
- **`_FakeActiveRrSource implements ActiveRrSource`** (for SmoothedRrSource tests): a broadcast `StreamController<RrInterval>` exposed via `stream`, a mutable `bool hasActiveSource`, and a `BehaviorSubject<bool>` (seeded false) exposed via `hasActiveSourceStream` with an `emitHasActive(bool)` helper. Add an `emit(RrInterval)` helper.
- **`_FakeSmoothedRrSource implements SmoothedRrSource`** (for HeartRateTickService tests): mutable `int? smoothedIntervalMs`, mutable `bool hasActiveSource`, a `BehaviorSubject<int>` exposed via `smoothedIntervalStream` (seed it when simulating the warm path), `hasActiveSourceStream` from a controller, and an `emitSmoothed(int)` helper that pushes to the subject. This gives full control over warm/cold construction paths without standing up a real RR pipeline.
- **`_rr(int intervalMs, {bool isArtifact = false})`** helper building `RrInterval` with `SensorSource.neiry` and a fixed `timestamp` (import `package:mind/Biometrics/Models/SensorSource.dart`).

> **Gotcha — shared timerFactory.** In `HeartRateTickService` both the metronome and the grace timer are created through the same injected `timerFactory`. On the warm path the grace timer is armed in the constructor *before* `start()` schedules the metronome, so captured-timer order is: `[grace, metronome, ...]`. On the cold path no grace timer exists until the first genuine beat. Assert on captured `Duration` values (grace == `graceWindow`, metronome == clamped period) to disambiguate which timer is which rather than relying on index alone.

---

## Tasks

### Phase 1: SmoothedRrSource — `test/Biometrics/smoothed_rr_source_test.dart`

- [x] **Task 1: SmoothedRrSource — initial state**
  Files: `test/Biometrics/smoothed_rr_source_test.dart`
  Test cases:
  - `should return null smoothedIntervalMs before any interval arrives`
  - `should not replay any value to a new subscriber before the first non-artifact interval`

- [x] **Task 2: SmoothedRrSource — SMA over non-artifact intervals**
  Files: `test/Biometrics/smoothed_rr_source_test.dart`
  Test cases:
  - `should expose the single value as the SMA after one interval` (send 500 → `smoothedIntervalMs == 500`)
  - `should average two intervals` (send 500, 600 → `smoothedIntervalMs == 550`) — note: rounded mean, not 600
  - `should compute the SMA of the last 3 intervals once the window fills` (send 500, 600, 700 → `smoothedIntervalMs == 600`)
  - `should drop the oldest sample once the window is full` (send 500, 600, 700, 800 → `smoothedIntervalMs == 700`)
  - `should emit a new SMA on smoothedIntervalStream for every non-artifact interval` (subscribe, send 500, 600, 700 → stream receives `[500, 550, 600]`)
  - `should replay the last SMA to a late subscriber` (send 500, then subscribe → subscriber immediately receives 500)
  - `should reflect only the latest interval when window is 1` (construct with `window: 1`, send 500, 600, 700 → `smoothedIntervalMs` tracks `[500, 600, 700]`)

- [x] **Task 3: SmoothedRrSource — artifact filtering**
  Files: `test/Biometrics/smoothed_rr_source_test.dart`
  Test cases:
  - `should skip artifact intervals when computing the SMA` (send 500, artifact(9999), 600, 700 → `smoothedIntervalMs == 600`; artifact never enters the window)
  - `should not emit and keep smoothedIntervalMs null when only artifacts arrive` (subscribe, send several artifacts → no emission, `smoothedIntervalMs == null`)

- [x] **Task 4: SmoothedRrSource — availability pass-through**
  Files: `test/Biometrics/smoothed_rr_source_test.dart`
  Test cases:
  - `should expose hasActiveSource from the underlying ActiveRrSource` (fake `hasActiveSource == true` → SmoothedRrSource reports true)
  - `should forward hasActiveSourceStream transitions from the underlying ActiveRrSource` (subscribe, fake emits false → received false)

- [x] **Task 5: SmoothedRrSource — dispose**
  Files: `test/Biometrics/smoothed_rr_source_test.dart`
  Test cases:
  - `should close smoothedIntervalStream on dispose (subscribers receive done)`
  - `should stop accepting intervals after dispose` (dispose, then fake emits an interval → no throw, `smoothedIntervalMs` unchanged)
  - `should not dispose or close the underlying ActiveRrSource` (after dispose, the fake ActiveRrSource stream is still open and usable by another subscriber)

### Phase 2: HeartRateTickService — `test/BreathModule/heart_rate_tick_service_test.dart`

- [x] **Task 6: HeartRateTickService — construction & seeding**
  Files: `test/BreathModule/heart_rate_tick_service_test.dart`
  Test cases:
  - `should seed hasActiveSource true from the smoothed source on the warm path` (fake `hasActiveSource == true` → `hasActiveSource == true` before start())
  - `should seed hasActiveSource false on the cold path` (fake `hasActiveSource == false` → `hasActiveSource == false`)
  - `should arm the grace timer at construction on the warm path` (warm fake → a timer with `Duration == graceWindow` is captured before start())
  - `should not arm the grace timer at construction on the cold path` (cold fake → no timer captured before start())
  - `should seed the metronome period from smoothedIntervalMs when available` (fake `smoothedIntervalMs == 600`, call start() → captured metronome `Duration == 600 ms`)
  - `should default the metronome period to 1000 ms when smoothedIntervalMs is null` (cold fake, call start() → captured metronome `Duration == 1000 ms`)

- [x] **Task 7: HeartRateTickService — metronome lifecycle**
  Files: `test/BreathModule/heart_rate_tick_service_test.dart`
  Test cases:
  - `should not schedule the metronome or emit ticks before start() is called` (subscribe to tickStream, emit SMA updates → no metronome timer captured, no ticks)
  - `should emit no immediate/prime tick when start() is called` (subscribe, call start() → no tick before the metronome fires)
  - `should emit a tick with the current period when the metronome fires` (start(), fire captured metronome → tickStream receives `TickData` with `intervalMs == _currentPeriodMs`)
  - `should reschedule the metronome after each fire` (start(), fire metronome → a new metronome timer is captured)
  - `should clamp the period to the 250 ms floor` (fake `smoothedIntervalMs == 100`, start() → captured metronome `Duration == 250 ms` and fired tick `intervalMs == 250`)
  - `should clamp the period to the 3000 ms ceiling` (fake `smoothedIntervalMs == 5000`, start() → captured metronome `Duration == 3000 ms` and fired tick `intervalMs == 3000`)
  - `should expose tickStream as a broadcast stream` (two subscribers both receive a fired tick)

- [x] **Task 8: HeartRateTickService — genuine heartbeat handling**
  Files: `test/BreathModule/heart_rate_tick_service_test.dart`
  Test cases:
  - `should update the metronome period from a genuine beat without emitting a tick` (cold path, start(), emit SMA 600 → no tick on emission; next metronome fire uses 600 ms)
  - `should drop the first replay emission on the warm path and treat the second as genuine` (warm fake seeded with 500, construct → first stream replay does not update period; emit 600 → period becomes 600)
  - `should treat the first emission as genuine on the cold path` (cold fake, emit 600 → period becomes 600, source re-activates)
  - `should re-arm the grace timer on each genuine beat` (cold path, emit 600 then 700 → a fresh grace timer with `Duration == graceWindow` is captured after each beat; previous grace timer is cancelled)

- [x] **Task 9: HeartRateTickService — grace window expiry & auto-fallback**
  Files: `test/BreathModule/heart_rate_tick_service_test.dart`
  Test cases:
  - `should flip hasActiveSource to false when the grace timer fires` (warm path, fire captured grace timer → `hasActiveSource == false`, `hasActiveSourceStream` emits false)
  - `should keep the metronome running after grace expiry (coasts at last period)` (start(), fire grace timer, then fire metronome → tick still emitted even though `hasActiveSource == false`)
  - `should flip hasActiveSource back to true when a beat returns after grace expiry` (fire grace timer → false; emit a genuine SMA → `hasActiveSource == true`)

- [x] **Task 10: HeartRateTickService — ITickService interface**
  Files: `test/BreathModule/heart_rate_tick_service_test.dart`
  Test cases:
  - `should report source as TickSource.heartbeat`
  - `should report nominalIntervalMs as 1000`
  - `should expose sourceChanges as an empty stream`
  - `should return false from trySwitchTo for any target`

- [x] **Task 11: HeartRateTickService — dispose**
  Files: `test/BreathModule/heart_rate_tick_service_test.dart`
  Test cases:
  - `should cancel the metronome timer on dispose` (start(), dispose → captured metronome `FakeTimer.cancelled == true`; firing it would otherwise emit, so no tick after dispose)
  - `should cancel the grace timer on dispose` (warm path, dispose → captured grace `FakeTimer.cancelled == true`)
  - `should stop reacting to smoothed emissions after dispose` (dispose, then fake emits SMA → no throw, `hasActiveSource` unchanged)
  - `should close tickStream on dispose (subscribers receive done)`
  - `should close hasActiveSourceStream on dispose (subscribers receive done)`
  - `should not dispose the underlying SmoothedRrSource` (after dispose, the fake smoothed source is untouched and still usable)
