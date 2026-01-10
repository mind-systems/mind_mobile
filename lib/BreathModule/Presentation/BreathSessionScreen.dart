import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Presentation/Models/TimelineStep.dart';
import 'package:mind/BreathModule/Presentation/Models/BreathSessionState.dart';
import 'package:mind/BreathModule/Presentation/BreathViewModel.dart';
import 'package:mind/BreathModule/Presentation/Animation/BreathMotionEngine.dart';
import 'package:mind/BreathModule/Presentation/Animation/BreathShapeShifter.dart';
import 'package:mind/BreathModule/Presentation/Animation/BreathAnimationCoordinator.dart';
import 'package:mind/BreathModule/Presentation/Views/BreathShapeWidget.dart';
import 'package:mind/BreathModule/Presentation/Views/BreathTimelineWidget.dart';

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
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();

    // Создаём motionEngine
    _motionEngine = BreathMotionEngine(this);

    final viewModel = ref.read(breathViewModelProvider.notifier);
    final firstExercise = viewModel.getNextExerciseWithShape();

    // Создаём shapeShifter с начальной формой
    _shapeShifter = BreathShapeShifter(initialShape: firstExercise?.shape ?? SetShape.circle);
    _shapeShifter.initialize(const Offset(100, 100), 200, this);

    // Создаём и инициализируем координатор после инициализации shapeShifter
    _coordinator = BreathAnimationCoordinator(
      motionEngine: _motionEngine,
      shapeShifter: _shapeShifter,
      viewModel: viewModel,
    );

    _scrollController = ScrollController();

    // Инициализация coordinator после первого рендера
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialState = ref.read(breathViewModelProvider);
      _coordinator.initialize(initialState);

      // Запускаем сессию
      viewModel.initState();
      _scrollToActive(initialState.activeStepId);
    });

    ref.listenManual<BreathSessionState>(
      breathViewModelProvider,
      (prev, next) {
        if (prev?.activeStepId != next.activeStepId) {
          _scrollToActive(next.activeStepId);
        }
      },
    );
  }

  @override
  void dispose() {
    _coordinator.dispose();
    _motionEngine.dispose();
    _shapeShifter.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActive(String? activeStepId) {
    if (!_scrollController.hasClients) return;

    final viewportHeight = _scrollController.position.viewportDimension;
    if (viewportHeight == 0) return;

    const itemHeight = 48.0;
    const separatorHeight = 0.5;

    final steps = ref.read(breathViewModelProvider).timelineSteps;
    final activeIndex = steps.indexWhere((s) => s.id == activeStepId);

    double offset = 0.0;
    for (int i = 0; i < activeIndex; i++) {
      offset += steps[i].type == TimelineStepType.separator ? separatorHeight : itemHeight;
    }

    _scrollController.animateTo(
      offset.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.read(breathViewModelProvider.notifier);
    final state = ref.watch(breathViewModelProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final shapeDimension = screenWidth * 0.7;
        const itemHeight = 48.0; // todo copypaste from BreathTimelineWidget!
        final timelineHeight = itemHeight * 4.5;

        final phaseInfo = viewModel.getCurrentPhaseInfo();

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
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          BreathShapeWidget(
                            motionController: _motionEngine,
                            shapeController: _shapeShifter,
                            shapeColor: const Color(0xFF00D9FF),
                            pointColor: Colors.white,
                            strokeWidth: 3.0,
                            pointRadius: 6.0,
                          ),
                          if (state.status != BreathSessionStatus.complete)
                            Text(
                              '${phaseInfo.remainingInPhase}',
                              style: const TextStyle(
                                color: Color(0xFF00D9FF),
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(
                    height: timelineHeight,
                    child: BreathTimelineWidget(
                      steps: state.timelineSteps,
                      activeStepId: state.activeStepId,
                      scrollController: _scrollController,
                      status: state.status,
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: _buildControlButton(state, viewModel),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
