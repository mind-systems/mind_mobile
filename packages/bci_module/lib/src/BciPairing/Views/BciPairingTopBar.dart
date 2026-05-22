import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_l10n/mind_l10n.dart';

import '../BciPairingViewModel.dart';
import '../Models/BciPairingStage.dart';
import 'BciDisconnectDialog.dart';

/// App bar for the BCI pairing screen. Shows battery level and disconnect
/// action when a device is connected.
class BciPairingTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const BciPairingTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(bciPairingViewModelProvider);

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () =>
            ref.read(bciPairingViewModelProvider.notifier).onClose(),
      ),
      title: Text(l10n.bciPairingTitle),
      centerTitle: true,
      actions: [
        if (state.batteryPercent != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.battery_full, size: 16),
                const SizedBox(width: 4),
                Text('${state.batteryPercent}%'),
              ],
            ),
          ),
        if (state.stage != BciPairingStage.discovery)
          TextButton(
            onPressed: () async {
              final ok = await showBciDisconnectDialog(context);
              if (ok && context.mounted) {
                ref
                    .read(bciPairingViewModelProvider.notifier)
                    .onDisconnect();
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.bciPairingDisconnect),
          ),
      ],
    );
  }
}
