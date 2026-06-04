# Plan: Remove known-device chip from discovery list; add connected Bluetooth indicator to pairing header

## Context
Remove the "Paired" chip from BCI discovery list cells and replace the surfacing of connection state with a Bluetooth icon in the pairing header that turns blue when a device is connected. Drop the now-unused `bciPairingKnownDevice` l10n key.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: UI changes

- [x] **Task 1: Remove known-device chip from discovery list**
  Files: `packages/bci_module/lib/src/BciPairing/Views/BciDiscoverySection.dart`
  In the per-device `ListTile` (around lines 132–137), replace the `trailing: device.isKnown ? Chip(...) : null` with `trailing: null`. Leave `device.isKnown` and `BciScannedDeviceDTO.isKnown` in the model untouched — only the UI usage is removed. After this, `l10n.bciPairingKnownDevice` should have no remaining reference in this file.

- [x] **Task 2: Add Bluetooth connected indicator to pairing header**
  Files: `packages/bci_module/lib/src/BciPairing/BciPairingScreen.dart`
  In `_BciPairingHeader.build()` (the `Row` starting at line 57), prepend a `Icon(Icons.bluetooth, size: 16)` as the first child, followed by `const SizedBox(width: 4)`, before the existing battery `Opacity` block. Color it `Colors.blue` when connected and dim white otherwise:
  ```dart
  final isConnected = state.stage != BciPairingStage.discovery;
  // ...
  Icon(
    Icons.bluetooth,
    size: 16,
    color: isConnected ? Colors.blue : Colors.white.withValues(alpha: 0.3),
  ),
  const SizedBox(width: 4),
  ```
  `state` is already watched in this widget — no new provider read needed.

### Phase 2: Localization cleanup

- [x] **Task 3: Delete `bciPairingKnownDevice` from both ARB files** (depends on Task 1)
  Files: `packages/mind_l10n/lib/l10n/app_en.arb`, `packages/mind_l10n/lib/l10n/app_ru.arb`
  Delete the `"bciPairingKnownDevice"` entry (and any associated `@bciPairingKnownDevice` metadata if present) from both ARB files. The English value is currently `"Paired"` (line 125 in `app_en.arb`). Confirm Task 1 removed the only callsite before deleting.

- [x] **Task 4: Regenerate localizations** (depends on Task 3)
  Files: `packages/mind_l10n/lib/l10n/app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_ru.dart` (generated)
  Run the localization codegen so the generated `AppLocalizations` files no longer declare `bciPairingKnownDevice`. From `packages/mind_l10n/`, run `/usr/local/bin/flutter gen-l10n` (or the project's configured l10n generation command). Do not hand-edit the generated files.
