# Plan: Add `importCalibration` to `IBciDeviceProvider` + implement in `NeiryBciProvider`

## Context
Expose a new capability on the BCI provider interface to restore a previously-persisted calibration result into the native classifier. The interface gains an abstract `importCalibration(NfbCalibrationData)` method, and the only Neiry-aware implementation maps the domain DTO back to `neiry.IndividualNfbData` and forwards it to `NfbCalibrator.importCalibrationData`. No callers are wired yet — repository integration is the final task of the broader phase and lives in a later milestone.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Interface + Neiry implementation

- [x] **Task 1: Add `importCalibration` to `IBciDeviceProvider`**
  Files: `lib/Bci/IBciDeviceProvider.dart`
  - Add `import 'Models/NfbCalibrationData.dart';` next to the other `Models/...` imports at the top of the file (keep the existing alphabetical block: `BciCalibrationEvent`, `BciChannelQuality`, `BciConnectionState`, `BciDeviceInfo`, then `NfbCalibrationData`).
  - Inside `abstract interface class IBciDeviceProvider`, declare a new abstract method just below `startCalibration()` and above `dispose()`:
    ```dart
    /// Imports a previously-persisted [NfbCalibrationData] into the underlying
    /// NFB calibrator so subsequent sessions can run with prior calibration
    /// results without forcing the user through another calibration sequence.
    ///
    /// This is the reverse direction of the mapping that
    /// [BciCalibrationCompleted] produces: the concrete implementation
    /// translates the pure-Dart domain model back into whatever plugin-level
    /// representation the hardware vendor requires. Plugin types must not
    /// leak through this signature.
    Future<void> importCalibration(NfbCalibrationData data);
    ```
  - Do not touch any existing method, stream getter, or doc comment.
  - The interface must stay free of `neiry_kit` imports — only the domain `NfbCalibrationData` is referenced.

- [x] **Task 2: Implement `importCalibration` in `NeiryBciProvider`** (depends on Task 1)
  Files: `lib/Bci/NeiryBciProvider.dart`
  This is the only file in `mind_mobile` allowed to import `neiry_kit`, so the reverse mapping lives here.
  - The existing `import 'package:neiry_kit/neiry_kit.dart' as neiry;` (line 6) and `import 'Models/NfbCalibrationData.dart';` (already present at line 27) already cover everything needed — no new imports.
  - Add a new section between the existing `startCalibration()` block (ends around line 388) and the `// ── disconnect() ─` separator. Use the same banner-comment style as the surrounding methods:
    ```dart
    // ── importCalibration() ────────────────────────────────────────────────────

    @override
    Future<void> importCalibration(NfbCalibrationData data) async {
      final neiryData = neiry.IndividualNfbData(
        timestamp: data.calibratedAt,
        failReason: neiry.NfbCalibrationFailReason.values
            .firstWhere((e) => e.name == data.failReason),
        individualFrequency: data.individualFrequency,
        individualPeakFrequencyPower: data.individualPeakFrequencyPower,
        individualPeakFrequencySuppression:
            data.individualPeakFrequencySuppression,
        individualBandwidth: data.individualBandwidth,
        individualNormalizedPower: data.individualNormalizedPower,
        lowerFrequency: data.lowerFrequency,
        upperFrequency: data.upperFrequency,
      );
      await neiry.NfbCalibrator.importCalibrationData(neiryData);
    }
    ```
  - Mapping rules (reverse of the forward mapping in `startCalibration()`):
    - `timestamp: data.calibratedAt` — the SDK's `timestamp` is nullable but `NfbCalibrationData.calibratedAt` is non-null; pass it through directly.
    - `failReason: neiry.NfbCalibrationFailReason.values.firstWhere((e) => e.name == data.failReason)` — symmetric with the forward `.name` mapping; the allowed strings (`"none"`, `"tooManyArtifacts"`, `"peakFrequencyAtBorder"`) are documented on `NfbCalibrationData.failReason`. An unknown value will throw `StateError` — acceptable since persisted data always comes from this same enum round-trip.
    - All eight `double` fields map 1:1 by name.
    - Do **not** populate `individualPeakFrequency` — it is a legacy alias of `individualFrequency` in the SDK and is not carried by `NfbCalibrationData`. The `IndividualNfbData` constructor defaults it (`= 10.0`), which is fine because the field is unused by the import path.
  - Do not add any logging — failures propagate as exceptions to the caller; the wider provider already follows this pattern for other write-side operations (e.g. `connect`, `startCalibration`).
  - Do not touch streams, subscriptions, `_calibrationSub`, `disconnect()`, or `_doDispose()` — `importCalibration` is a fire-and-forget write to the native calibrator with no subscription bookkeeping.
  - Leave the existing `startCalibration()` mapping (forward direction) unchanged.

### Cross-cutting verification (no separate task)
After Tasks 1–2 land, `NeiryBciProvider` continues to satisfy `IBciDeviceProvider` because the new abstract method is concretely implemented. No other class in the codebase implements `IBciDeviceProvider` (verified via the absence of additional `implements IBciDeviceProvider` matches), so no other adapter needs updating. The milestone description explicitly notes "No callers yet" — `BciDeviceManager`, `BciPairingService`, and every other consumer of the provider remain untouched in this milestone; wiring lands in the final milestone of Phase 24.

<!-- orchestrator-sessions
planner: fa2e54a9-b459-438a-92f0-771cba0c5871
elapsed: 465
implementer: 01df9928-3e53-4f0a-be70-7b938c5b7455
-->
