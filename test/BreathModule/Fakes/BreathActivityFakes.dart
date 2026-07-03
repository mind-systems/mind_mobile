import 'dart:async';

import 'package:breath_module/breath_module.dart'
    show
        BreathExerciseDTO,
        BreathPhase,
        BreathSessionDTO,
        IBreathSessionCoordinator,
        IBreathSessionService,
        ITickService,
        BreathStepDTO,
        TickData,
        TickSource;
import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Core/Grpc/ModuleSession.dart';
import 'package:mind/Core/Grpc/ModuleState.dart';
import 'package:mind/Core/Grpc/ModuleStateChannel.dart';
import 'package:mind/Core/Grpc/ModuleStateEvent.dart';
import 'package:mind/BreathModule/Core/BreathModuleInstructionStream.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FakeTickService
//
// Declared abstract interface (ITickService). All five interface members are
// implemented explicitly — no noSuchMethod escape needed.
// Port of FakeTickService from
// test/BreathModule/Presentation/BreathSession/breath_session_state_machine_test.dart
// ─────────────────────────────────────────────────────────────────────────────

class FakeTickService implements ITickService {
  final _controller = StreamController<TickData>.broadcast();

  @override
  Stream<TickData> get tickStream => _controller.stream;

  @override
  TickSource get source => TickSource.timer;

  @override
  int get nominalIntervalMs => 1000;

  @override
  Stream<TickSource> get sourceChanges => const Stream.empty();

  @override
  bool trySwitchTo(TickSource target) => false;

  /// Emit a single tick with [intervalMs] as the measured delta.
  void tick([int intervalMs = 1000]) => _controller.add(TickData(intervalMs));

  @override
  void dispose() => _controller.close();
}

// ─────────────────────────────────────────────────────────────────────────────
// FakeModuleStateChannel
//
// ModuleStateChannel is a concrete class, not a declared abstract interface.
// Fakeable via Dart's implicit per-class interface mechanism.
// The noSuchMethod override covers members not explicitly implemented.
// Port of _FakeChannel from
// test/BreathModule/breath_module_state_channel_test.dart
// ─────────────────────────────────────────────────────────────────────────────

class FakeModuleStateChannel implements ModuleStateChannel {
  final List<(ActivityType, String?)> startCalls = [];
  int unpauseCount = 0;
  int pauseCount = 0;
  int endCount = 0;
  int stopCount = 0;

  // No seeded events — SUT does not assume an initial moduleSessionId.
  final stateController = StreamController<ModuleState>.broadcast();
  final eventsController = StreamController<ModuleStateEvent>.broadcast();

  @override
  Stream<ModuleState> get state => stateController.stream;

  @override
  Stream<ModuleStateEvent> get events => eventsController.stream;

  @override
  ModuleSession? childOfType(ActivityType type) => null;

  @override
  void start({required ActivityType type, String? refId, int? clientTimestampMs, String? clientActivityId}) =>
      startCalls.add((type, refId));

  @override
  void unpause({String? sessionId}) => unpauseCount++;

  @override
  void pause({String? sessionId}) => pauseCount++;

  @override
  void end({int? clientTimestampMs, String? sessionId}) => endCount++;

  @override
  void stop({String? sessionId}) => stopCount++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ─────────────────────────────────────────────────────────────────────────────
// FakeInstructionStream
//
// BreathModuleInstructionStream is a concrete class, not a declared abstract
// interface. Fakeable via Dart's implicit per-class interface mechanism.
// The noSuchMethod override covers members not explicitly implemented.
// Port of _FakeInstructionStream from
// test/BreathModule/breath_module_state_channel_test.dart
// ─────────────────────────────────────────────────────────────────────────────

class FakeInstructionStream implements BreathModuleInstructionStream {
  final List<(String, String, int, int, int)> sendSampleCalls = [];

  /// Convenience view: (sessionId, phase, tickCount) tuples only.
  List<(String, String, int)> get phaseTickCalls =>
      sendSampleCalls.map((c) => (c.$1, c.$2, c.$3)).toList();

  @override
  void sendSample(
    String sessionId,
    String phase,
    int tickCount,
    int offsetMs,
    int timestampMs,
  ) =>
      sendSampleCalls.add((sessionId, phase, tickCount, offsetMs, timestampMs));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ─────────────────────────────────────────────────────────────────────────────
// FakeBreathSessionService
//
// Declared abstract interface (IBreathSessionService). Returns the supplied
// BreathSessionDTO; observeSession / observeSessionDeletion return empty streams
// so they do not trigger a second _setupEngine call during tests.
// Port of _FakeSessionService from
// test/BreathModule/Presentation/BreathSession/breath_view_model_publication_test.dart
// ─────────────────────────────────────────────────────────────────────────────

class FakeBreathSessionService implements IBreathSessionService {
  final BreathSessionDTO dto;

  FakeBreathSessionService(this.dto);

  @override
  Future<BreathSessionDTO> getSession(String id) async => dto;

  @override
  Future<BreathSessionDTO> starSession(String id, {required bool starred}) async => dto;

  @override
  Stream<BreathSessionDTO> observeSession(String id) => const Stream.empty();

  @override
  Stream<void> observeSessionDeletion(String id) => const Stream.empty();
}

// ─────────────────────────────────────────────────────────────────────────────
// FakeBreathSessionCoordinator
//
// Declared abstract interface (IBreathSessionCoordinator). Records call counts
// for each method; extends the no-op pattern of _FakeCoordinator from
// test/BreathModule/Presentation/BreathSession/breath_view_model_publication_test.dart
// with call recording.
// ─────────────────────────────────────────────────────────────────────────────

class FakeBreathSessionCoordinator implements IBreathSessionCoordinator {
  int openConstructorCount = 0;
  int shareSessionCount = 0;
  int dismissCount = 0;

  @override
  void openConstructor(String sessionId) => openConstructorCount++;

  @override
  void shareSession(String sessionId) => shareSessionCount++;

  @override
  void dismiss() => dismissCount++;
}

// ─────────────────────────────────────────────────────────────────────────────
// DTO builders
//
// Port of makeExercise / makeSession from
// test/BreathModule/Presentation/BreathSession/breath_session_state_machine_test.dart
// ─────────────────────────────────────────────────────────────────────────────

BreathExerciseDTO makeExercise({
  int inhale = 2,
  int exhale = 2,
  int restDuration = 0,
  int repeatCount = 1,
}) {
  return BreathExerciseDTO(
    steps: [
      BreathStepDTO(phase: BreathPhase.inhale, duration: inhale),
      BreathStepDTO(phase: BreathPhase.exhale, duration: exhale),
    ],
    restDuration: restDuration,
    repeatCount: repeatCount,
    shape: null,
  );
}

BreathSessionDTO makeSession(List<BreathExerciseDTO> exercises) {
  return BreathSessionDTO(
    id: 'test-session',
    description: 'Test',
    isStarred: false,
    canStar: false,
    exercises: exercises,
  );
}
