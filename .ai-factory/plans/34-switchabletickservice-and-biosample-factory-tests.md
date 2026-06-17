# Test Plan: SwitchableTickService and BioSample factory tests

## Context
Two zero-coverage units get unit tests: `SwitchableTickService` (a tick-source decorator that switches between clock and heart-rate sources and auto-falls-back when the heart source goes silent) and the five `BioSample` factory methods (pure encoders from domain models to the uniform `{timestampMs, sampleType, data}` wire shape). Both are testable as-is with no infra refactor.

## Settings
- Testing: yes
- Logging: minimal
- Docs: no

## Test Command
`flutter test test/BreathModule/switchable_tick_service_test.dart test/Biometrics/bio_sample_factories_test.dart`

(Project note: invoke flutter via its absolute path `/usr/local/bin/flutter` if `flutter` is not on PATH.)

## Target Spec Files
- `test/BreathModule/switchable_tick_service_test.dart`
- `test/Biometrics/bio_sample_factories_test.dart`

---

## Implementation Notes (read before writing tests)

### SwitchableTickService — fake typing constraint (critical)
The constructor signature is `SwitchableTickService({required ClockTickService clock, required HeartRateTickService heart})` — it demands the **concrete** `ClockTickService` / `HeartRateTickService` types, not `ITickService`. Therefore the fakes must use Dart's implicit-interface feature and declare:
- `class _FakeClockTickService implements ClockTickService { ... }`
- `class _FakeHeartRateTickService implements HeartRateTickService { ... }`

A fake that only `implements ITickService` will **not** type-check against the constructor. Each fake must override every member of the concrete class:
- `_FakeClockTickService`: inject a `StreamController<TickData>.broadcast()` for `tickStream`; expose a `bool disposed` flag set in `dispose()`; stub `source => TickSource.timer`, `sourceChanges => const Stream.empty()`, `trySwitchTo => false`, and a no-op `simulateTick()`.
- `_FakeHeartRateTickService`: inject a `StreamController<TickData>.broadcast()` for `tickStream`, a mutable `bool hasActiveSource`, and a `StreamController<bool>.broadcast()` for `hasActiveSourceStream`; expose a `bool disposed` flag set in `dispose()`; stub `source => TickSource.heartbeat`, `sourceChanges => const Stream.empty()`, `trySwitchTo => false`.

`tickStream` and `sourceChanges` on the SUT are **broadcast** streams — subscribe before pushing events, and use `addTearDown` to dispose the SUT and close fake controllers so tests don't hang. Push fake ticks via the injected controllers; the SUT forwards only the currently-active source's controller.

### BioSample factories — direct construction
All five factories are pure functions; construct domain models directly, no fakes/mocks. Use **explicit** `DateTime` literals (e.g. `DateTime(2025, 6, 3, 10, 30, 45, 123)`) and assert `timestampMs == <that DateTime>.millisecondsSinceEpoch` to prove SDK timestamps are used rather than `DateTime.now()`. `SensorSource` is an enum encoded via `.name` (`neiry`, `garmin`, `polar`, `appleHealth`). `MotionData.accelerometer`/`gyroscope` are positional-named records `({double x, double y, double z})`. The `hrv` sub-map in `fromCardio` is present only when `CardioData.hrv != null`.

---

## Tasks

### Phase 1: BioSample factory encoders (pure, no fakes)

- [x] **Task 1: BioSample.fromCardio**
  Files: `test/Biometrics/bio_sample_factories_test.dart`
  Test cases:
  - `should set sampleType to 'cardio' and timestampMs from cardio.timestamp.millisecondsSinceEpoch when given a CardioData`
  - `should encode heartRate, metricsAvailable, hasArtifacts and source.name into data when given a CardioData`
  - `should omit the hrv sub-map when cardio.hrv is null`
  - `should include the full hrv sub-map with all six indices when cardio.hrv is non-null`
  - `should preserve nulls in the hrv sub-map when only some hrv indices are populated`
  - `should encode each SensorSource value via .name when given that source` (neiry, garmin, polar, appleHealth)

- [x] **Task 2: BioSample.fromRr**
  Files: `test/Biometrics/bio_sample_factories_test.dart`
  Test cases:
  - `should set sampleType to 'rr' and timestampMs from rr.timestamp.millisecondsSinceEpoch when given an RrInterval`
  - `should encode intervalMs and source.name into data when given an RrInterval`
  - `should forward isArtifact as false when rr.isArtifact is false`
  - `should forward isArtifact as true when rr.isArtifact is true` (no client-side filtering)
  - `should encode each SensorSource value via .name when given that source`

- [x] **Task 3: BioSample.fromNfb**
  Files: `test/Biometrics/bio_sample_factories_test.dart`
  Test cases:
  - `should set sampleType to 'nfb' and timestampMs from nfb.timestamp.millisecondsSinceEpoch when given a BciNfbData`
  - `should encode all five band amplitudes (delta, theta, alpha, smr, beta) into data when all bands are present`
  - `should preserve null band values as null when some bands are unset`
  - `should hard-code source to 'neiry' regardless of input` (model carries no source field)

- [x] **Task 4: BioSample.fromEmotions**
  Files: `test/Biometrics/bio_sample_factories_test.dart`
  Test cases:
  - `should set sampleType to 'emotions' and timestampMs from emotions.timestamp.millisecondsSinceEpoch when given a BciEmotionsData`
  - `should encode all five emotion fields (attention, relaxation, cognitiveLoad, cognitiveControl, selfControl) into data when all are present`
  - `should preserve null emotion values as null when some fields are unset`
  - `should hard-code source to 'neiry' regardless of input`

- [x] **Task 5: BioSample.fromMotion**
  Files: `test/Biometrics/bio_sample_factories_test.dart`
  Test cases:
  - `should set sampleType to 'motion' and timestampMs from motion.timestamp.millisecondsSinceEpoch when given a MotionData` (per-sample SDK timestamp, not wall-clock)
  - `should encode the accelerometer triplet into ax, ay, az when given a MotionData`
  - `should encode the gyroscope triplet into gx, gy, gz when given a MotionData`
  - `should encode source.name (not hard-coded) when given a MotionData`
  - `should preserve negative accelerometer and gyroscope values when given negative inputs`

### Phase 2: SwitchableTickService — construction & tick forwarding

- [x] **Task 6: Construction and initial source**
  Files: `test/BreathModule/switchable_tick_service_test.dart`
  Test cases:
  - `should expose source as TickSource.timer when constructed`
  - `should forward clock ticks through tickStream when constructed (initial active source is clock)`
  - `should not forward heart ticks through tickStream when active source is timer`
  - `should expose tickStream as a broadcast stream supporting multiple independent subscribers`

### Phase 3: SwitchableTickService — trySwitchTo

- [x] **Task 7: trySwitchTo behavior**
  Files: `test/BreathModule/switchable_tick_service_test.dart`
  Test cases:
  - `should return true and forward heart ticks (stop forwarding clock ticks) when switching to heartbeat and heart.hasActiveSource is true`
  - `should return false and leave source unchanged when switching to heartbeat and heart.hasActiveSource is false`
  - `should return true and forward clock ticks again when switching back to timer from heartbeat`
  - `should return true and emit nothing on sourceChanges when target equals the already-active source`
  - `should emit the new source on sourceChanges only when an actual switch occurs`

### Phase 4: SwitchableTickService — auto-fallback

- [x] **Task 8: Auto-fallback on source-lost event**
  Files: `test/BreathModule/switchable_tick_service_test.dart`
  Test cases:
  - `should revert source to TickSource.timer when active is heartbeat and hasActiveSourceStream emits false`
  - `should emit TickSource.timer on sourceChanges when auto-fallback triggers`
  - `should forward clock ticks (not heart ticks) after auto-fallback`
  - `should not switch or emit when active is timer and hasActiveSourceStream emits false` (condition guards on heartbeat-active only)

### Phase 5: SwitchableTickService — dispose

- [x] **Task 9: Dispose propagation and cleanup**
  Files: `test/BreathModule/switchable_tick_service_test.dart`
  Test cases:
  - `should call dispose on the clock delegate when disposed`
  - `should call dispose on the heart delegate when disposed`
  - `should close tickStream (subscribers receive done) when disposed`
  - `should close sourceChanges (subscribers receive done) when disposed`
  - `should stop reacting to hasActiveSourceStream after dispose` (health subscription cancelled — no fallback emitted)
