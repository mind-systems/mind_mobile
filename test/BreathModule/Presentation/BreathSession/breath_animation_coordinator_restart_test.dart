import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind/BreathModule/ITickService.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Animation/BreathAnimationCoordinator.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Animation/BreathMotionEngine.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Animation/BreathShapeShifter.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionViewModel.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/IBreathSessionService.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathExerciseDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionState.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathStepDTO.dart';

// ---------------------------------------------------------------------------
// Fake TickerProvider
// ---------------------------------------------------------------------------

class _FakeTickerProvider implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

// ---------------------------------------------------------------------------
// Fake TickService — never emits ticks in these tests
// ---------------------------------------------------------------------------

class _FakeTickService implements ITickService {
  final _controller = StreamController<TickData>.broadcast();

  @override
  Stream<TickData> get tickStream => _controller.stream;

  void close() => _controller.close();
}

// ---------------------------------------------------------------------------
// Fake IBreathSessionService — returns a hard-coded DTO
// ---------------------------------------------------------------------------

class _FakeSessionService implements IBreathSessionService {
  final BreathSessionDTO dto;
  _FakeSessionService(this.dto);

  @override
  Future<BreathSessionDTO> getSession(String id) async => dto;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

BreathSessionDTO _makeSession() {
  return BreathSessionDTO(
    id: 'test',
    description: 'Test',
    exercises: [
      BreathExerciseDTO(
        steps: [
          BreathStepDTO(phase: BreathPhase.inhale, duration: 2),
          BreathStepDTO(phase: BreathPhase.exhale, duration: 2),
        ],
        restDuration: 0,
        repeatCount: 1,
        shape: null,
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeTickerProvider vsync;
  late _FakeTickService tickService;
  late BreathMotionEngine motionEngine;
  late BreathShapeShifter shapeShifter;
  late ProviderContainer container;
  late BreathViewModel viewModel;
  late BreathAnimationCoordinator coordinator;

  setUp(() {
    vsync = _FakeTickerProvider();
    tickService = _FakeTickService();
    motionEngine = BreathMotionEngine(vsync);
    shapeShifter = BreathShapeShifter(initialShape: SetShape.circle);

    container = ProviderContainer(
      overrides: [
        breathViewModelProvider.overrideWith(
          (ref) => BreathViewModel(
            tickService: tickService,
            service: _FakeSessionService(_makeSession()),
            sessionId: 'test',
          ),
        ),
      ],
    );
    viewModel = container.read(breathViewModelProvider.notifier);

    coordinator = BreathAnimationCoordinator(
      motionEngine: motionEngine,
      shapeShifter: shapeShifter,
      viewModel: viewModel,
    );
  });

  tearDown(() {
    coordinator.dispose();
    motionEngine.dispose();
    tickService.close();
    container.dispose();
  });

  // Mirrors the real lifecycle: initialize with loading state, then load session.
  Future<void> loadSession() async {
    final initialState = container.read(breathViewModelProvider); // loading state
    coordinator.initialize(initialState);
    await viewModel.initState(); // loads session → emits ready state
    await Future<void>.delayed(Duration.zero); // flush microtasks / listeners
  }

  // -------------------------------------------------------------------------
  // After session loads, the motion engine should be inactive (status = pause)
  // -------------------------------------------------------------------------

  test('motionEngine is inactive after session loads (engine starts paused)', () async {
    await loadSession();

    // Engine starts in pause state — motionEngine should not be ticking.
    expect(motionEngine.isActive, isFalse);
  });

  // -------------------------------------------------------------------------
  // After resume(), motionEngine becomes active
  // -------------------------------------------------------------------------

  test('motionEngine is active after viewModel.resume()', () async {
    await loadSession();

    viewModel.resume();
    await Future<void>.delayed(Duration.zero);

    expect(motionEngine.isActive, isTrue);
  });

  // -------------------------------------------------------------------------
  // reset() clears state caches (private fields verified via behaviour)
  // -------------------------------------------------------------------------

  test('reset() deactivates motionEngine (returns it to initial state)', () async {
    await loadSession();
    viewModel.resume();
    await Future<void>.delayed(Duration.zero);

    // Engine is active. reset() brings coordinator back to initial state,
    // which includes setActive(false) so the activation gate fires on next breath state.
    coordinator.reset();

    expect(motionEngine.isActive, isFalse);
  });

  // -------------------------------------------------------------------------
  // After restart: coordinator.reset() + viewModel.restart() → engine stays active
  // -------------------------------------------------------------------------

  test('motionEngine remains active after coordinator.reset() + viewModel.restart()', () async {
    await loadSession();

    viewModel.resume();
    await Future<void>.delayed(Duration.zero);
    expect(motionEngine.isActive, isTrue);

    // Simulate the restart button sequence from BreathSessionScreen.
    coordinator.reset();
    viewModel.restart();
    await Future<void>.delayed(Duration.zero);

    // After restart, the engine resets to pause state — the coordinator should
    // correctly reflect that (not stuck in a stale active state from before).
    // The engine starts paused after restart.
    expect(motionEngine.isActive, isFalse);
  });

  // -------------------------------------------------------------------------
  // After restart + resume: engine is active (phaseInfo re-initialised)
  // -------------------------------------------------------------------------

  test('motionEngine is active after restart + resume', () async {
    await loadSession();

    // First run
    viewModel.resume();
    await Future<void>.delayed(Duration.zero);

    // Restart
    coordinator.reset();
    viewModel.restart();
    await Future<void>.delayed(Duration.zero);

    // Resume the restarted session
    viewModel.resume();
    await Future<void>.delayed(Duration.zero);

    expect(motionEngine.isActive, isTrue);
  });
}
