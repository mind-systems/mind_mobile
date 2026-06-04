import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_l10n/mind_l10n.dart';

import '../BciPairingViewModel.dart';
import '../Models/BciChannelQualityDTO.dart';
import '../Models/BciPairingStage.dart';
import 'BciSectionHeader.dart';

Color _qualityColor(BciSignalQuality quality) {
  switch (quality) {
    case BciSignalQuality.good:
      return Colors.green;
    case BciSignalQuality.fair:
      return Colors.amber;
    case BciSignalQuality.poor:
      return Colors.red;
  }
}

/// Section showing per-channel signal quality indicators.
class BciImpedanceSection extends ConsumerWidget {
  const BciImpedanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(bciPairingViewModelProvider);

    final channels = state.channels;

    // Always render four circles; use placeholders when channels are empty.
    final int placeholderCount = channels.length < 4 ? 4 - channels.length : 0;

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BciSectionHeader(title: l10n.bciPairingSignalQuality),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ...channels.map((ch) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _qualityColor(ch.quality),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ch.channelName,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        ch.impedanceOhm?.toStringAsFixed(0) ?? '',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.color
                                  ?.withValues(alpha: 0.5),
                            ),
                      ),
                    ],
                  )),
              ...List.generate(
                placeholderCount,
                (_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(' '),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Text(
            l10n.bciPairingAdjustHeadband,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );

    return IgnorePointer(
      ignoring: state.stage == BciPairingStage.discovery,
      child: AnimatedOpacity(
        opacity: state.stage == BciPairingStage.discovery ? 0.38 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: content,
      ),
    );
  }
}
