import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_l10n/mind_l10n.dart';

import 'BciPairingViewModel.dart';
import 'Models/BciPairingStage.dart';
import 'Views/BciCalibrationSection.dart';
import 'Views/BciDisconnectDialog.dart';
import 'Views/BciDiscoverySection.dart';
import 'Views/BciImpedanceSection.dart';

/// Full-screen BCI device pairing flow — discovery, impedance check, and
/// calibration — driven by [bciPairingViewModelProvider].
class BciPairingScreen extends ConsumerStatefulWidget {
  const BciPairingScreen({super.key});

  static const String name = 'bci_pairing';
  static const String path = '/$name';

  @override
  ConsumerState<BciPairingScreen> createState() => _BciPairingScreenState();
}

class _BciPairingScreenState extends ConsumerState<BciPairingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BciPairingHeader(),
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
    );
  }
}

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
          Opacity(
            opacity: state.batteryPercent != null ? 1.0 : 0.3,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.battery_full, size: 16),
                const SizedBox(width: 4),
                Text(state.batteryPercent != null
                    ? '${state.batteryPercent}%'
                    : '--'),
                const SizedBox(width: 8),
              ],
            ),
          ),
          const Spacer(),
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
