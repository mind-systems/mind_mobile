# BCI Pairing — Remove Known-Device Badge, Add Connected Bluetooth Indicator

**Date:** 2026-06-02
**Source:** conversation context

## Key Findings

- Remove the `Chip(bciPairingKnownDevice)` trailing from discovery list cells — `isKnown` is no longer surfaced to the user.
- Add a `Icons.bluetooth` icon to `_BciPairingHeader`: blue when connected (`stage != discovery`), dim otherwise.
- Delete the `bciPairingKnownDevice` l10n key from both ARB files — it has no remaining callsite.

## Details

### 1. Remove isKnown chip — `BciDiscoverySection`

**File:** `packages/bci_module/lib/src/BciPairing/Views/BciDiscoverySection.dart`

In the `ListTile` per device, the `trailing` is currently:
```dart
trailing: device.isKnown
    ? Chip(label: Text(l10n.bciPairingKnownDevice), visualDensity: VisualDensity.compact)
    : null,
```

Change to:
```dart
trailing: null,
```

`device.isKnown` field and `BciScannedDeviceDTO.isKnown` stay in the model — no model change needed. Only the UI is removed.

### 2. Add Bluetooth connected indicator — `_BciPairingHeader`

**File:** `packages/bci_module/lib/src/BciPairing/BciPairingScreen.dart`

`_BciPairingHeader` currently shows battery + `Spacer` + disconnect button. Add `Icons.bluetooth` before the battery:

```dart
// in _BciPairingHeader.build():
final isConnected = state.stage != BciPairingStage.discovery;

Row(
  children: [
    Icon(
      Icons.bluetooth,
      size: 16,
      color: isConnected ? Colors.blue : Colors.white.withValues(alpha: 0.3),
    ),
    const SizedBox(width: 4),
    // existing battery row ...
    const Spacer(),
    // existing disconnect button ...
  ],
)
```

No new provider reads needed — `state` is already watched in `_BciPairingHeader`.

### 3. Remove l10n key

**Files:** `packages/mind_l10n/lib/l10n/app_en.arb` and `app_ru.arb`

Delete the `bciPairingKnownDevice` entry from both files. Verify no other widget references `l10n.bciPairingKnownDevice` before deleting.

### Verify

Open pairing screen:
- Discovery list cells no longer show a chip on any device.
- Bluetooth icon in header is dim (0.3 opacity) during scanning.
- After connecting a device, icon turns blue.
- Disconnecting returns the icon to dim.
