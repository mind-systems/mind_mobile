import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_audio/mind_audio.dart';
import 'package:mind_l10n/mind_l10n.dart';
import 'package:mind_ui/mind_ui.dart';
import '../CommonModels/SetShape.dart';
import 'Models/BreathSessionState.dart';
import 'BreathSessionLayout.dart';
import 'BreathSessionViewModel.dart';
import 'Animation/BreathMotionEngine.dart';
import 'Animation/BreathShapeShifter.dart';
import 'Animation/BreathAnimationCoordinator.dart';
import 'Animation/OrbAnimationCoordinator.dart';
import 'Audio/BreathSoundCoordinator.dart';
import 'Views/BreathShapeWidget.dart';
import 'Views/BreathTimelineWidget.dart';
import 'Views/EclipseOrb.dart';
import 'Views/SessionBottomBar.dart';

/// Экран дыхательной сессии
class BreathSessionScreen extends ConsumerStatefulWidget {
  final VoidCallback? onRestart;
  final VoidCallback? onDispose;

  const BreathSessionScreen({this.onRestart, this.onDispose, super.key});

  static String name = 'breath_session';
  static String path = '/$name';

  @override
  ConsumerState<BreathSessionScreen> createState() =>
      _BreathSessionScreenState();
}

class _BreathSessionScreenState extends ConsumerState<BreathSessionScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final BreathMotionEngine _motionEngine;
  late final BreathShapeShifter _shapeShifter;
  late final BreathAnimationCoordinator _coordinator;
  late final OrbAnimationCoordinator _orbCoordinator;
  late final BreathSoundCoordinator _soundCoordinator;
  late final ScrollController _scrollController;

  bool _isBlackedOut = false;

  // GlobalKey для доступа к методам BreathTimelineWidget
  final GlobalKey<BreathTimelineWidgetState> _timelineKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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

    _orbCoordinator = OrbAnimationCoordinator(
      viewModel: viewModel,
      vsync: this,
    );
    _soundCoordinator = BreathSoundCoordinator(
      viewModel: viewModel,
      looper: AudioLooper(),
      oneShot: AudioOneShot(),
    );

    _scrollController = ScrollController();

    // Инициализация coordinator после первого рендера
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialState = ref.read(breathViewModelProvider);
      _coordinator.initialize(initialState);
      _orbCoordinator.initialize(initialState);
      _soundCoordinator.initialize(initialState);

      // Запускаем загрузку сессии
      viewModel.initState();
    });

    ref.listenManual<BreathSessionState>(breathViewModelProvider, (prev, next) {
      if (prev?.activeStepId != next.activeStepId) {
        _scrollToActive(next.activeStepId);
      }
    });

    viewModel.onErrorEvent = (_) {
      ref
          .read(globalSnackBarNotifierProvider.notifier)
          .show(SnackBarEvent.error(AppLocalizations.of(context)!.error));
    };
  }

  @override
  void dispose() {
    widget.onDispose?.call();
    _coordinator.dispose();
    _orbCoordinator.dispose();
    _soundCoordinator.dispose();
    _motionEngine.dispose();
    _shapeShifter.dispose();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _soundCoordinator.suspend();
      final status = ref.read(breathViewModelProvider).status;
      if (status == BreathSessionStatus.breath ||
          status == BreathSessionStatus.rest) {
        ref.read(breathViewModelProvider.notifier).pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      _soundCoordinator.resume();
    }
  }

  void _scrollToActive(String? activeStepId) {
    if (activeStepId == null || !_scrollController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final timelineState = _timelineKey.currentState;
      if (timelineState == null) return;

      final itemContentOffset = timelineState.getItemScrollOffsetById(
        activeStepId,
      );
      if (itemContentOffset == null) return;

      final viewportHeight = _scrollController.position.viewportDimension;
      final targetScroll = itemContentOffset - (viewportHeight / 3);

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
    final mq = MediaQuery.of(context);
    final screenWidth = mq.size.width;
    final bottomBarHeight =
        BreathSessionLayout.kBottomBarBaseHeight + mq.padding.bottom;
    final availableHeight = mq.size.height - mq.padding.top - bottomBarHeight;
    final layout = BreathSessionLayout.compute(screenWidth, availableHeight);
    final cs = Theme.of(context).colorScheme;

    final viewModel = ref.read(breathViewModelProvider.notifier);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Основной контент по центру
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Основная область с дыхательной фигурой
                      Consumer(
                        builder: (context, ref, _) {
                          final loadState = ref.watch(
                            breathViewModelProvider.select((s) => s.loadState),
                          );
                          return Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: layout.shapePadding,
                            ),
                            child: SizedBox(
                              width: layout.shapeDimension,
                              height: layout.shapeDimension,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  ValueListenableBuilder<double>(
                                    valueListenable:
                                        _orbCoordinator.orbProgress,
                                    builder:
                                        (context, progress, _) => EclipseOrb(
                                          size:
                                              layout.shapeDimension * progress,
                                          glowColor: cs.tertiary,
                                          maskColor:
                                              Theme.of(
                                                context,
                                              ).scaffoldBackgroundColor,
                                          pulseStream: viewModel.tickStream,
                                          onTap:
                                              () => setState(
                                                () => _isBlackedOut = true,
                                              ),
                                        ),
                                  ),
                                  AnimatedOpacity(
                                    opacity:
                                        loadState == SessionLoadState.ready
                                            ? 1.0
                                            : 0.0,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeIn,
                                    child: BreathShapeWidget(
                                      motionController: _motionEngine,
                                      shapeController: _shapeShifter,
                                      shapeColor: cs.tertiary,
                                      pointColor: Colors.white,
                                      strokeWidth: 3.0,
                                      pointRadius: 6.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      Consumer(
                        builder: (context, ref, _) {
                          final (steps, activeStepId, status) = ref.watch(
                            breathViewModelProvider.select(
                              (s) => (
                                s.timelineSteps,
                                s.activeStepId,
                                s.status,
                              ),
                            ),
                          );
                          return SizedBox(
                            height: layout.timelineHeight,
                            child: BreathTimelineWidget(
                              key: _timelineKey,
                              steps: steps,
                              activeStepId: activeStepId,
                              scrollController: _scrollController,
                              status: status,
                              itemHeight: layout.itemHeight,
                              remainingTicksListenable:
                                  ref
                                      .read(breathViewModelProvider.notifier)
                                      .remainingTicksNotifier,
                            ),
                          );
                        },
                      ),

                      Consumer(
                        builder: (context, ref, _) {
                          final (status, loadState) = ref.watch(
                            breathViewModelProvider.select(
                              (s) => (s.status, s.loadState),
                            ),
                          );
                          return Padding(
                            padding: EdgeInsets.all(layout.buttonPadding),
                            child: _buildControlButton(
                              status: status,
                              loadState: loadState,
                              viewModel: viewModel,
                              buttonSize: layout.buttonSize,
                              iconSize: layout.iconSize,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Bottom bar прибит к низу
                Consumer(
                  builder: (context, ref, _) {
                    final (canStar, isStarred) = ref.watch(
                      breathViewModelProvider.select(
                        (s) => (s.canStar, s.isStarred),
                      ),
                    );
                    return SessionBottomBar(
                      iconSize: layout.iconSize,
                      leadingActions: [
                        ValueListenableBuilder<bool>(
                          valueListenable: _soundCoordinator.isMuted,
                          builder:
                              (context, isMuted, _) => IconButton(
                                icon: Icon(
                                  isMuted
                                      ? Icons.volume_off_outlined
                                      : Icons.volume_up,
                                ),
                                color:
                                    isMuted
                                        ? Colors.white.withValues(alpha: 0.3)
                                        : cs.tertiary,
                                onPressed: _soundCoordinator.toggleMute,
                              ),
                        ),
                      ],
                      trailingActions: [
                        IconButton(
                          icon: const Icon(Icons.share_outlined),
                          color: cs.tertiary,
                          onPressed: () => viewModel.shareSession(),
                        ),
                        if (canStar)
                          IconButton(
                            icon: Icon(
                              isStarred ? Icons.star : Icons.star_border,
                            ),
                            color: cs.tertiary,
                            onPressed: () => viewModel.toggleStar(),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          color: cs.tertiary,
                          onPressed: () => viewModel.openEditor(),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          AnimatedOpacity(
            opacity: _isBlackedOut ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: !_isBlackedOut,
              child: GestureDetector(
                onTap: () => setState(() => _isBlackedOut = false),
                child: const ColoredBox(
                  color: Colors.black,
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required BreathSessionStatus status,
    required SessionLoadState loadState,
    required BreathViewModel viewModel,
    required double buttonSize,
    required double iconSize,
  }) {
    if (status == BreathSessionStatus.complete) {
      return SizedBox(
        width: buttonSize,
        height: buttonSize,
        child: ControlButton(
          icon: Icons.replay,
          onPressed: () {
            widget.onRestart?.call();
            _coordinator.reset();
            _orbCoordinator.reset();
            _soundCoordinator.reset();
            viewModel.restartEngine();
          },
          // 0.5 mirrors the original 40/80 icon-to-button ratio.
          iconSize: buttonSize * 0.5,
        ),
      );
    }

    final isPaused = status == BreathSessionStatus.pause;
    final isLoading = loadState != SessionLoadState.ready;

    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: ControlButton(
        icon: isPaused ? Icons.play_arrow : Icons.pause,
        onPressed:
            isLoading
                ? null
                : () {
                  if (isPaused) {
                    viewModel.resume();
                  } else {
                    viewModel.pause();
                  }
                },
        iconSize: buttonSize * 0.5,
      ),
    );
  }
}
