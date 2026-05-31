import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_ui/mind_ui.dart';
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
    final status = ref.watch(
      meditationSessionViewModelProvider.select((s) => s.status),
    );
    final isActive = status == MeditationSessionStatus.active;

    return Scaffold(
      body: Center(
        child: SizedBox(
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
      ),
    );
  }
}
