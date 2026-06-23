import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_audio/mind_audio.dart';
import 'package:mind_l10n/mind_l10n.dart';

import '../BciPairingViewModel.dart';
import '../Models/BciPairingStage.dart';
import '../Models/BciPairingState.dart';
import 'BciSectionHeader.dart';

class BciCalibrationSection extends ConsumerStatefulWidget {
  const BciCalibrationSection({super.key});

  @override
  ConsumerState<BciCalibrationSection> createState() =>
      _BciCalibrationSectionState();
}

class _BciCalibrationSectionState extends ConsumerState<BciCalibrationSection> {
  late final AudioOneShot _completionCue;
  late final AudioOneShot _stageChime;
  late final AudioOneShot _tick;

  bool _cueReady = false;
  bool _chimeReady = false;

  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _completionCue = AudioOneShot();
    _stageChime = AudioOneShot();
    _tick = AudioOneShot();
    unawaited(_loadCue());
    unawaited(_loadChime());
    unawaited(_loadTick());
  }

  Future<void> _loadCue() async {
    try {
      await _completionCue.load(
        const AudioTrack('packages/bci_module/assets/calibration_complete.wav'),
      );
      if (mounted) setState(() => _cueReady = true);
    } catch (_) {}
  }

  Future<void> _loadChime() async {
    try {
      await _stageChime.load(const AudioTrack('packages/bci_module/assets/stage.wav'));
      if (mounted) setState(() => _chimeReady = true);
    } catch (_) {}
  }

  Future<void> _loadTick() async {
    try {
      await _tick.load(const AudioTrack('assets/audio/tick_clock.ogg'));
    } catch (_) {}
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _tick.dispose();
    _stageChime.dispose();
    _completionCue.dispose();
    super.dispose();
  }

  // Returns the instruction for the currently active stage.
  // activeStage = stagesCompleted + 1 (1-indexed).
  // Stages 1 and 3 (odd) → close eyes; stages 2 and 4 (even) → open eyes.
  String _instruction(BuildContext context, int stagesCompleted) {
    final l10n = AppLocalizations.of(context)!;
    final activeStage = stagesCompleted + 1;
    return activeStage.isOdd ? l10n.bciPairingCloseEyes : l10n.bciPairingOpenEyes;
  }

  // Maps a machine-readable failReason string to a localized message.
  String _failureMessage(BuildContext context, String? failReason) {
    final l10n = AppLocalizations.of(context)!;
    switch (failReason) {
      case 'tooManyArtifacts':
        return l10n.bciPairingCalibrationFailedArtifacts;
      case 'peakFrequencyAtBorder':
        return l10n.bciPairingCalibrationFailedPeak;
      default:
        return l10n.bciPairingCalibrationFailed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    ref.listen<BciPairingState>(bciPairingViewModelProvider, (prev, next) {
      // ── Stage change → play chime and update tick timer ──────────────────
      final prevStages = prev?.calibration?.stagesCompleted;
      final nextStages = next.calibration?.stagesCompleted;
      final inProgress = next.calibration != null &&
          !next.calibration!.isComplete &&
          !next.calibration!.failed;

      if (inProgress && prevStages != nextStages) {
        if (_chimeReady) _stageChime.play();
      }

      // ── Tick timer: run while calibration is in progress ─────────────────
      if (inProgress && _tickTimer == null) {
        _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          _tick.play();
        });
      } else if (!inProgress && _tickTimer != null) {
        _tickTimer?.cancel();
        _tickTimer = null;
      }

      // ── Completion cue ────────────────────────────────────────────────────
      final wasComplete = prev?.calibration?.isComplete == true;
      final isComplete = next.calibration?.isComplete == true;
      if (!wasComplete && isComplete && _cueReady) {
        _completionCue.play();
      }
    });

    final state = ref.watch(bciPairingViewModelProvider);

    final hasFailed = state.calibration?.failed == true;

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BciSectionHeader(title: l10n.bciPairingCalibration),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Text(
            l10n.bciPairingCalibrationInstruction,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        // Primary "Start calibration" button — disabled once a failure is shown
        // (Retry becomes the primary action).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            onPressed: state.stage == BciPairingStage.impedance && !hasFailed
                ? () => ref
                    .read(bciPairingViewModelProvider.notifier)
                    .onStartCalibration()
                : null,
            child: Text(l10n.bciPairingStartCalibration),
          ),
        ),
        // In-progress block: visible while calibration is running (not failed, not complete).
        if (state.calibration != null &&
            !state.calibration!.isComplete &&
            !state.calibration!.failed) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(state.calibration!.totalStages, (i) {
              final filled = i < state.calibration!.stagesCompleted;
              return Padding(
                padding: EdgeInsets.only(
                  right: i < state.calibration!.totalStages - 1 ? 8.0 : 0,
                ),
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
              _instruction(context, state.calibration!.stagesCompleted),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
        // Completion check — only shown when succeeded (not when failed).
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
        // Failure block with localized reason and Retry button.
        if (hasFailed) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _failureMessage(context, state.calibration!.failReason),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: () => ref
                  .read(bciPairingViewModelProvider.notifier)
                  .onRetryCalibration(),
              child: Text(l10n.bciPairingRetryCalibration),
            ),
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
