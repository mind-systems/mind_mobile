import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mind/Views/ControlButton.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionState.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionViewModel.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Animation/BreathMotionEngine.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Animation/BreathShapeShifter.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Animation/BreathAnimationCoordinator.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Views/BreathShapeWidget.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Views/BreathTimelineWidget.dart';

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

  // GlobalKey для доступа к методам BreathTimelineWidget
  final GlobalKey<BreathTimelineWidgetState> _timelineKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    // Создаём motionEngine
    _motionEngine = BreathMotionEngine(this);

    // Дефолтная форма — круг. При загрузке данных shapeShifter обновится через координатор.
    _shapeShifter = BreathShapeShifter(initialShape: SetShape.circle);
    _shapeShifter.initialize(const Offset(100, 100), 200, this);

    final viewModel = ref.read(breathViewModelProvider.notifier);

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

      // Запускаем загрузку сессии
      viewModel.initState();
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
    if (activeStepId == null || !_scrollController.hasClients) return;

    // Даём время на layout, потом получаем реальную координату
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final timelineState = _timelineKey.currentState;
      if (timelineState == null) return;

      final itemOffset = timelineState.getItemOffsetById(activeStepId);
      if (itemOffset == null) return;

      final viewportHeight = _scrollController.position.viewportDimension;

      final targetScroll = _scrollController.offset + itemOffset - (viewportHeight / 3);

      _scrollController.animateTo(
        targetScroll.clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    });
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
                      key: _timelineKey,
                      steps: state.timelineSteps,
                      activeStepId: state.activeStepId,
                      scrollController: _scrollController,
                      status: state.status,
                      itemHeight: itemHeight,
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
      return SizedBox(
        width: 80,
        height: 80,
        child: ControlButton(
          icon: Icons.check_circle_outline,
          onPressed: () => Navigator.pop(context),
          iconSize: 40,
        ),
      );
    }

    final isPaused = state.status == BreathSessionStatus.pause;
    final isLoading = state.loadState != SessionLoadState.ready;

    return SizedBox(
      width: 80,
      height: 80,
      child: ControlButton(
        icon: isPaused ? Icons.play_arrow : Icons.pause,
        onPressed: isLoading ? null : () {
          if (isPaused) {
            viewModel.resume();
          } else {
            viewModel.pause();
          }
        },
        iconSize: 40,
      ),
    );
  }
}
