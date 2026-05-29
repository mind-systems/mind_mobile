# Plan: Create `CardioData` + `RrInterval` + `MotionData` value objects in `lib/Biometrics/Models/`

## Context
Pure additive milestone preparing the data layer for the upcoming biometrics refactor (note 27, Milestone 1) and the SDK-timestamp fix (note 32). Introduces a `lib/Biometrics/` directory with five new value objects and extends two existing Phase 19 BCI models with a `timestamp` field — no existing consumer touched besides the two `NeiryBciProvider` mapping handlers that gain the new field.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: New value objects under `lib/Biometrics/Models/`

- [x] **Task 1: Add `SensorSource` enum**
  Files: `lib/Biometrics/Models/SensorSource.dart`
  Create a single-file enum: `enum SensorSource { neiry, garmin, polar, appleHealth }`. This is the shared vendor-identity enum used by `CardioData`, `RrInterval`, and `MotionData`. Today only `neiry` is wired; other values exist so consumers can pattern-match exhaustively without future churn. No imports needed.

- [x] **Task 2: Add `CardioHrvIndices` value object** (depends on Task 1)
  Files: `lib/Biometrics/Models/CardioHrvIndices.dart`
  `final class CardioHrvIndices` with six nullable double fields: `rmssd`, `sdnn`, `pnn50`, `lf`, `hf`, `lfhf`. All optional named parameters in a `const` constructor (`this.rmssd, this.sdnn, this.pnn50, this.lf, this.hf, this.lfhf`). No imports. Follows the same style as existing Phase 19 BCI models (no `@immutable` annotation required; `final class` is sufficient).

- [x] **Task 3: Add `CardioData` value object** (depends on Tasks 1, 2)
  Files: `lib/Biometrics/Models/CardioData.dart`
  `final class CardioData` with fields: `double heartRate`, `bool metricsAvailable`, `bool hasArtifacts`, `DateTime timestamp`, `SensorSource source`, `CardioHrvIndices? hrv`. All required-named except `hrv` (optional, nullable). Const constructor. The `timestamp` field is required and must come from the SDK's `neiry_kit` `CardioData.timestamp` at the call site (the actual mapping lands in a later milestone — this milestone only defines the type). Imports: `CardioHrvIndices.dart`, `SensorSource.dart`.

- [x] **Task 4: Add `RrInterval` value object** (depends on Task 1)
  Files: `lib/Biometrics/Models/RrInterval.dart`
  `final class RrInterval` with required-named fields: `int intervalMs`, `DateTime timestamp`, `bool isArtifact`, `SensorSource source`. Const constructor. Imports: `SensorSource.dart`. This is the raw beat-to-beat substrate from which server-side analytics reconstructs any HRV metric — firmware-computed indices (Neiry stress/Kaplan, Garmin body-battery) are deliberately NOT carried.

- [x] **Task 5: Add `MotionData` value object** (depends on Task 1)
  Files: `lib/Biometrics/Models/MotionData.dart`
  `final class MotionData` with required-named fields: `({double x, double y, double z}) accelerometer`, `({double x, double y, double z}) gyroscope` (Dart records mirroring the SDK's `MemsSample`/`clCPoint3d` triplets), `DateTime timestamp`, `SensorSource source`. Const constructor. Imports: `SensorSource.dart`. Raw device-unit values — normalization happens server-side. `timestamp` must come from SDK per-sample (the actual provider wiring is in a later milestone).

### Phase 2: Backfill `timestamp` on Phase 19 BCI models

- [x] **Task 6: Add `timestamp` to `BciNfbData`**
  Files: `lib/Bci/Models/BciNfbData.dart`
  Add `final DateTime timestamp;` as a **required** named field on the existing `BciNfbData` class. Update the `const` constructor: add `required this.timestamp` to the parameter list (keep all existing `delta`/`theta`/`alpha`/`smr`/`beta` optional fields untouched). No other consumer reads `timestamp` yet — only the constructor signature changes, plus the single call site in Task 8.

- [x] **Task 7: Add `timestamp` to `BciEmotionsData`**
  Files: `lib/Bci/Models/BciEmotionsData.dart`
  Add `final DateTime timestamp;` as a **required** named field on the existing `BciEmotionsData` class. Update the `const` constructor: add `required this.timestamp` to the parameter list (keep all existing `attention`/`relaxation`/`cognitiveLoad`/`cognitiveControl`/`selfControl` optional fields untouched). No other consumer reads `timestamp` yet — only the constructor signature changes, plus the single call site in Task 8.

- [x] **Task 8: Update `NeiryBciProvider` mappers to pass SDK timestamps** (depends on Tasks 6, 7)
  Files: `lib/Bci/NeiryBciProvider.dart`
  Two minimal edits — `BciCardioData` is intentionally NOT touched in this milestone:
  - In `_onNfbState(NfbUserState s)`: add `timestamp: s.timestamp,` to the `BciNfbData(...)` constructor call (the SDK type `NfbUserState` exposes `timestamp: DateTime`).
  - In `_onEmotionsState(EmotionsStates e)`: add `timestamp: e.timestamp,` to the `BciEmotionsData(...)` constructor call (the SDK type `EmotionsStates` exposes `timestamp: DateTime`).
  No other changes — no new imports (both SDK types already in scope), no controller/subscription changes, no signature changes elsewhere. Existing downstream consumers (`BciNotifier`, `BciDataService`, `BciDataScreen`) don't read `timestamp` yet, so this is a transparent additive update.

## Commit Plan
- **Commit 1** (after Tasks 1–5): "Add CardioData, RrInterval, MotionData value objects under lib/Biometrics/Models/"
- **Commit 2** (after Tasks 6–8): "Add SDK timestamp to BciNfbData and BciEmotionsData and wire through NeiryBciProvider"

<!-- orchestrator-sessions
planner: f16dcdad-84d0-4232-9233-dc8cfad4c9ef
elapsed: 474
implementer: f296bfba-5205-4fbd-ac8a-f2318ca0ae5f
-->
