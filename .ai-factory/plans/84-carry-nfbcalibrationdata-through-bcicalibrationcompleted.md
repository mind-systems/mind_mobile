# Plan: Carry `NfbCalibrationData` through `BciCalibrationCompleted`

## Context
Wire the freshly-introduced `NfbCalibrationData` domain model through the calibration event stream so the result of an NFB calibration run is no longer thrown away. Three files change atomically — the event gains a payload, the Neiry adapter populates it by mapping `neiry.IndividualNfbData`, and the device manager destructures the new field (without using it yet — repository wiring happens in a later milestone).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Event payload + producer + consumer

- [x] **Task 1: Add `data` payload to `BciCalibrationCompleted`**
  Files: `lib/Bci/Models/BciCalibrationEvent.dart`
  Extend the sealed event:
  - Add `import 'NfbCalibrationData.dart';` at the top of the file.
  - In `final class BciCalibrationCompleted extends BciCalibrationEvent`:
    - Add `final NfbCalibrationData data;` as the sole field.
    - Update the `const` constructor to `const BciCalibrationCompleted(this.data);` (positional, required — matches the style of `BciCalibrationStageFinished` and `BciCalibrationFailed` which also take a single positional payload).
  - Update the existing Dartdoc on `BciCalibrationCompleted`: replace the "Carries no payload" sentence with a short comment explaining that `data` is the domain-level calibration result mapped from the plugin's `IndividualNfbData` by the concrete `IBciDeviceProvider`. Keep the class-level reminder that plugin types (e.g. `IndividualNfbData`) must not leak into this file — `NfbCalibrationData` is the pure-Dart projection.
  - Do not touch `BciCalibrationStageFinished` or `BciCalibrationFailed`.

- [x] **Task 2: Map `neiry.IndividualNfbData` → `NfbCalibrationData` in `NeiryBciProvider.startCalibration`** (depends on Task 1)
  Files: `lib/Bci/NeiryBciProvider.dart`
  This file is the only place in the project allowed to import `neiry_kit`, so the mapping lives here.
  - The existing `import 'package:neiry_kit/neiry_kit.dart' as neiry;` (line 6) already provides the alias — keep it; no duplicate import.
  - Add `import 'Models/NfbCalibrationData.dart';` next to the other `Models/...` imports (alphabetical block starting around line 20).
  - In `startCalibration()`, update the `switch (event)` branch for `neiry.CalibrationCompleted`:
    - Destructure the payload: `case neiry.CalibrationCompleted(:final data):` (the `neiry.CalibrationCompleted` constructor is `CalibrationCompleted({required this.data})` where `data` is `neiry.IndividualNfbData`).
    - Build a `NfbCalibrationData` value following the mapping table in `.ai-factory/notes/30-nfb-calibration-history.md` (§ "Mapping `IndividualNfbData` → `NfbCalibrationData`"):
      - `calibratedAt: data.timestamp ?? DateTime.now()` — the SDK uses `null` to signal "-1" / unknown.
      - `isValid: data.isValid` — getter on `IndividualNfbData` that returns `failReason == NfbCalibrationFailReason.none`.
      - `failReason: data.failReason.name` — `enum.name` yields `"none"`, `"tooManyArtifacts"`, or `"peakFrequencyAtBorder"`, matching the documented allowed values on `NfbCalibrationData.failReason`.
      - `individualFrequency: data.individualFrequency`
      - `individualPeakFrequencyPower: data.individualPeakFrequencyPower`
      - `individualPeakFrequencySuppression: data.individualPeakFrequencySuppression`
      - `individualBandwidth: data.individualBandwidth`
      - `individualNormalizedPower: data.individualNormalizedPower`
      - `lowerFrequency: data.lowerFrequency`
      - `upperFrequency: data.upperFrequency`
    - Do **not** copy `individualPeakFrequency` (legacy alias of `individualFrequency` — explicitly excluded by the spec).
    - Emit `_calibrationController.add(BciCalibrationCompleted(mapped))` (drop the previous `const` since the value is no longer compile-time constant).
  - Leave the `CalibrationStageFinished` branch and the `onError` handler untouched.
  - No other code in this file changes (subscription bookkeeping, classifier wiring, dispose flow all stay as-is).

- [x] **Task 3: Destructure `data` in `BciDeviceManager` calibration listener** (depends on Task 1)
  Files: `lib/Bci/BciDeviceManager.dart`
  - In `_subscribeProviderStreams()` (note: the milestone description calls this `_subscribeCalibration`; the actual method that subscribes to `_provider.calibrationStream` is `_subscribeProviderStreams`), update the `switch (event)` branch to pattern-match with the new field:
    - Replace `case BciCalibrationCompleted():` with `case BciCalibrationCompleted(:final data):`.
    - Keep the body exactly as today: `if (_state == BciConnectionState.calibrating) _setState(BciConnectionState.ready);`.
    - The destructured `data` is intentionally unused in this milestone. To avoid an `unused_local_variable` lint without suppressing it project-wide, simply discard the binding by renaming the local: use `case BciCalibrationCompleted(data: final _):` (Dart 3 allows `_` as a wildcard name in patterns) — this preserves the explicit "we know the payload exists, repository wiring lands in the final milestone of Phase 24" intent while keeping `flutter analyze` clean.
  - Do not modify any other case (`BciCalibrationStageFinished`, `BciCalibrationFailed`) and do not touch `connectDevice`, `startCalibration`, or any other method — repository wiring is explicitly out of scope.
  - No new imports are needed: `BciCalibrationEvent.dart` is already imported and re-exports `BciCalibrationCompleted` via the same file; `NfbCalibrationData` does not need to be imported here because the field is destructured but unused.

### Cross-cutting verification (no separate task)
After Tasks 1–3 land, every existing exhaustive pattern match on `BciCalibrationEvent` keeps compiling because we only added a field to an existing variant — no new variants were introduced. The only other consumer in the codebase, `lib/BciModule/BciPairingService.dart` (`case BciCalibrationCompleted():` at line 172), continues to compile unchanged: a bare class pattern still matches the variant; it just ignores the new field. That file is intentionally not modified in this milestone.

<!-- orchestrator-sessions
planner: aa84a156-5193-4b08-85f5-642f0067eddb
elapsed: 434
implementer: e80d1760-b323-49c2-96dc-a6de30a322d4
-->
