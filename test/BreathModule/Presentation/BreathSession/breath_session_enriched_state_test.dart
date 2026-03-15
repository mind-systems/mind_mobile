// Tests for Phase 1: Enriched State + Single Emit
//
// These tests verify:
// - Task 1: BreathSessionStateMachineState has new enriched fields
// - Task 2a: _advanceExercise no longer causes double-reset (exerciseChange wins)
// - Task 2b: Only one emit per tick (no double-emit of currentIntervalMs)
// - Task 2c: Enriched fields are computed at emit time
// - Task 3: BreathSessionState has enriched fields + ViewModel maps them correctly

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind/BreathModule/ITickService.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionStateMachine.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathExerciseDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionState.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathStepDTO.dart';

// ---------------------------------------------------------------------------
// Fake tick service
// ---------------------------------------------------------------------------

class FakeTickService implements ITickService {
  final _controller = StreamController<TickData>.broadcast();

  @override
  Stream<TickData> get tickStream => _controller.stream;

  void tick([int intervalMs = 1000]) => _controller.add(TickData(intervalMs));

  void dispose() => _controller.close();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

BreathExerciseDTO makeExercise({
  int inhale = 2,
  int exhale = 2,
  int restDuration = 0,
  int repeatCount = 1,
  SetShape? shape,
}) {
  return BreathExerciseDTO(
    steps: [
      BreathStepDTO(phase: BreathPhase.inhale, duration: inhale),
      BreathStepDTO(phase: BreathPhase.exhale, duration: exhale),
    ],
    restDuration: restDuration,
    repeatCount: repeatCount,
    shape: shape,
  );
}

BreathExerciseDTO makeRestOnlyExercise({int restDuration = 3}) {
  return BreathExerciseDTO(
    steps: const [],
    restDuration: restDuration,
    repeatCount: 1,
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

// ---------------------------------------------------------------------------
// Task 1: BreathSessionStateMachineState enriched fields
// ---------------------------------------------------------------------------

void main() {
  group('Task 1 — BreathSessionStateMachineState enriched fields', () {
    late FakeTickService ticks;
    late BreathSessionStateMachine sm;

    tearDown(() {
      sm.dispose();
      ticks.dispose();
    });

    test('initial state has resetReason = null', () {
      final session = makeSession([makeExercise(inhale: 2, exhale: 2)]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      expect(sm.currentState.resetReason, isNull);
    });

    test('initial state has totalPhases = number of steps in first exercise', () {
      final session = makeSession([makeExercise(inhale: 2, exhale: 2)]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      // inhale + exhale = 2 steps
      expect(sm.currentState.totalPhases, equals(2));
    });

    test('initial state has currentPhaseIndex = 0', () {
      final session = makeSession([makeExercise(inhale: 2, exhale: 2)]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      expect(sm.currentState.currentPhaseIndex, equals(0));
    });

    test('initial state has currentPhaseTotalDuration = duration of first step', () {
      // inhale=3, exhale=2 → first step is inhale with duration 3
      final session = makeSession([makeExercise(inhale: 3, exhale: 2)]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      expect(sm.currentState.currentPhaseTotalDuration, equals(3));
    });

    test('initial state has currentExerciseShape = shape of first exercise', () {
      final session = makeSession([makeExercise(shape: SetShape.square)]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      expect(sm.currentState.currentExerciseShape, equals(SetShape.square));
    });

    test('initial state has currentExerciseShape = null when exercise has no shape', () {
      final session = makeSession([makeExercise(shape: null)]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      expect(sm.currentState.currentExerciseShape, isNull);
    });

    test('initial state nextExerciseShape is shape of first exercise with steps', () {
      // Exercise 1 has steps with shape=circle, exercise 2 is rest-only (no shape)
      final ex1 = makeExercise(shape: SetShape.circle);
      final ex2 = makeRestOnlyExercise();
      final session = makeSession([ex1, ex2]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      // Currently on ex1 which has steps → nextExerciseShape = ex1.shape (current)
      expect(sm.currentState.nextExerciseShape, equals(SetShape.circle));
    });

    test('nextExerciseShape scans forward past rest-only exercises', () {
      final ex1 = makeRestOnlyExercise(restDuration: 3);
      final ex2 = makeExercise(shape: SetShape.triangleUp);
      final session = makeSession([ex1, ex2]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      expect(sm.currentState.nextExerciseShape, equals(SetShape.triangleUp));
    });

    test('state during breath tick has correct currentPhaseIndex', () async {
      // inhale=2, exhale=2 → after 2 ticks we move to exhale (index 1)
      final session = makeSession([makeExercise(inhale: 2, exhale: 2)]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      sm.resume();
      ticks.tick(); // tick 1 → still inhale (index 0)
      await Future<void>.delayed(Duration.zero);
      expect(sm.currentState.currentPhaseIndex, equals(0));

      ticks.tick(); // tick 2 → moves to exhale (index 1)
      await Future<void>.delayed(Duration.zero);
      expect(sm.currentState.currentPhaseIndex, equals(1));
    });

    test('state during breath tick has correct currentPhaseTotalDuration', () async {
      // inhale=3, exhale=2 → when we enter exhale, currentPhaseTotalDuration = 2
      final session = makeSession([makeExercise(inhale: 3, exhale: 2)]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      sm.resume();

      // Drive through inhale (3 ticks) to land in exhale
      for (var i = 0; i < 3; i++) {
        ticks.tick();
        await Future<void>.delayed(Duration.zero);
      }

      expect(sm.currentState.phase, equals(BreathPhase.exhale));
      expect(sm.currentState.currentPhaseTotalDuration, equals(2));
    });

    test('state during rest tick has currentPhaseTotalDuration = restDuration', () async {
      // exercise: inhale=1, exhale=1, repeatCount=2, restDuration=3
      // After first cycle (2 ticks), enters rest → currentPhaseTotalDuration = 3
      final session = makeSession([makeExercise(inhale: 1, exhale: 1, restDuration: 3, repeatCount: 2)]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      sm.resume();

      // Drive through first cycle (2 ticks)
      ticks.tick();
      await Future<void>.delayed(Duration.zero);
      ticks.tick();
      await Future<void>.delayed(Duration.zero);

      // Should now be in rest
      expect(sm.currentState.status, equals(BreathSessionStatus.rest));
      expect(sm.currentState.currentPhaseTotalDuration, equals(3));
    });
  });

  // ---------------------------------------------------------------------------
  // Task 2b: Single emit per tick (no double-emit)
  // ---------------------------------------------------------------------------

  group('Task 2b — Single emit per tick', () {
    late FakeTickService ticks;
    late BreathSessionStateMachine sm;

    tearDown(() {
      sm.dispose();
      ticks.dispose();
    });

    test('exactly one state is emitted per tick during breath', () async {
      final session = makeSession([makeExercise(inhale: 5, exhale: 5)]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      sm.resume();

      final emissions = <BreathSessionStateMachineState>[];
      final sub = sm.stateStream.listen(emissions.add);

      // Emit exactly one tick and count state emissions
      emissions.clear();
      ticks.tick();
      await Future<void>.delayed(Duration.zero);

      sub.cancel();

      expect(
        emissions.length,
        equals(1),
        reason: 'Exactly one state emission expected per tick, got ${emissions.length}',
      );
    });

    test('exactly one state is emitted per tick during transition to rest', () async {
      // inhale=1, exhale=1, repeatCount=2, restDuration=3
      // At tick 2, we transition from breath to rest → should still be 1 emission
      final session = makeSession([makeExercise(inhale: 1, exhale: 1, restDuration: 3, repeatCount: 2)]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      sm.resume();

      // Drive through first cycle without counting
      ticks.tick();
      await Future<void>.delayed(Duration.zero);

      // Now count emissions on the transition tick
      final emissions = <BreathSessionStateMachineState>[];
      final sub = sm.stateStream.listen(emissions.add);

      ticks.tick(); // This tick completes cycle → transitions to rest
      await Future<void>.delayed(Duration.zero);

      sub.cancel();

      expect(
        emissions.length,
        equals(1),
        reason: 'Transition tick must emit exactly one state, got ${emissions.length}',
      );
    });

    test('exactly one state is emitted per tick during exercise change', () async {
      // ex1: inhale=1, exhale=1, ex2: inhale=1, exhale=1
      // Tick that completes ex1 should emit exactly 1 state
      final ex1 = makeExercise(inhale: 1, exhale: 1);
      final ex2 = makeExercise(inhale: 1, exhale: 1);
      final session = makeSession([ex1, ex2]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      sm.resume();

      // Drive first tick (doesn't complete cycle)
      ticks.tick();
      await Future<void>.delayed(Duration.zero);

      // Count on the transition tick
      final emissions = <BreathSessionStateMachineState>[];
      final sub = sm.stateStream.listen(emissions.add);

      ticks.tick(); // completes ex1 cycle → exerciseChange
      await Future<void>.delayed(Duration.zero);

      sub.cancel();

      expect(
        emissions.length,
        equals(1),
        reason: 'Exercise change tick must emit exactly one state, got ${emissions.length}',
      );
    });

    test('emitted state on transition tick has correct currentIntervalMs', () async {
      final session = makeSession([makeExercise(inhale: 5, exhale: 5)]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      sm.resume();

      BreathSessionStateMachineState? lastState;
      final sub = sm.stateStream.listen((s) => lastState = s);

      const testIntervalMs = 750;
      ticks.tick(testIntervalMs);
      await Future<void>.delayed(Duration.zero);

      sub.cancel();

      expect(lastState?.currentIntervalMs, equals(testIntervalMs));
    });

    test('exactly one state is emitted per tick during rest', () async {
      final session = makeSession([makeExercise(inhale: 1, exhale: 1, restDuration: 5, repeatCount: 2)]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      sm.resume();

      // Drive into rest (2 ticks completes first cycle)
      ticks.tick();
      await Future<void>.delayed(Duration.zero);
      ticks.tick();
      await Future<void>.delayed(Duration.zero);

      expect(sm.currentState.status, equals(BreathSessionStatus.rest));

      // Count emissions on a regular rest tick
      final emissions = <BreathSessionStateMachineState>[];
      final sub = sm.stateStream.listen(emissions.add);

      ticks.tick(); // mid-rest tick
      await Future<void>.delayed(Duration.zero);

      sub.cancel();

      expect(
        emissions.length,
        equals(1),
        reason: 'Rest tick must emit exactly one state, got ${emissions.length}',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Task 2a: _advanceExercise double-reset fix (exerciseChange wins)
  // ---------------------------------------------------------------------------

  group('Task 2a — exerciseChange reset reason wins over rest/newCycle', () {
    late FakeTickService ticks;
    late BreathSessionStateMachine sm;

    tearDown(() {
      sm.dispose();
      ticks.dispose();
    });

    test('state on exercise change tick has resetReason = exerciseChange', () async {
      final ex1 = makeExercise(inhale: 1, exhale: 1);
      final ex2 = makeExercise(inhale: 1, exhale: 1);
      final session = makeSession([ex1, ex2]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      sm.resume();

      // First tick — just breathing
      ticks.tick();
      await Future<void>.delayed(Duration.zero);

      // Second tick — completes ex1, triggers exerciseChange
      ticks.tick();
      await Future<void>.delayed(Duration.zero);

      expect(
        sm.currentState.resetReason,
        equals(ResetReason.exerciseChange),
        reason: 'State on exercise-change tick must carry resetReason = exerciseChange',
      );
    });

    test('resetStream emits exactly one event on exercise change (not two)', () async {
      final ex1 = makeExercise(inhale: 1, exhale: 1);
      final ex2 = makeExercise(inhale: 1, exhale: 1);
      final session = makeSession([ex1, ex2]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      sm.resume();

      final resetReasons = <ResetReason>[];
      final sub = sm.resetStream.listen(resetReasons.add);

      // Drive ex1 to completion (2 ticks)
      ticks.tick();
      await Future<void>.delayed(Duration.zero);
      ticks.tick();
      await Future<void>.delayed(Duration.zero);

      sub.cancel();

      expect(
        resetReasons.length,
        equals(1),
        reason: 'resetStream must emit exactly once on exercise change, got $resetReasons',
      );
      expect(resetReasons.first, equals(ResetReason.exerciseChange));
    });

    test('state on rest reset has resetReason = rest', () async {
      // inhale=1, exhale=1, repeatCount=2, restDuration=3 → after first cycle: rest
      final session = makeSession([makeExercise(inhale: 1, exhale: 1, restDuration: 3, repeatCount: 2)]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      sm.resume();

      ticks.tick(); // tick 1
      await Future<void>.delayed(Duration.zero);
      ticks.tick(); // tick 2 → completes cycle → starts rest
      await Future<void>.delayed(Duration.zero);

      expect(sm.currentState.resetReason, equals(ResetReason.rest));
    });

    test('state on new cycle reset has resetReason = newCycle', () async {
      // inhale=1, exhale=1, repeatCount=2, restDuration=0 → after first cycle: newCycle
      final session = makeSession([makeExercise(inhale: 1, exhale: 1, restDuration: 0, repeatCount: 2)]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      sm.resume();

      ticks.tick(); // tick 1
      await Future<void>.delayed(Duration.zero);
      ticks.tick(); // tick 2 → completes cycle → newCycle
      await Future<void>.delayed(Duration.zero);

      expect(sm.currentState.resetReason, equals(ResetReason.newCycle));
    });

    test('resetReason is null on regular breath tick', () async {
      final session = makeSession([makeExercise(inhale: 5, exhale: 5)]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      sm.resume();

      ticks.tick(); // regular breath tick
      await Future<void>.delayed(Duration.zero);

      expect(sm.currentState.resetReason, isNull);
    });

    test('resetReason is null after pause() even if paused right after transition', () async {
      // inhale=1, exhale=1, repeatCount=2, restDuration=3
      // After 2 ticks: transition to rest, resetReason = rest (non-null)
      // Then pause() must clear it
      final session = makeSession([makeExercise(inhale: 1, exhale: 1, restDuration: 3, repeatCount: 2)]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      sm.resume();
      ticks.tick();
      await Future<void>.delayed(Duration.zero);
      ticks.tick(); // transition → rest, resetReason = rest
      await Future<void>.delayed(Duration.zero);

      expect(sm.currentState.resetReason, equals(ResetReason.rest)); // precondition

      sm.pause();
      await Future<void>.delayed(Duration.zero);

      expect(sm.currentState.resetReason, isNull);
    });

    test('state on exercise change to rest-only exercise has resetReason = exerciseChange', () async {
      final ex1 = makeExercise(inhale: 1, exhale: 1);
      final ex2 = makeRestOnlyExercise(restDuration: 3);
      final session = makeSession([ex1, ex2]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      sm.resume();
      ticks.tick();
      await Future<void>.delayed(Duration.zero);
      ticks.tick(); // completes ex1 → advances to rest-only ex2
      await Future<void>.delayed(Duration.zero);

      expect(sm.currentState.resetReason, equals(ResetReason.exerciseChange));
      expect(sm.currentState.status, equals(BreathSessionStatus.rest));
    });

    test('resetReason is null after resume() even if paused right after transition', () async {
      // inhale=1, exhale=1, repeatCount=2, restDuration=3
      // After 2 ticks: transition to rest, resetReason = rest (non-null)
      // Then pause() + resume() must clear it
      final session = makeSession([makeExercise(inhale: 1, exhale: 1, restDuration: 3, repeatCount: 2)]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      sm.resume();
      ticks.tick();
      await Future<void>.delayed(Duration.zero);
      ticks.tick(); // transition → rest, resetReason = rest
      await Future<void>.delayed(Duration.zero);

      expect(sm.currentState.resetReason, equals(ResetReason.rest)); // precondition

      sm.pause();
      sm.resume(); // must clear resetReason

      expect(sm.currentState.resetReason, isNull);
    });

    test('resetReason is null after complete()', () async {
      // inhale=1, exhale=1, single exercise → completes after 2 ticks
      final session = makeSession([makeExercise(inhale: 1, exhale: 1)]);
      ticks = FakeTickService();
      sm = BreathSessionStateMachine(session: session, tickService: ticks);

      sm.resume();
      ticks.tick();
      await Future<void>.delayed(Duration.zero);
      ticks.tick();
      await Future<void>.delayed(Duration.zero);

      expect(sm.currentState.status, equals(BreathSessionStatus.complete));
      expect(sm.currentState.resetReason, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Task 3: BreathSessionState enriched fields exist
  // ---------------------------------------------------------------------------

  group('Task 3a — BreathSessionState has enriched fields', () {
    test('BreathSessionState.initial() has resetReason = null', () {
      final state = BreathSessionState.initial();
      expect(state.resetReason, isNull);
    });

    test('BreathSessionState.initial() has totalPhases = 0', () {
      final state = BreathSessionState.initial();
      expect(state.totalPhases, equals(0));
    });

    test('BreathSessionState.initial() has currentPhaseIndex = 0', () {
      final state = BreathSessionState.initial();
      expect(state.currentPhaseIndex, equals(0));
    });

    test('BreathSessionState.initial() has currentPhaseTotalDuration = 0', () {
      final state = BreathSessionState.initial();
      expect(state.currentPhaseTotalDuration, equals(0));
    });

    test('BreathSessionState.initial() has currentExerciseShape = null', () {
      final state = BreathSessionState.initial();
      expect(state.currentExerciseShape, isNull);
    });

    test('BreathSessionState.initial() has nextExerciseShape = null', () {
      final state = BreathSessionState.initial();
      expect(state.nextExerciseShape, isNull);
    });

    test('BreathSessionState copyWith preserves enriched fields when not overridden', () {
      const original = BreathSessionState(
        loadState: SessionLoadState.ready,
        status: BreathSessionStatus.breath,
        phase: BreathPhase.inhale,
        exerciseIndex: 0,
        remainingTicks: 3,
        currentIntervalMs: 1000,
        totalPhases: 2,
        currentPhaseIndex: 1,
        currentPhaseTotalDuration: 4,
        currentExerciseShape: SetShape.circle,
        nextExerciseShape: SetShape.square,
      );

      final copy = original.copyWith(remainingTicks: 2);

      expect(copy.totalPhases, equals(2));
      expect(copy.currentPhaseIndex, equals(1));
      expect(copy.currentPhaseTotalDuration, equals(4));
      expect(copy.currentExerciseShape, equals(SetShape.circle));
      expect(copy.nextExerciseShape, equals(SetShape.square));
    });
  });
}
