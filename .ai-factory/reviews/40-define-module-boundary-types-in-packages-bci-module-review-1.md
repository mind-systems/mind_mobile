# Code Review — 40-define-module-boundary-types-in-packages-bci-module

## Code Review Summary

**Files Reviewed:** 9 (7 new source files, 1 modified barrel, 1 modified `analysis_options.yaml`)
**Risk Level:** 🟡 Medium

### Context Gates

- **ARCHITECTURE.md** (`.ai-factory/ARCHITECTURE.md`): PASS — package-side files declare interfaces + DTOs only, contain no Flutter/Riverpod/domain imports, respecting the module boundary.
- **RULES.md** (`.ai-factory/RULES.md`): PASS for what this milestone produces. Rule #1 (stateless services, no `StreamController`/`StreamSubscription`/`dispose()`) targets the concrete service in the next milestone — the abstract `IBciPairingService` here imposes no obstacles and the plan's "Implementer guidance" block points the next agent at the correct pattern.
- **ROADMAP alignment**: PASS — Phase 17, milestone 11 produces only the package boundary types and matches the plan deliverables.

### Critical Issues

**1. `BciPairingState.copyWith` cannot clear nullable fields to `null` — contradicts the plan's reducer contract.** (`packages/bci_module/lib/src/BciPairing/Models/BciPairingState.dart:40-60`)

The `copyWith` implementation uses the `value ?? this.value` pattern for every field, including the three nullable ones: `calibration`, `batteryPercent`, `errorMessage`. With this pattern, `state.copyWith(calibration: null)` is indistinguishable from `state.copyWith()` — the previous value is retained instead of being cleared.

The plan explicitly says this state must be clearable. From Task 5's "Contract note (for the concrete service in the next milestone)":

> on calibration failure (`BciCalibrationFailed(reason)`), the reducer **clears `calibration` (sets it to `null`)**, drops `stage` back to `impedance`, and populates `errorMessage` with the failure reason

The plan also says `calibration == null` means "no active calibration data (e.g. before calibration has started, or after a failure has cleared it)". The current `copyWith` makes that post-failure clear impossible without constructing a fresh `BciPairingState(...)` by hand — defeating the purpose of `copyWith` for the upcoming reducer.

The same issue applies to:
- `errorMessage` — once set on a failure, the reducer cannot clear it on the next successful event via `copyWith(errorMessage: null)`.
- `batteryPercent` — if a battery-cleared/disconnect event arrives, the value cannot be set back to `null`.

Recommended fix (sentinel pattern used widely in Dart for exactly this case):

```dart
// Top of file
const Object _undefined = Object();

BciPairingState copyWith({
  BciPairingStage? stage,
  List<BciScannedDeviceDTO>? devices,
  bool? isScanning,
  bool? isConnecting,
  List<BciChannelQualityDTO>? channels,
  Object? calibration = _undefined,
  Object? batteryPercent = _undefined,
  Object? errorMessage = _undefined,
}) {
  return BciPairingState(
    stage: stage ?? this.stage,
    devices: devices ?? this.devices,
    isScanning: isScanning ?? this.isScanning,
    isConnecting: isConnecting ?? this.isConnecting,
    channels: channels ?? this.channels,
    calibration: identical(calibration, _undefined)
        ? this.calibration
        : calibration as BciCalibrationProgressDTO?,
    batteryPercent: identical(batteryPercent, _undefined)
        ? this.batteryPercent
        : batteryPercent as int?,
    errorMessage: identical(errorMessage, _undefined)
        ? this.errorMessage
        : errorMessage as String?,
  );
}
```

Alternative: a `Wrapped<T>` ValueWrapper, or explicit dedicated helpers (`clearCalibration()`, `clearError()`). Either approach is acceptable — but the current implementation as-is forces the next milestone's reducer to either reconstruct the full state every time it needs to drop a nullable field (defeating the point of `copyWith`) or to add post-hoc clearing helpers later. Better to fix here, before the reducer is written against it.

### Other Findings

- None. The remaining files match the plan, follow `breath_module`'s patterns (PascalCase filenames covered by `analyzer.errors.file_names: ignore` in `analysis_options.yaml`, const constructors with required named parameters, sealed event hierarchy mirroring `BciNotifierEvent`), and have no domain leaks.

### Positive Notes

- Clean separation: only intra-package imports — no `lib/Bci/` or domain types leak into the package. Boundary preserved.
- `IBciPairingService` doc comments explicitly state the rolling-snapshot contract and command-method semantics, which directs the next-milestone implementer toward the RULES.md Rule #1-compliant pattern.
- The `BciPairingServiceEvent` sealed hierarchy with a single `final class BciPairingStateUpdated` variant correctly mirrors the established `BciNotifierEvent` pattern and leaves the door open for future event types.
- `BciCalibrationProgressDTO` carries the invariant docstring required by the plan (range, authoritative `isComplete` signal).
- `BciPairingState.initial()` is a `static` method (per the milestone spec), not a `factory` or `static const` — matches the plan exactly.
- Barrel exports correctly grouped under the existing comment headers and mirror `breath_module`'s organization.
- `analysis_options.yaml` change (`file_names: ignore`) is consistent with the project's PascalCase filename convention used across other packages.
