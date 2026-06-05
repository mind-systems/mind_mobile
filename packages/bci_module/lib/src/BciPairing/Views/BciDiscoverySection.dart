import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_l10n/mind_l10n.dart';
import 'package:permission_handler/permission_handler.dart';

import '../BciPairingViewModel.dart';
import '../Models/BciPairingStage.dart';
import '../Models/BciPairingState.dart';
import 'BciSectionHeader.dart';

/// Section that shows the BLE device discovery list with a connection spinner.
class BciDiscoverySection extends ConsumerStatefulWidget {
  const BciDiscoverySection({super.key});

  @override
  ConsumerState<BciDiscoverySection> createState() => _BciDiscoverySectionState();
}

class _BciDiscoverySectionState extends ConsumerState<BciDiscoverySection>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed &&
        ref.read(bciPairingViewModelProvider).isBluetoothPermissionDenied) {
      ref.read(bciPairingViewModelProvider.notifier).onRescan();
    }
  }

  void _showBluetoothPermissionAlert(BuildContext context, AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.bciBluetoothPermissionTitle),
        content: Text(l10n.bciBluetoothPermissionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: Text(l10n.bciOpenSettings),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    ref.listen<BciPairingState>(bciPairingViewModelProvider, (prev, next) {
      if (prev?.isBluetoothPermissionDenied != true &&
          next.isBluetoothPermissionDenied == true) {
        if (!mounted) return;
        _showBluetoothPermissionAlert(context, l10n);
      }
    });

    final state = ref.watch(bciPairingViewModelProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        if (state.isScanning) const LinearProgressIndicator(),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.devices.length,
          itemBuilder: (context, index) {
            final device = state.devices[index];
            final isThisDevice = state.connectedSerial == device.serial;
            final isConnectedThis =
                isThisDevice && state.stage != BciPairingStage.discovery;
            // Spinner while connecting (isConnecting) or connected but channels
            // not yet arrived.
            final showSpinner =
                isThisDevice && state.channels.isEmpty;

            return ListTile(
              leading: Icon(
                Icons.bluetooth,
                color: isConnectedThis ? Colors.blue : null,
              ),
              title: Text(
                device.name,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                device.serial.length > 6
                    ? device.serial.substring(device.serial.length - 6)
                    : device.serial,
              ),
              trailing: showSpinner
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: isConnectedThis
                  ? null
                  : () {
                      ref
                          .read(bciPairingViewModelProvider.notifier)
                          .onDeviceTap(device.serial);
                    },
            );
          },
        ),
      ],
    );
  }
}
