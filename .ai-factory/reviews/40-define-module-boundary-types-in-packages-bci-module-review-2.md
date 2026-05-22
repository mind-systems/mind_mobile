# Code Review — 40-define-module-boundary-types-in-packages-bci-module (Pass 2)

## Code Review Summary

**Files Reviewed:** 9 (7 new source files, 1 modified barrel, 1 modified `analysis_options.yaml`)
**Risk Level:** 🟡 Medium

No code changes have landed since review-1; this pass re-verifies the same files and re-affirms the previously identified finding. No new issues uncovered.

### Context Gates

- **ARCHITECTURE.md** (`.ai-factory/ARCHITECTURE.md`): PASS — package-side files declare interfaces + DTOs only. No Flutter, Riverpod, or `lib/Bci/` domain imports. The module/domain boundary is preserved.
- **RULES.md** (`.ai-factory/RULES.md`): PASS for this milestone's scope. Rule #1 (stateless services — no `StreamController`/`StreamSubscription`/`dispose()`) targets the *concrete* service in the next milestone; the abstract `IBciPairingService` introduces no obstacles, and the plan's "Implementer guidance" already points the next agent at the correct `scan`-based pattern.
- **Plan alignment**: All 8 tasks in `.ai-factory/plans/40-define-module-boundary-types-in-packages-bci-module.md` produced the expected files, with field ordering, const constructors, sealed event hierarchy, barrel grouping, and PascalCase-friendly `analyzer.errors.file_names: ignore` all matching the spec.

### Critical Issues

**1. `BciPairingState.copyWith` cannot clear nullable fields to `null` — contradicts the plan's reducer contract.** (`packages/bci_module/lib/src/BciPairing/Models/BciPairingState.dart:40-60`)

The `copyWith` uses the standard `value ?? this.value` pattern for every field, including the three nullable ones: `calibration`, `batteryPercent`, `errorMessage`. With this pattern, `state.copyWith(calibration: null)` is indistinguishable from `state.copyWith()` — `null` is interpreted as "field omitted" and the previous value is retained instead of being cleared.

The plan explicitly requires the next-milestone reducer to clear these fields. From Task 5's "Contract note (for the concrete service in the next milestone)":

> on calibration failure (`BciCalibrationFailed(reason)`), the reducer **clears `calibration` (sets it to `null`)**, drops `stage` back to `impedance`, and populates `errorMessage` with the failure reason

The plan further documents that `calibration == null` means "no active calibration data (e.g. before calibration has started, or after a failure has **cleared it**)". With the current `copyWith`, the post-failure clear is impossible — the reducer would have to construct a fresh `BciPairingState(...)` by hand, defeating the purpose of `copyWith`.

The same issue applies to:
- `errorMessage` — once set on a failure, a subsequent successful event cannot clear it via `copyWith(errorMessage: null)`.
- `batteryPercent` — on disconnect or "no value" emissions, the field cannot be reset to `null`.

Recommended fix (standard Dart sentinel pattern):

```dart
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

A `Wrapped<T>`/`ValueWrapper<T>` alternative or dedicated helpers (`clearCalibration()`, `clearError()`) would also work. Either approach is acceptable, but the current implementation forces the next milestone's reducer to either reconstruct the whole state by hand or to retro-add helpers later — better fixed here before the reducer is written against it.

### Other Findings

- None. The remaining files match the plan, follow `breath_module` conventions (PascalCase filenames covered by the `analyzer.errors.file_names: ignore` rule, const constructors with required named parameters, sealed event hierarchy mirroring `BciNotifierEvent`), and contain no domain or Flutter leaks.

### Positive Notes

- Boundary integrity preserved: only intra-package imports — no `lib/Bci/` or domain types leak into the package.
- `IBciPairingService` doc comments explicitly state the rolling-snapshot contract and fire-and-forget command semantics, steering the next-milestone implementer toward the RULES.md Rule #1-compliant `scan`-based pattern.
- The `BciPairingServiceEvent` sealed hierarchy with a single `final class BciPairingStateUpdated` variant correctly mirrors `BciNotifierEvent` and leaves the door open for future events without breaking changes.
- `BciCalibrationProgressDTO` carries the invariant docstring required by the plan (range 0–4, authoritative `isComplete` terminal signal).
- `BciPairingState.initial()` is a `static` method per the milestone spec — not a `factory` or `static const`.
- Barrel exports are correctly grouped under the existing header comments and mirror `breath_module`'s ordering.
- `analysis_options.yaml` change (`file_names: ignore`) is consistent with the PascalCase convention used across the project's packages.
