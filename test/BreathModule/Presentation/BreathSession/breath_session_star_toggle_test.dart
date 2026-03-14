import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind/BreathModule/ITickService.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionViewModel.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/IBreathSessionCoordinator.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/IBreathSessionService.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/ILiveSessionService.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/ITelemetryService.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathExerciseDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionState.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathStepDTO.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeTickService implements ITickService {
  final _controller = StreamController<TickData>.broadcast();

  @override
  Stream<TickData> get tickStream => _controller.stream;

  void tick([int intervalMs = 1000]) => _controller.add(TickData(intervalMs));
  void dispose() => _controller.close();
}

class _FakeLiveSessionService implements ILiveSessionService {
  @override
  void startSession(String sessionId) {}
  @override
  void endSession() {}
  @override
  void pauseSession() {}
  @override
  void resumeSession() {}
  @override
  Stream<LiveSessionDto> get sessionStateStream => const Stream.empty();
}

class _FakeTelemetryService implements ITelemetryService {
  @override
  void sendSample(String sessionId, String phase, int durationMs) {}
}

class _FakeCoordinator implements IBreathSessionCoordinator {
  @override
  void openConstructor(String sessionId) {}
  @override
  void shareSession(String sessionId) {}
}

class _FakeSessionService implements IBreathSessionService {
  BreathSessionDTO dto;
  bool shouldFail = false;

  _FakeSessionService(this.dto);

  @override
  Future<BreathSessionDTO> getSession(String id) async => dto;

  @override
  Future<BreathSessionDTO> starSession(String id, {required bool starred}) async {
    if (shouldFail) throw Exception('Network error');
    dto = BreathSessionDTO(
      id: dto.id,
      description: dto.description,
      isStarred: starred,
      canStar: dto.canStar,
      exercises: dto.exercises,
    );
    return dto;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

BreathSessionDTO _makeDTO({bool isStarred = false, bool canStar = true}) {
  return BreathSessionDTO(
    id: 'test-session',
    description: 'Test',
    isStarred: isStarred,
    canStar: canStar,
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
  late _FakeTickService tickService;
  late _FakeSessionService service;
  late BreathViewModel vm;

  setUp(() {
    tickService = _FakeTickService();
  });

  tearDown(() {
    vm.dispose();
    tickService.dispose();
  });

  group('star toggle', () {
    test('initState sets isStarred and canStar from DTO', () async {
      service = _FakeSessionService(_makeDTO(isStarred: true, canStar: true));
      vm = BreathViewModel(
        tickService: tickService,
        service: service,
        coordinator: _FakeCoordinator(),
        liveSessionService: _FakeLiveSessionService(),
        telemetryService: _FakeTelemetryService(),
        sessionId: 'test-session',
      );

      expect(vm.state.isStarred, false);
      expect(vm.state.canStar, false);

      await vm.initState();

      expect(vm.state.isStarred, true);
      expect(vm.state.canStar, true);
    });

    test('initState sets canStar=false for own sessions', () async {
      service = _FakeSessionService(_makeDTO(isStarred: false, canStar: false));
      vm = BreathViewModel(
        tickService: tickService,
        service: service,
        coordinator: _FakeCoordinator(),
        liveSessionService: _FakeLiveSessionService(),
        telemetryService: _FakeTelemetryService(),
        sessionId: 'test-session',
      );

      await vm.initState();

      expect(vm.state.canStar, false);
    });

    test('toggleStar success: flips isStarred', () async {
      service = _FakeSessionService(_makeDTO(isStarred: false, canStar: true));
      vm = BreathViewModel(
        tickService: tickService,
        service: service,
        coordinator: _FakeCoordinator(),
        liveSessionService: _FakeLiveSessionService(),
        telemetryService: _FakeTelemetryService(),
        sessionId: 'test-session',
      );
      await vm.initState();
      expect(vm.state.isStarred, false);

      await vm.toggleStar();

      expect(vm.state.isStarred, true);
    });

    test('toggleStar success: unstar a starred session', () async {
      service = _FakeSessionService(_makeDTO(isStarred: true, canStar: true));
      vm = BreathViewModel(
        tickService: tickService,
        service: service,
        coordinator: _FakeCoordinator(),
        liveSessionService: _FakeLiveSessionService(),
        telemetryService: _FakeTelemetryService(),
        sessionId: 'test-session',
      );
      await vm.initState();
      expect(vm.state.isStarred, true);

      await vm.toggleStar();

      expect(vm.state.isStarred, false);
    });

    test('toggleStar failure: reverts isStarred', () async {
      service = _FakeSessionService(_makeDTO(isStarred: false, canStar: true));
      vm = BreathViewModel(
        tickService: tickService,
        service: service,
        coordinator: _FakeCoordinator(),
        liveSessionService: _FakeLiveSessionService(),
        telemetryService: _FakeTelemetryService(),
        sessionId: 'test-session',
      );
      await vm.initState();
      expect(vm.state.isStarred, false);

      service.shouldFail = true;
      await vm.toggleStar();

      expect(vm.state.isStarred, false);
    });
  });
}
