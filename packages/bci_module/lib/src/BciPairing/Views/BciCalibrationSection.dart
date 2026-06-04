import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_audio/mind_audio.dart';
import 'package:mind_l10n/mind_l10n.dart';

import '../BciPairingViewModel.dart';
import '../Models/BciPairingStage.dart';
import '../Models/BciPairingState.dart';
import 'BciSectionHeader.dart';

/// Section showing calibration controls and progress.
class BciCalibrationSection extends ConsumerStatefulWidget {
  const BciCalibrationSection({super.key});

  @override
  ConsumerState<BciCalibrationSection> createState() =>
      _BciCalibrationSectionState();
}

class _BciCalibrationSectionState extends ConsumerState<BciCalibrationSection> {
  late final AudioOneShot _completionCue;
  bool _cueReady = false;
  late final AudioOneShot _tick;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _completionCue = AudioOneShot();
    unawaited(_loadCue());
    _tick = AudioOneShot();
    unawaited(_loadTick());
  }

  Future<void> _loadCue() async {
    final source = await AssetAudioCatalog().sourceFor(
      const AudioTrack('packages/bci_module/assets/calibration_complete.wav'),
    );
    await _completionCue.load(source);
    if (mounted) setState(() => _cueReady = true);
  }

  Future<void> _loadTick() async {
    final source = await AssetAudioCatalog().sourceFor(
      const AudioTrack('assets/audio/tick_clock.ogg'),
    );
    await _tick.load(source);
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _tick.dispose();
    _completionCue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    ref.listen<BciPairingState>(bciPairingViewModelProvider, (prev, next) {
      if (_cueReady &&
          prev != null &&
          prev.calibration?.isComplete != true &&
          next.calibration?.isComplete == true) {
        _completionCue.play();
      }

      final inProgress =
          next.calibration != null && !next.calibration!.isComplete;
      if (inProgress && _tickTimer == null) {
        _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          _tick.play();
        });
      } else if (!inProgress) {
        _tickTimer?.cancel();
        _tickTimer = null;
      }
    });

    final state = ref.watch(bciPairingViewModelProvider);

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BciSectionHeader(title: l10n.bciPairingCalibration),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            onPressed: state.stage == BciPairingStage.impedance
                ? () => ref
                    .read(bciPairingViewModelProvider.notifier)
                    .onStartCalibration()
                : null,
            child: Text(l10n.bciPairingStartCalibration),
          ),
        ),
        if (state.calibration != null && !state.calibration!.isComplete) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final filled = i < state.calibration!.stagesCompleted;
              return Padding(
                padding: EdgeInsets.only(right: i < 3 ? 8.0 : 0),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    border: filled
                        ? null
                        : Border.all(
                            color: Theme.of(context).colorScheme.outline,
                            width: 1,
                          ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              l10n.bciPairingCloseEyes,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
        if (state.calibration?.isComplete == true) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text(l10n.bciPairingCalibrationComplete),
            ],
          ),
        ],
        const SizedBox(height: 16),
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
