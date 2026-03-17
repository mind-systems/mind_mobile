import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breath_module/breath_module.dart' show ITickService, TickData, SetShape, OrbAnimationCoordinator, BreathViewModel, breathViewModelProvider, IBreathSessionCoordinator, IBreathSessionService, BreathExerciseDTO, BreathSessionDTO, BreathStepDTO, BreathPhase;

// ---------------------------------------------------------------------------
// Manual TickService — emits ticks on demand
// ---------------------------------------------------------------------------

class _ManualTickService implements ITickService {
  final _controller = StreamController<TickData>.broadcast();

  @override
  Stream<TickData> get tickStream => _controller.stream;

  void tick([int intervalMs = 1000]) => _controller.add(TickData(intervalMs));

  void close() => _controller.close();
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeBreathSessionCoordinator implements IBreathSessionCoordinator {
  @override
  void openConstructor(String sessionId) {}
  @override
  void shareSession(String sessionId) {}
}

class _FakeSessionService implements IBreathSessionService {
  final BreathSessionDTO dto;
  _FakeSessionService(this.dto);

  @override
  Future<BreathSessionDTO> getSession(String id) async => dto;

  @override
  Future<BreathSessionDTO> starSession(String id, {required bool starred}) async => dto;

  @override
  Stream<BreathSessionDTO> observeSession(String id) => Stream.value(dto);
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

BreathSessionDTO _makeSession() {
  return BreathSessionDTO(
    id: 'test',
    description: 'Test',
    isStarred: false,
    canStar: false,
    exercises: [
      BreathExerciseDTO(
        steps: [
          BreathStepDTO(phase: BreathPhase.inhale, duration: 4),
          BreathStepDTO(phase: BreathPhase.exhale, duration: 4),
        ],
        restDuration: 0,
        repeatCount: 2,
        shape: SetShape.circle,
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // After pause + resume, orbProgress changes on next tick (animation restarts)
  // -------------------------------------------------------------------------

  testWidgets('orbProgress changes after pause + resume on next tick', (tester) async {
    final tickService = _ManualTickService();
    late BreathViewModel viewModel;
    late OrbAnimationCoordinator coordinator;

    final container = ProviderContainer(
      overrides: [
        breathViewModelProvider.overrideWith(
          () => BreathViewModel(
            tickService: tickService,
            service: _FakeSessionService(_makeSession()),
            coordinator: _FakeBreathSessionCoordinator(),
            sessionId: 'test',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(tickService.close);

    viewModel = container.read(breathViewModelProvider.notifier);
    coordinator = OrbAnimationCoordinator(viewModel: viewModel, vsync: tester);

    // Load session
    final initialState = container.read(breathViewModelProvider);
    coordinator.initialize(initialState);
    await viewModel.initState();
    await tester.pump();

    // Start breathing
    viewModel.resume();
    await tester.pump();

    // First tick — starts inhale animation
    tickService.tick();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Record progress after animation has run
    final progressAfterFirstTick = coordinator.orbProgress.value;

    // Pause
    viewModel.pause();
    await tester.pump();

    // Resume — dedup guard (if present) would block animation on next tick
    viewModel.resume();
    await tester.pump();

    // Tick — coordinator must restart animation regardless of same remaining/phase
    tickService.tick();
    await tester.pump();

    // Pump animation forward so orbProgress actually updates
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      coordinator.orbProgress.value,
      isNot(equals(progressAfterFirstTick)),
      reason:
          'orbProgress must change after pause+resume on next tick — '
          'the dedup guard (_lastAnimatedRemaining) blocks animation restart',
    );

    // Dispose before end-of-test ticker check runs.
    coordinator.dispose();
  });
}
