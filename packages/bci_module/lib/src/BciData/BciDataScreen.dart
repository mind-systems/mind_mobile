import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_l10n/mind_l10n.dart';

import 'BciDataViewModel.dart';
import 'Views/BciDataHeader.dart';
import 'Views/BciMetricBar.dart';
import '../BciPairing/Views/BciSectionHeader.dart';

/// Screen that displays live BCI data — heart rate, emotional state bars, and
/// EEG band bars. When the device is not connected, shows an empty state with a
/// "Connect" button that opens the pairing flow.
class BciDataScreen extends ConsumerWidget {
  const BciDataScreen({super.key});

  static const String name = 'bci_data';
  static const String path = '/$name';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bciDataViewModelProvider);
    final vm = ref.read(bciDataViewModelProvider.notifier);
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    final Widget body;

    if (!state.isConnected) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bluetooth_disabled, size: 64),
            const SizedBox(height: 16),
            Text(l10n.bciNotConnectedMessage),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: vm.onConnectPressed,
              child: Text(l10n.bciConnectButton),
            ),
          ],
        ),
      );
    } else {
      body = SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Heart-rate row
              Opacity(
                opacity: state.heartRate != null ? 1.0 : 0.3,
                child: Row(
                  children: [
                    const Icon(Icons.favorite, color: Color(0xFFF88D8D)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.bciHeartRate,
                        style: textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      state.heartRate?.toString() ?? '--',
                      style: textTheme.titleLarge,
                    ),
                    const SizedBox(width: 4),
                    Text(l10n.bciBpm, style: textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Emotional states section
              BciSectionHeader(title: l10n.bciEmotionalStates),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    BciMetricBar(
                      value: state.emotions?.attention,
                      color: const Color(0xFFC88DF8),
                      label: l10n.bciFocus,
                    ),
                    BciMetricBar(
                      value: state.emotions?.cognitiveLoad,
                      color: const Color(0xFFA1BFF6),
                      label: l10n.bciCognitiveLoad,
                    ),
                    BciMetricBar(
                      value: state.emotions?.relaxation,
                      color: const Color(0xFFA4F792),
                      label: l10n.bciRelaxation,
                    ),
                    BciMetricBar(
                      value: state.emotions?.cognitiveControl,
                      color: const Color(0xFFF8C88D),
                      label: l10n.bciCognitiveControl,
                    ),
                    BciMetricBar(
                      value: state.emotions?.selfControl,
                      color: const Color(0xFFF88DB8),
                      label: l10n.bciSelfControl,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // EEG bands section
              BciSectionHeader(title: l10n.bciEegBands),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    BciMetricBar(
                      value: state.nfb?.delta,
                      color: const Color(0xFF8DD6F8),
                      label: 'Delta',
                    ),
                    BciMetricBar(
                      value: state.nfb?.theta,
                      color: const Color(0xFFB48DF8),
                      label: 'Theta',
                    ),
                    BciMetricBar(
                      value: state.nfb?.alpha,
                      color: const Color(0xFFF8F08D),
                      label: 'Alpha',
                    ),
                    BciMetricBar(
                      value: state.nfb?.smr,
                      color: const Color(0xFF8DF8E4),
                      label: 'SMR',
                    ),
                    BciMetricBar(
                      value: state.nfb?.beta,
                      color: const Color(0xFFF8B08D),
                      label: 'Beta',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const BciDataHeader(),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
