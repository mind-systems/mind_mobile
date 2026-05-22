# Remove AppBar from BciPairingScreen

## Problem

`BciPairingScreen` uses `Scaffold.appBar: BciPairingTopBar()` — a standard `AppBar` with title text, a close button, and conditional battery + disconnect actions. The app does not use title bars anywhere else; this screen is inconsistent.

The AppBar carries three real controls that must survive the removal:
- Close button (always visible) → calls `vm.onClose()`
- Battery indicator (when `state.batteryPercent != null`)
- Disconnect button (when `state.stage != BciPairingStage.discovery`) → opens `showBciDisconnectDialog`

## Files to change

### 1. `packages/bci_module/lib/src/BciPairing/Views/BciPairingTopBar.dart`

Delete the file entirely.

### 2. `packages/bci_module/lib/src/BciPairing/BciPairingScreen.dart`

Remove `appBar: const BciPairingTopBar()` from the `Scaffold`.

Remove the import of `BciPairingTopBar`.

Make `_BciPairingScreenState` a `ConsumerStatefulWidget` state (it already is `ConsumerState`) and add a custom header row as the first child of the `Column` inside `SingleChildScrollView`:

```dart
body: SafeArea(
  child: SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BciPairingHeader(),    // ← new
        const BciDiscoverySection(),
        const Divider(height: 1),
        const BciImpedanceSection(),
        const Divider(height: 1),
        const BciCalibrationSection(),
        const SizedBox(height: 16),
      ],
    ),
  ),
),
```

`_BciPairingHeader` is a private `ConsumerWidget` at the bottom of `BciPairingScreen.dart` — keeping it co-located avoids a new file for a trivial widget:

```dart
class _BciPairingHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bciPairingViewModelProvider);
    final vm = ref.read(bciPairingViewModelProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: vm.onClose,
          ),
          const Spacer(),
          Opacity(
            opacity: state.batteryPercent != null ? 1.0 : 0.3,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.battery_full, size: 16),
                const SizedBox(width: 4),
                Text(state.batteryPercent != null ? '${state.batteryPercent}%' : '--'),
                const SizedBox(width: 8),
              ],
            ),
          ),
          TextButton(
            onPressed: state.stage == BciPairingStage.discovery
                ? null
                : () async {
                    final ok = await showBciDisconnectDialog(context);
                    if (ok && context.mounted) vm.onDisconnect();
                  },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.bciPairingDisconnect),
          ),
        ],
      ),
    );
  }
}
```

Add the missing imports to `BciPairingScreen.dart`:
- `package:flutter_riverpod/flutter_riverpod.dart` (already present via ConsumerStatefulWidget)
- `package:mind_l10n/mind_l10n.dart`
- `BciPairingViewModel.dart` (already present)
- `Models/BciPairingStage.dart`
- `Views/BciDisconnectDialog.dart`

Remove the `const` keywords from the section children now that the list is mixed (`_BciPairingHeader` is not const).
