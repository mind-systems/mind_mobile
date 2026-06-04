import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_ui/mind_ui.dart';
import 'IMeditationSessionCoordinator.dart';
import 'Models/MeditationSessionState.dart';
import 'MeditationSessionViewModel.dart';

class MeditationSessionScreen extends ConsumerStatefulWidget {
  final VoidCallback? onDispose;

  const MeditationSessionScreen({this.onDispose, super.key});

  static String name = 'meditation_session';
  static String path = '/$name';

  @override
  ConsumerState<MeditationSessionScreen> createState() =>
      _MeditationSessionScreenState();
}

class _MeditationSessionScreenState
    extends ConsumerState<MeditationSessionScreen> {
  @override
  void dispose() {
    widget.onDispose?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<MeditationSessionStatus>(
      meditationSessionViewModelProvider.select((s) => s.status),
      (previous, next) {
        if (previous == MeditationSessionStatus.active &&
            next == MeditationSessionStatus.idle) {
          unawaited(
            ref.read(meditationSessionCoordinatorProvider).onSessionStopped(),
          );
        }
      },
    );

    final status = ref.watch(
      meditationSessionViewModelProvider.select((s) => s.status),
    );
    final poseId = ref.watch(
      meditationSessionViewModelProvider.select((s) => s.poseId),
    );
    final isActive = status == MeditationSessionStatus.active;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 240,
              height: 240,
              child: Image.asset(
                'assets/images/modules/meditation/meditation-pose-${poseId.replaceAll('_', '-')}.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 80,
              height: 80,
              child: ControlButton(
                icon: isActive ? Icons.stop : Icons.play_arrow,
                onPressed: () => isActive
                    ? ref.read(meditationSessionViewModelProvider.notifier).stop()
                    : ref.read(meditationSessionViewModelProvider.notifier).start(),
                iconSize: 40,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
