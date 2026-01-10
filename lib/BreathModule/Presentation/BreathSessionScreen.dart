import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionState.dart';
import 'package:mind/BreathModule/Presentation/BreathViewModel.dart';
import 'package:mind/BreathModule/Presentation/Animation/BreathMotionEngine.dart';
import 'package:mind/BreathModule/Presentation/Animation/BreathShapeShifter.dart';
import 'package:mind/BreathModule/Presentation/Animation/BreathAnimationCoordinator.dart';
import 'package:mind/BreathModule/Presentation/Views/BreathShapeWidget.dart';

/// Экран дыхательной сессии
class BreathSessionScreen extends ConsumerStatefulWidget {
  const BreathSessionScreen({super.key});

  static String name = 'breath_session';
  static String path = '/$name';

  @override
  ConsumerState<BreathSessionScreen> createState() => _BreathSessionScreenState();
}

class _BreathSessionScreenState extends ConsumerState<BreathSessionScreen> with TickerProviderStateMixin {
  late final BreathMotionEngine _motionEngine;
  late final BreathShapeShifter _shapeShifter;
  late final BreathAnimationCoordinator _coordinator;

  @override
  void initState() {
    super.initState();

    // Создаём motionEngine
    _motionEngine = BreathMotionEngine(this);

    // Создаём shapeShifter с начальной формой
    final viewModel = ref.read(breathViewModelProvider.notifier);
    final firstExercise = viewModel.getNextExerciseWithShape();
    _shapeShifter = BreathShapeShifter(
      initialShape: firstExercise?.shape ?? SetShape.circle,
    );

    // Инициализируем с примерными размерами СРАЗУ
    // Это предотвратит краш при первой отрисовке
    _shapeShifter.initialize(const Offset(100, 100), 200, this);

    // Создаём и инициализируем координатор после инициализации shapeShifter
    _coordinator = BreathAnimationCoordinator(
      motionEngine: _motionEngine,
      shapeShifter: _shapeShifter,
      viewModel: viewModel,
    );

    // Инициализация coordinator после первого рендера
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialState = ref.read(breathViewModelProvider);
      _coordinator.initialize(initialState);

      // Запускаем сессию
      viewModel.initState();
    });
  }

  @override
  void dispose() {
    _coordinator.dispose();
    _motionEngine.dispose();
    _shapeShifter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.read(breathViewModelProvider.notifier);
    final state = ref.watch(breathViewModelProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final shapeDimension = screenWidth * 0.7;

        return Scaffold(
          backgroundColor: const Color(0xFF0A0E27),
          body: SafeArea(
            child: Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Основная область с дыхательной фигурой
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: SizedBox(
                      width: shapeDimension,
                      height: shapeDimension,
                      child: BreathShapeWidget(
                        motionController: _motionEngine,
                        shapeController: _shapeShifter,
                        shapeColor: const Color(0xFF00D9FF),
                        pointColor: Colors.white,
                        strokeWidth: 3.0,
                        pointRadius: 6.0,
                      ),
                    ),
                  ),

                  // Информационная панель
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Текущая и следующая фаза
                        _buildPhaseInfo(state, viewModel),

                        const SizedBox(height: 40),

                        // Кнопка управления паузой/продолжением
                        _buildControlButton(state, viewModel),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhaseInfo(BreathSessionState state, BreathViewModel viewModel) {
    // Текущая фаза
    String currentPhaseText;
    switch (state.phase) {
      case BreathPhase.inhale:
        currentPhaseText = 'Inhale';
        break;
      case BreathPhase.hold:
        currentPhaseText = 'Hold';
        break;
      case BreathPhase.exhale:
        currentPhaseText = 'Exhale';
        break;
      case BreathPhase.rest:
        currentPhaseText = 'Rest';
        break;
    }

    if (state.status == BreathSessionStatus.complete) {
      currentPhaseText = 'Session Complete';
    }

    // Следующая фаза
    String? nextPhaseText;
    if (state.status != BreathSessionStatus.complete) {
      final nextPhaseInfo = viewModel.getNextPhaseInfo();
      if (nextPhaseInfo != null) {
        switch (nextPhaseInfo.phase) {
          case BreathPhase.inhale:
            nextPhaseText = 'Next: Inhale ${nextPhaseInfo.duration}';
            break;
          case BreathPhase.hold:
            nextPhaseText = 'Next: Hold ${nextPhaseInfo.duration}';
            break;
          case BreathPhase.exhale:
            nextPhaseText = 'Next: Exhale ${nextPhaseInfo.duration}';
            break;
          case BreathPhase.rest:
            nextPhaseText = 'Next: Rest ${nextPhaseInfo.duration}';
            break;
        }
      }
    }

    return Column(
      children: [
        // Текущая фаза
        Text(
          currentPhaseText,
          style: const TextStyle(
            color: Color(0xFF00D9FF),
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Оставшееся время
        if (state.status != BreathSessionStatus.complete)
          Text(
            '${viewModel.getCurrentPhaseInfo().remainingInPhase}',
            style: const TextStyle(
              color: Color.fromRGBO(255, 255, 255, 0.8),
              fontSize: 24,
              fontWeight: FontWeight.w300,
            ),
          ),

        // Следующая фаза
        if (nextPhaseText != null) ...[
          const SizedBox(height: 20),
          Text(
            nextPhaseText,
            style: const TextStyle(
              color: Color.fromRGBO(255, 255, 255, 0.5),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildControlButton(BreathSessionState state, BreathViewModel viewModel) {
    if (state.status == BreathSessionStatus.complete) {
      return _ControlButton(
        icon: Icons.check_circle_outline,
        onPressed: () => Navigator.pop(context),
      );
    }

    final isPaused = state.status == BreathSessionStatus.pause;

    return _ControlButton(
      icon: isPaused ? Icons.play_arrow : Icons.pause,
      onPressed: () {
        if (isPaused) {
          viewModel.resume();
        } else {
          viewModel.pause();
        }
      },
    );
  }
}

/// Кнопка управления
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
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
      ],
    );
  }
}
