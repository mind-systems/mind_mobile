# BCI Discovery Section — Retry/Rescan Button

**Date:** 2026-06-02
**Source:** conversation context

## Key Findings

- `BciDiscoverySection` has no recovery path when BLE scanning times out with no device found — user must close and reopen the screen.
- `onRescan()` already exists on `BciPairingViewModel` and calls `service.startScan()` — no ViewModel, Service, or domain changes needed.
- One file changes: wrap the existing `BciSectionHeader` in a `Row` with a conditional `IconButton(Icons.refresh)`.
- Show button when `!state.isScanning && state.stage == BciPairingStage.discovery`.

## Details

### Affected file

`packages/bci_module/lib/src/BciPairing/Views/BciDiscoverySection.dart`

Add import at the top:
```dart
import '../Models/BciPairingStage.dart';
```

Replace the existing header line in `build()`:
```dart
BciSectionHeader(title: l10n.bciPairingNearbyDevices),
```

With:
```dart
Row(
  children: [
    Expanded(child: BciSectionHeader(title: l10n.bciPairingNearbyDevices)),
    if (!state.isScanning && state.stage == BciPairingStage.discovery)
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () =>
              ref.read(bciPairingViewModelProvider.notifier).onRescan(),
        ),
      ),
  ],
),
```

### Guard logic

| `isScanning` | `stage`     | Button visible |
|---|---|---|
| `true`       | any         | No — scan running; `LinearProgressIndicator` signals activity |
| `false`      | `discovery` | **Yes** — scan stopped, no device connected |
| `false`      | `impedance` / `calibrating` / `ready` | No — device already connected |

### Why `BciPairingStage` import is new

`BciDiscoverySection` currently imports `BciPairingState` (which in turn imports `BciPairingStage`), but does not directly import `BciPairingStage`. The enum is needed to reference `BciPairingStage.discovery` in the guard.

### Existing infrastructure reused

- `BciPairingState.isScanning` — already populated by `BciPairingService`
- `BciPairingState.stage` — already populated by `BciPairingService`
- `BciPairingViewModel.onRescan()` — already exists, calls `service.startScan()`
- `BciSectionHeader` — wrapped in `Expanded`, layout unchanged for existing usages

## Verify

1. Open `BciPairingScreen` with no BCI device in range.
2. Scan starts → `LinearProgressIndicator` shows, no retry button.
3. Scan times out → progress bar disappears → `IconButton(Icons.refresh)` appears next to the "Устройства рядом" header.
4. Tap retry → scan restarts, progress bar returns, button disappears.
5. Connect a device → button stays hidden through impedance / calibration stages.
