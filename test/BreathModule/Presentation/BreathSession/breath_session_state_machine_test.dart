import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind/BreathModule/ITickService.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionStateMachine.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathExerciseDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionState.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathStepDTO.dart';

// ---------------------------------------------------------------------------
// Fake tick service — emits ticks on demand
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
    exercises: exercises,
  );
}

// Drives the engine through all ticks needed to exhaust one exercise cycle:
// (inhale + exhale) * repeatCount + restDuration * (repeatCount - 1) ticks
void driveExercise(
  FakeTickService ticks,
  BreathSessionStateMachine engine,
  BreathExerciseDTO exercise,
) {
  final cycleDuration = exercise.cycleDuration;
  final repeats = exercise.repeatCount;
  final rest = exercise.restDuration;

  for (var r = 0; r < repeats; r++) {
    // Drive breath cycle
    for (var t = 0; t < cycleDuration; t++) {
      ticks.tick();
    }
    // Drive rest between repeats (not after last repeat)
    if (r < repeats - 1 && rest > 0) {
      for (var t = 0; t < rest; t++) {
        ticks.tick();
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('BreathSessionStateMachine', () {
    late FakeTickService ticks;
    late BreathSessionStateMachine stateMachine;

    tearDown(() {
      stateMachine.dispose();
      ticks.dispose();
    });

    // -----------------------------------------------------------------------
    // Regression: RangeError when single-exercise session completes
    // -----------------------------------------------------------------------

    test(
      'currentExercise does not throw after single-exercise session completes',
      () async {
        final exercise = makeExercise(inhale: 2, exhale: 2, repeatCount: 1);
        final session = makeSession([exercise]);

        ticks = FakeTickService();
        stateMachine = BreathSessionStateMachine(
          session: session,
          tickService: ticks,
        );

        // Collect all emitted states
        final states = <BreathSessionStateMachineState>[];
        final sub = stateMachine.stateStream.listen(states.add);

        stateMachine.resume();

        // Drive all ticks (inhale=2, exhale=2 → 4 ticks advance the cycle)
        // After cycleDuration ticks the stateMachine calls _advanceExercise which
        // triggers complete() because there is only one exercise.
        driveExercise(ticks, stateMachine, exercise);

        // Allow microtasks / async delivery to flush
        await Future<void>.delayed(Duration.zero);

        sub.cancel();

        // Engine must be in complete state
        expect(
          stateMachine.currentState.status,
          BreathSessionStatus.complete,
          reason: 'Engine should reach complete status',
        );

        // currentExercise must not throw — this is the regression guard
        expect(
          () => stateMachine.currentExercise,
          returnsNormally,
          reason: 'currentExercise must not throw after completion',
        );

        // The last valid exercise must be returned (index 0, only exercise)
        expect(stateMachine.currentExercise, same(exercise));
      },
    );

    // -----------------------------------------------------------------------
    // Regression: RangeError when multi-exercise session completes
    // -----------------------------------------------------------------------

    test(
      'currentExercise does not throw after multi-exercise session completes',
      () async {
        final ex1 = makeExercise(inhale: 1, exhale: 1);
        final ex2 = makeExercise(inhale: 1, exhale: 1);
        final session = makeSession([ex1, ex2]);

        ticks = FakeTickService();
        stateMachine = BreathSessionStateMachine(
          session: session,
          tickService: ticks,
        );

        stateMachine.resume();

        driveExercise(ticks, stateMachine, ex1); // completes ex1, stateMachine moves to ex2
        driveExercise(
          ticks,
          stateMachine,
          ex2,
        ); // completes ex2, stateMachine calls complete()

        await Future<void>.delayed(Duration.zero);

        expect(stateMachine.currentState.status, BreathSessionStatus.complete);
        expect(() => stateMachine.currentExercise, returnsNormally);
        // Last valid exercise is ex2 (index 1)
        expect(stateMachine.currentExercise, same(ex2));
      },
    );

    // -----------------------------------------------------------------------
    // State machine: pause / resume / complete
    // -----------------------------------------------------------------------

    test('starts in pause state', () {
      final session = makeSession([makeExercise()]);
      ticks = FakeTickService();
      stateMachine = BreathSessionStateMachine(session: session, tickService: ticks);

      expect(stateMachine.currentState.status, BreathSessionStatus.pause);
    });

    test('resume transitions to breath status', () async {
      final session = makeSession([makeExercise()]);
      ticks = FakeTickService();
      stateMachine = BreathSessionStateMachine(session: session, tickService: ticks);

      stateMachine.resume();
      ticks.tick();
      await Future<void>.delayed(Duration.zero);

      expect(stateMachine.currentState.status, BreathSessionStatus.breath);
    });

    test('pause stops tick processing', () async {
      final session = makeSession([makeExercise(inhale: 5, exhale: 5)]);
      ticks = FakeTickService();
      stateMachine = BreathSessionStateMachine(session: session, tickService: ticks);

      stateMachine.resume();
      ticks.tick();
      await Future<void>.delayed(Duration.zero);

      stateMachine.pause();
      final stateAfterPause = stateMachine.currentState;

      ticks.tick();
      ticks.tick();
      await Future<void>.delayed(Duration.zero);

      // Phase progress should not change while paused
      expect(stateMachine.currentState.phase, stateAfterPause.phase);
      expect(stateMachine.currentState.status, BreathSessionStatus.pause);
    });

    test('complete() immediately sets status to complete', () {
      final session = makeSession([makeExercise()]);
      ticks = FakeTickService();
      stateMachine = BreathSessionStateMachine(session: session, tickService: ticks);

      stateMachine.complete();

      expect(stateMachine.currentState.status, BreathSessionStatus.complete);
    });

    // -----------------------------------------------------------------------
    // Phase progression
    // -----------------------------------------------------------------------

    test('inhale phase is active at start of cycle', () async {
      final session = makeSession([makeExercise(inhale: 3, exhale: 3)]);
      ticks = FakeTickService();
      stateMachine = BreathSessionStateMachine(session: session, tickService: ticks);

      stateMachine.resume();
      ticks.tick();
      await Future<void>.delayed(Duration.zero);

      expect(stateMachine.currentState.phase, BreathPhase.inhale);
    });

    test('exhale phase follows inhale', () async {
      final session = makeSession([makeExercise(inhale: 2, exhale: 2)]);
      ticks = FakeTickService();
      stateMachine = BreathSessionStateMachine(session: session, tickService: ticks);

      stateMachine.resume();

      // Drive through inhale phase (2 ticks)
      for (var i = 0; i < 2; i++) {
        ticks.tick();
      }
      await Future<void>.delayed(Duration.zero);

      expect(stateMachine.currentState.phase, BreathPhase.exhale);
    });

    test('remainingTicks decrements each tick', () async {
      final session = makeSession([makeExercise(inhale: 4, exhale: 4)]);
      ticks = FakeTickService();
      stateMachine = BreathSessionStateMachine(session: session, tickService: ticks);

      stateMachine.resume();
      ticks.tick();
      await Future<void>.delayed(Duration.zero);
      final r1 = stateMachine.currentState.remainingTicks;

      ticks.tick();
      await Future<void>.delayed(Duration.zero);
      final r2 = stateMachine.currentState.remainingTicks;

      expect(r2, lessThan(r1));
    });
  });
}
