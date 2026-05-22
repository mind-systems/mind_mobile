# Plan: Remove AppBar from BciPairingScreen

## Context
`BciPairingScreen` is the only screen using a system `AppBar`. Replace it with an in-body header row that preserves the three live controls (close, battery indicator, disconnect) so the screen matches the rest of the app's title-bar-less style.

Full spec: `.ai-factory/notes/21-bci-pairing-remove-appbar.md`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Replace AppBar with in-body header

- [x] **Task 1: Delete `BciPairingTopBar.dart`**
  Files: `packages/bci_module/lib/src/BciPairing/Views/BciPairingTopBar.dart`
  Delete the file entirely. It is referenced only from `BciPairingScreen.dart`, which will be updated in Task 2.

- [x] **Task 2: Replace `appBar:` with `_BciPairingHeader` in `BciPairingScreen`** (depends on Task 1)
  Files: `packages/bci_module/lib/src/BciPairing/BciPairingScreen.dart`
  - Remove `appBar: const BciPairingTopBar()` from the `Scaffold`.
  - Remove the `import 'Views/BciPairingTopBar.dart';` line.
  - Add new imports needed by the in-file header widget:
    - `package:mind_l10n/mind_l10n.dart`
    - `Models/BciPairingStage.dart`
    - `Views/BciDisconnectDialog.dart`
  - Insert `_BciPairingHeader()` as the first child of the existing `Column` inside the `SingleChildScrollView`, before `BciDiscoverySection`.
  - Drop the `const` qualifier from the `children:` list (the list is now mixed because `_BciPairingHeader` is non-const); keep `const` on the individual section children where possible.
  - Append a private `_BciPairingHeader` `ConsumerWidget` at the bottom of the same file with this behavior (exactly as in the spec):
    - `Padding` `EdgeInsets.symmetric(horizontal: 4, vertical: 4)` wrapping a `Row`.
    - Leading `IconButton(Icons.close)` → `vm.onClose()`.
    - `Spacer`.
    - Battery group wrapped in `Opacity` (`1.0` if `state.batteryPercent != null`, else `0.3`): inner `Row` with `Icon(Icons.battery_full, size: 16)`, 4px gap, text `"${state.batteryPercent}%"` when present otherwise `"--"`, then 8px trailing gap.
    - `TextButton` with red `foregroundColor` showing `l10n.bciPairingDisconnect`; `onPressed` is `null` when `state.stage == BciPairingStage.discovery`, otherwise calls `showBciDisconnectDialog(context)` and, on `ok && context.mounted`, invokes `vm.onDisconnect()`.
  - The widget reads `bciPairingViewModelProvider` via `ref.watch` and the notifier via `ref.read`; pull `l10n` from `AppLocalizations.of(context)!`.

<!-- orchestrator-sessions
planner: 637cae37-ca81-4bdb-9bff-593995e5384c
implementer: 0fb31532-7406-4f17-af12-3683d3e8d7b6
-->
