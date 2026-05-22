import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_l10n/mind_l10n.dart';

import '../BciPairingViewModel.dart';
import '../Models/BciPairingState.dart';
import 'BciSectionHeader.dart';

/// Section that shows the BLE device discovery list with a connection spinner.
class BciDiscoverySection extends ConsumerStatefulWidget {
  const BciDiscoverySection({super.key});

  @override
  ConsumerState<BciDiscoverySection> createState() => _BciDiscoverySectionState();
}

class _BciDiscoverySectionState extends ConsumerState<BciDiscoverySection> {
  String? _pendingSerial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    ref.listen<BciPairingState>(bciPairingViewModelProvider, (prev, next) {
      if (prev != null &&
          prev.isConnecting == true &&
          next.isConnecting == false &&
          _pendingSerial != null) {
        setState(() => _pendingSerial = null);
      }
    });

    final state = ref.watch(bciPairingViewModelProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BciSectionHeader(title: l10n.bciPairingNearbyDevices),
        if (state.isScanning) const LinearProgressIndicator(),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.devices.length,
          itemBuilder: (context, index) {
            final device = state.devices[index];
            final isConnectingThis =
                _pendingSerial == device.serial && state.isConnecting;

            return ListTile(
              leading: isConnectingThis
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bluetooth),
              title: Text(
                device.name,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                device.serial.length > 6
                    ? device.serial.substring(device.serial.length - 6)
                    : device.serial,
              ),
              trailing: device.isKnown
                  ? Chip(
                      label: Text(l10n.bciPairingKnownDevice),
                      visualDensity: VisualDensity.compact,
                    )
                  : null,
              onTap: () {
                setState(() => _pendingSerial = device.serial);
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
