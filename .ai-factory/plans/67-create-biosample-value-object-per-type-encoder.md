# Plan: Create `BioSample` value object + per-type encoder

## Context
Introduce a single hardware-agnostic `BioSample` value object in `lib/Biometrics/` that wraps the five domain types (`CardioData`, `RrInterval`, `BciNfbData`, `BciEmotionsData`, `MotionData`) into a uniform `{timestampMs, sampleType, data}` shape consumable by the future router/batcher/stream client. Pure data — no I/O, no streams, no `sessionId`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Implementation

- [x] **Task 1: Create `lib/Biometrics/BioSample.dart` with the value object and five factory methods**
  Files: `lib/Biometrics/BioSample.dart`
  Create a new file declaring `final class BioSample` with three `final` fields: `int timestampMs`, `String sampleType`, `Map<String, dynamic> data`, and a `const` constructor with all three as `required` named parameters. Do NOT add a `sessionId` field — the session ID is injected later by `BiometricStreamClient.sendBatch` at wire-encoding time.

  Import the five domain models:
  - `package:mind/Bci/Models/BciEmotionsData.dart`
  - `package:mind/Bci/Models/BciNfbData.dart`
  - `Models/CardioData.dart`
  - `Models/MotionData.dart`
  - `Models/RrInterval.dart`

  Implement five factory constructors. All five MUST use the SDK-supplied physiological `timestamp` field on the source domain model — no `DateTime.now()` anywhere:

  1. `factory BioSample.fromCardio(CardioData cardio)` →
     - `timestampMs: cardio.timestamp.millisecondsSinceEpoch`
     - `sampleType: 'cardio'`
     - `data`: `{'heartRate': cardio.heartRate, 'metricsAvailable': cardio.metricsAvailable, 'hasArtifacts': cardio.hasArtifacts, 'source': cardio.source.name}` plus a nested `'hrv'` sub-map **only when `cardio.hrv != null`** containing `rmssd`, `sdnn`, `pnn50`, `lf`, `hf`, `lfhf` read from `cardio.hrv!`.

  2. `factory BioSample.fromRr(RrInterval rr)` →
     - `timestampMs: rr.timestamp.millisecondsSinceEpoch`
     - `sampleType: 'rr'`
     - `data`: `{'intervalMs': rr.intervalMs, 'isArtifact': rr.isArtifact, 'source': rr.source.name}`. Artifacts are deliberately forwarded — the server decides filtering.

  3. `factory BioSample.fromNfb(BciNfbData nfb)` →
     - `timestampMs: nfb.timestamp.millisecondsSinceEpoch`
     - `sampleType: 'nfb'`
     - `data`: `{'delta': nfb.delta, 'theta': nfb.theta, 'alpha': nfb.alpha, 'smr': nfb.smr, 'beta': nfb.beta, 'source': 'neiry'}`. Hard-code `'source': 'neiry'` because `BciNfbData` has no source field today; when a non-Neiry EEG provider lands, add `source` to the domain model and read from there.

  4. `factory BioSample.fromEmotions(BciEmotionsData emotions)` →
     - `timestampMs: emotions.timestamp.millisecondsSinceEpoch`
     - `sampleType: 'emotions'`
     - `data`: `{'attention': emotions.attention, 'relaxation': emotions.relaxation, 'cognitiveLoad': emotions.cognitiveLoad, 'cognitiveControl': emotions.cognitiveControl, 'selfControl': emotions.selfControl, 'source': 'neiry'}`. Same hard-coded-source rationale as `fromNfb`.

  5. `factory BioSample.fromMotion(MotionData motion)` →
     - `timestampMs: motion.timestamp.millisecondsSinceEpoch` (critical: MEMS arrives in batches, and `DateTime.now()` would collapse a whole batch onto one wall-clock instant)
     - `sampleType: 'motion'`
     - `data`: `{'ax': motion.accelerometer.x, 'ay': motion.accelerometer.y, 'az': motion.accelerometer.z, 'gx': motion.gyroscope.x, 'gy': motion.gyroscope.y, 'gz': motion.gyroscope.z, 'source': motion.source.name}` — six raw axes in device units, no client-side normalization.

  Add a class-level doc comment briefly noting: pure data type, no `sessionId` by design (injected at wire-encoding time in `BiometricStreamClient.sendBatch`), all timestamps come from SDK per-sample clocks. Spec reference: `.ai-factory/notes/28-biometric-stream-pipeline.md` Milestone 5 and `.ai-factory/notes/32-biosample-sdk-timestamps.md`.

<!-- orchestrator-sessions
planner: 2d22859a-4553-4711-b3a9-4e2c0997ad44
elapsed: 427
implementer: 84a2f129-8378-4cc3-8f18-e9c5dbe65a88
-->
