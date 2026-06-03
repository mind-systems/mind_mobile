# BioSample Factory Methods — Test Plan

**Date:** 2025-06-03
**Source:** roadmap-test-coverage agent
**File:** /Users/max/projects/mind/mind_mobile/lib/Biometrics/BioSample.dart

## Source Overview

BioSample is a hardware-agnostic wrapper around five domain measurement types (CardioData, RrInterval, BciNfbData, BciEmotionsData, MotionData). Each factory method encodes its domain type into a uniform `{timestampMs, sampleType, data}` shape for the router/batcher/stream client pipeline. All timestamps originate from per-sample SDK clocks, never from DateTime.now(). The BioSample itself is a pure value object with no dependencies.

## Instantiation

All domain models are pure value objects with no external dependencies. Construct them directly in test setup:

- **CardioData**: `heartRate` (double), `metricsAvailable` (bool), `hasArtifacts` (bool), `timestamp` (DateTime), `source` (SensorSource enum), `hrv` (CardioHrvIndices?, nullable)
- **RrInterval**: `intervalMs` (int), `timestamp` (DateTime), `isArtifact` (bool), `source` (SensorSource enum)
- **BciNfbData**: `timestamp` (DateTime), plus five optional double fields (delta, theta, alpha, smr, beta) — each nullable
- **BciEmotionsData**: `timestamp` (DateTime), plus five optional double fields (attention, relaxation, cognitiveLoad, cognitiveControl, selfControl) — each nullable
- **MotionData**: `accelerometer` and `gyroscope` record types (each with x, y, z: double), `timestamp` (DateTime), `source` (SensorSource enum)
- **CardioHrvIndices**: All six fields are optional doubles (rmssd, sdnn, pnn50, lf, hf, lfhf)
- **SensorSource**: Use the enum directly — `SensorSource.neiry`, `SensorSource.garmin`, etc.

No fakes or mocks are needed; wire test inputs directly.

## Existing Coverage

None. BioSample factories have no unit tests.

## Test Cases

### BioSample.fromCardio(CardioData)

**Test 1:** should encode heartRate, metricsAvailable, hasArtifacts, and source.name into data
- Inputs: `CardioData(heartRate: 72.0, metricsAvailable: true, hasArtifacts: false, timestamp: <now>, source: SensorSource.neiry, hrv: null)`
- Expected: `data['heartRate'] == 72.0`, `data['metricsAvailable'] == true`, `data['hasArtifacts'] == false`, `data['source'] == 'neiry'`
- No hrv sub-map should be present when hrv is null.

**Test 2:** should include hrv sub-map when CardioData.hrv is non-null
- Inputs: `CardioData(..., hrv: CardioHrvIndices(rmssd: 50.0, sdnn: 60.0, pnn50: 25.5, lf: 100.0, hf: 150.0, lfhf: 0.67))`
- Expected: `data['hrv']` exists and contains all six fields with correct values.

**Test 3:** should handle partial hrv (some fields null, others populated)
- Inputs: `CardioData(..., hrv: CardioHrvIndices(rmssd: 50.0, sdnn: null, pnn50: null, lf: null, hf: null, lfhf: null))`
- Expected: `data['hrv']['rmssd'] == 50.0`, `data['hrv']['sdnn'] == null`, etc.

**Test 4:** should convert timestamp to millisecondsSinceEpoch
- Inputs: `CardioData(timestamp: DateTime(2025, 6, 3, 10, 30, 45, 123), ...)`
- Expected: `timestampMs` equals the epoch milliseconds of that DateTime.

**Test 5:** should set sampleType to 'cardio'
- Expected: `sampleType == 'cardio'`

**Test 6:** should encode all SensorSource enum values correctly
- Test with each: `SensorSource.neiry` → 'neiry', `SensorSource.garmin` → 'garmin', `SensorSource.polar` → 'polar', `SensorSource.appleHealth` → 'appleHealth'

### BioSample.fromRr(RrInterval)

**Test 7:** should encode intervalMs, isArtifact, and source.name into data
- Inputs: `RrInterval(intervalMs: 800, isArtifact: false, timestamp: <now>, source: SensorSource.neiry)`
- Expected: `data['intervalMs'] == 800`, `data['isArtifact'] == false`, `data['source'] == 'neiry'`

**Test 8:** should forward isArtifact as true (server decides filtering)
- Inputs: `RrInterval(intervalMs: 950, isArtifact: true, ...)`
- Expected: `data['isArtifact'] == true` (not filtered client-side)

**Test 9:** should convert timestamp to millisecondsSinceEpoch
- Inputs: `RrInterval(timestamp: DateTime(2025, 6, 3, 14, 20, 10, 500), ...)`
- Expected: `timestampMs` equals the epoch milliseconds of that DateTime.

**Test 10:** should set sampleType to 'rr'
- Expected: `sampleType == 'rr'`

**Test 11:** should encode all SensorSource enum values correctly
- Test each enum value like in Test 6.

### BioSample.fromNfb(BciNfbData)

**Test 12:** should encode all five band amplitudes (delta, theta, alpha, smr, beta) into data
- Inputs: `BciNfbData(delta: 0.1, theta: 0.2, alpha: 0.3, smr: 0.4, beta: 0.5, timestamp: <now>)`
- Expected: `data['delta'] == 0.1`, `data['theta'] == 0.2`, `data['alpha'] == 0.3`, `data['smr'] == 0.4`, `data['beta'] == 0.5`

**Test 13:** should encode null band values as null
- Inputs: `BciNfbData(delta: 0.1, theta: null, alpha: 0.3, smr: null, beta: 0.5, timestamp: <now>)`
- Expected: `data['delta'] == 0.1`, `data['theta'] == null`, `data['alpha'] == 0.3`, `data['smr'] == null`, `data['beta'] == 0.5`

**Test 14:** should hard-code source to 'neiry' (no source field in BciNfbData)
- Expected: `data['source'] == 'neiry'` (constant, not read from domain model)

**Test 15:** should convert timestamp to millisecondsSinceEpoch
- Expected: `timestampMs` equals the epoch milliseconds of the BciNfbData.timestamp.

**Test 16:** should set sampleType to 'nfb'
- Expected: `sampleType == 'nfb'`

### BioSample.fromEmotions(BciEmotionsData)

**Test 17:** should encode all five emotion classifiers (attention, relaxation, cognitiveLoad, cognitiveControl, selfControl) into data
- Inputs: `BciEmotionsData(attention: 0.8, relaxation: 0.6, cognitiveLoad: 0.7, cognitiveControl: 0.5, selfControl: 0.9, timestamp: <now>)`
- Expected: All five fields present in data with correct values.

**Test 18:** should encode null emotion values as null
- Inputs: `BciEmotionsData(attention: 0.8, relaxation: null, cognitiveLoad: 0.7, cognitiveControl: null, selfControl: 0.9, timestamp: <now>)`
- Expected: null values preserved in data map.

**Test 19:** should hard-code source to 'neiry' (same rationale as fromNfb)
- Expected: `data['source'] == 'neiry'`

**Test 20:** should convert timestamp to millisecondsSinceEpoch
- Expected: `timestampMs` equals the epoch milliseconds of the BciEmotionsData.timestamp.

**Test 21:** should set sampleType to 'emotions'
- Expected: `sampleType == 'emotions'`

### BioSample.fromMotion(MotionData)

**Test 22:** should encode accelerometer triplet (ax, ay, az) into data
- Inputs: `MotionData(accelerometer: (x: 1.5, y: 2.5, z: 3.5), gyroscope: (x: 10.0, y: 20.0, z: 30.0), timestamp: <now>, source: SensorSource.neiry)`
- Expected: `data['ax'] == 1.5`, `data['ay'] == 2.5`, `data['az'] == 3.5`

**Test 23:** should encode gyroscope triplet (gx, gy, gz) into data
- Expected: `data['gx'] == 10.0`, `data['gy'] == 20.0`, `data['gz'] == 30.0`

**Test 24:** should encode source.name (not hard-coded)
- Inputs: `MotionData(..., source: SensorSource.garmin)`
- Expected: `data['source'] == 'garmin'`

**Test 25:** should handle negative acceleration and gyroscope values
- Inputs: `MotionData(accelerometer: (x: -1.5, y: -2.5, z: -3.5), gyroscope: (x: -10.0, y: -20.0, z: -30.0), ...)`
- Expected: Negative values preserved in data.

**Test 26:** should convert timestamp to millisecondsSinceEpoch
- Expected: `timestampMs` equals the epoch milliseconds of the MotionData.timestamp.

**Test 27:** should set sampleType to 'motion'
- Expected: `sampleType == 'motion'`

**Test 28:** should encode all SensorSource enum values correctly
- Test with each enum value like in Test 6.

## Gotchas

1. **SDK timestamps vs DateTime.now()**: All five factories read `<domain>.timestamp.millisecondsSinceEpoch`, never substituting DateTime.now(). MEMS samples (MotionData) arrive in batches — collapsing them to a single wall-clock time would destroy timing precision. Always construct domain models with explicit test DateTime values.

2. **Null hrv sub-map**: In `fromCardio`, the `hrv` sub-map is conditionally included only when `CardioData.hrv != null`. Tests must verify:
   - Absence when hrv is null (check that 'hrv' key does not exist, or is not present in the data map)
   - Presence and full encoding when hrv is provided
   - Partial nullability within hrv (all six fields are optional doubles)

3. **isArtifact forwarding**: In `fromRr`, the `isArtifact` field is deliberately forwarded to the server without client-side filtering. Tests must verify it encodes correctly in both true and false cases. This is **not** a bug — it is a design choice documented in the source comment.

4. **Hard-coded 'neiry' source**: Both `fromNfb` and `fromEmotions` hard-code `'source': 'neiry'` because BciNfbData and BciEmotionsData carry no source field. If a non-Neiry EEG provider lands in the future, the domain model will be extended with a source field and these factories will need updating. Tests should verify the hard-coded value and document this assumption.

5. **Enum.name encoding**: SensorSource is an enum. Use `.name` to encode to string (e.g., `SensorSource.garmin.name == 'garmin'`). Tests must verify all four enum values (neiry, garmin, polar, appleHealth) encode correctly via their `.name` property.

6. **Record types in MotionData**: The accelerometer and gyroscope fields are record types (final positional-only records). Access their x, y, z members directly in test construction: `(x: 1.5, y: 2.5, z: 3.5)`.
