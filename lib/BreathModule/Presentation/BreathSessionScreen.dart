import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mind/BreathModule/Presentation/BreathSessionState.dart';
import 'package:mind/BreathModule/Presentation/BreathViewModel.dart';
import 'package:mind/BreathModule/Presentation/Views/BreathWidget.dart';

/// Экран дыхательной сессии
class BreathSessionScreen extends ConsumerStatefulWidget {
  const BreathSessionScreen({super.key});

  static String name = 'breath_session';
  static String path = '/$name';

  @override
  ConsumerState<BreathSessionScreen> createState() => _BreathSessionScreenState();
}

class _BreathSessionScreenState extends ConsumerState<BreathSessionScreen> {
  @override
  void initState() {
    super.initState();
    // Запускаем сессию при входе на экран
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(breathViewModelProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.read(breathViewModelProvider.notifier);
    final state = ref.watch(breathViewModelProvider);
    final currentExercise = viewModel.session.exercises[viewModel.exerciseIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: SafeArea(
        child: Column(
          children: [
            // Шапка с кнопкой назад
            _buildHeader(context),

            // Основная область с дыхательной фигурой
            Expanded(
              flex: 3,
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.maxWidth * 0.7;
                    return SizedBox(
                      width: size,
                      height: size,
                      child: BreathShapeWidget(
                        shape: currentExercise.shape,
                        triangleOrientation: currentExercise.triangleOrientation,
                        controller: viewModel.shapeController,
                        shapeColor: const Color(0xFF00D9FF),
                        pointColor: Colors.white,
                        strokeWidth: 3.0,
                        pointRadius: 6.0,
                      ),
                    );
                  },
                ),
              ),
            ),

            // Информационная панель
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(255, 255, 255, 0.05),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    // Текущая фаза и оставшееся время
                    _buildPhaseInfo(state),

                    const SizedBox(height: 30),

                    // Кнопка управления паузой/продолжением
                    _buildControlButton(state, viewModel),

                    const Spacer(),

                    // Кнопка пропуска упражнения (опционально)
                    if (state.status != BreathSessionStatus.complete)
                      _buildSkipButton(viewModel),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 10),
          const Text(
            'Breath Session',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseInfo(BreathSessionState state) {
    String phaseText;
    switch (state.phase) {
      case BreathPhase.inhale:
        phaseText = 'Breathe In';
        break;
      case BreathPhase.holdIn:
        phaseText = 'Hold';
        break;
      case BreathPhase.exhale:
        phaseText = 'Breathe Out';
        break;
      case BreathPhase.holdOut:
        phaseText = 'Hold';
        break;
      case BreathPhase.rest:
        phaseText = 'Rest';
        break;
    }

    String statusText;
    switch (state.status) {
      case BreathSessionStatus.pause:
        statusText = 'Paused';
        break;
      case BreathSessionStatus.complete:
        statusText = 'Complete';
        phaseText = 'Session Finished';
        break;
      default:
        statusText = '';
    }

    return Column(
      children: [
        if (statusText.isNotEmpty)
          Text(
            statusText,
            style: const TextStyle(
              color: Color.fromRGBO(255, 255, 255, 0.6),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          phaseText,
          style: const TextStyle(
            color: Color(0xFF00D9FF),
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (state.status != BreathSessionStatus.complete)
          Text(
            '${state.remainingTicks}s',
            style: const TextStyle(
              color: Color.fromRGBO(255, 255, 255, 0.8),
              fontSize: 24,
              fontWeight: FontWeight.w300,
            ),
          ),
      ],
    );
  }

  Widget _buildControlButton(BreathSessionState state, BreathViewModel viewModel) {
    if (state.status == BreathSessionStatus.complete) {
      return _ControlButton(
        icon: Icons.check_circle_outline,
        label: 'Finish',
        onPressed: () => Navigator.pop(context),
      );
    }

    final isPaused = state.status == BreathSessionStatus.pause;

    return _ControlButton(
      icon: isPaused ? Icons.play_arrow : Icons.pause,
      label: isPaused ? 'Resume' : 'Pause',
      onPressed: () {
        if (isPaused) {
          viewModel.resume();
        } else {
          viewModel.pause();
        }
      },
    );
  }

  Widget _buildSkipButton(BreathViewModel viewModel) {
    return TextButton.icon(
      onPressed: () => viewModel.skipToNextExercise(),
      icon: const Icon(
        Icons.skip_next,
        color: Colors.white60,
        size: 20,
      ),
      label: const Text(
        'Skip Exercise',
        style: TextStyle(
          color: Colors.white60,
          fontSize: 14,
        ),
      ),
    );
  }
}

/// Кнопка управления
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: const Color.fromRGBO(0, 217, 255, 0.2),
          borderRadius: BorderRadius.circular(50),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Icon(
                icon,
                color: const Color(0xFF00D9FF),
                size: 40,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
