import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../BciDataViewModel.dart';
import '../../BciPairing/Models/BciChannelQualityDTO.dart';

Color _impedanceColor(BciSignalQuality q) {
  switch (q) {
    case BciSignalQuality.good:
      return const Color(0xFFA4F792);
    case BciSignalQuality.fair:
      return const Color(0xFFF8F08D);
    case BciSignalQuality.poor:
      return const Color(0xFFF88D8D);
  }
}

/// Header row for BciDataScreen — shows battery level and channel impedance
/// dots together on the left, with the dots wrapped in a pill background.
/// Tapping opens the pairing flow.
/// Package-internal; not exported from bci_module.dart.
class BciDataHeader extends ConsumerWidget {
  const BciDataHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bciDataViewModelProvider);
    final vm = ref.read(bciDataViewModelProvider.notifier);

    final bool showRealDots = state.isConnected && state.channels.isNotEmpty;

    final Widget channelRow;
    if (showRealDots) {
      channelRow = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < state.channels.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _impedanceColor(state.channels[i].quality),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      );
    } else {
      // Neutral grey placeholders — no signal-quality semantics when disconnected
      channelRow = Opacity(
        opacity: 0.3,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: vm.onHeaderTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Opacity(
              opacity: (state.isConnected && state.batteryPercent != null)
                  ? 1.0
                  : 0.3,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.battery_full, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    state.batteryPercent != null
                        ? '${state.batteryPercent}%'
                        : '--',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(11),
              ),
              child: channelRow,
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
