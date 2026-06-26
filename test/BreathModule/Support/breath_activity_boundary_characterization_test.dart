import 'package:flutter_test/flutter_test.dart';
import 'package:breath_module/breath_module.dart'
    show BreathSessionState, BreathLifecycle, BreathPhase, ResetReason;
import 'BreathActivityHarness.dart';
import '../Fakes/BreathActivityFakes.dart';

// ─────────────────────────────────────────────────────────────────────────────
// expectState
//
// Asserts only the fields the caller provides, so each call reads as an
// input→output tuple:
//
//   expectState(s, lifecycle: BreathLifecycle.running, resetReason: ResetReason.start)
//
// resetReason uses a sentinel (_unset) so that:
//   - expectState(s, resetReason: null)  → asserts s.resetReason == null
//   - expectState(s)                     → resetReason is not checked at all
// ─────────────────────────────────────────────────────────────────────────────

const _unset = Object();

void expectState(
  BreathSessionState s, {
  BreathLifecycle? lifecycle,
  BreathPhase? phase,
  int? exerciseIndex,
  Object? resetReason = _unset,
  int? remainingTicks,
}) {
  if (lifecycle != null) {
    expect(s.lifecycle, lifecycle, reason: 'lifecycle mismatch');
  }
  if (phase != null) {
    expect(s.phase, phase, reason: 'phase mismatch');
  }
  if (exerciseIndex != null) {
    expect(s.exerciseIndex, exerciseIndex, reason: 'exerciseIndex mismatch');
  }
  if (remainingTicks != null) {
    expect(s.remainingTicks, remainingTicks, reason: 'remainingTicks mismatch');
  }
  if (!identical(resetReason, _unset)) {
    expect(s.resetReason, resetReason, reason: 'resetReason mismatch');
  }
}

void main() {
  late BreathActivityHarness harness;

  setUp(() async {
    harness = BreathActivityHarness();
    await harness.init();
    // _stateController is an async broadcast stream — flush its initial
    // _setupEngine emission so harness.states.first is available to all tests.
    await pumpEventQueue();
  });

  tearDown(() => harness.dispose());

  // ── Task 1: smoke — initial state anchor ──────────────────────────────────
  //
  // Anchors the starting point so every group below can rely on this state
  // being the first recorded emission.

  test('initial _setupEngine emission is the first recorded state', () {
    expect(
      harness.states,
      isNotEmpty,
      reason: 'states must contain at least the initial _setupEngine emission',
    );
    expectState(
      harness.states.first,
      lifecycle: BreathLifecycle.notStarted,
      phase: BreathPhase.inhale,
      exerciseIndex: 0,
      remainingTicks: 2,
      resetReason: null,
    );
  });

  // ── Task 2: _hasStarted resume discriminator ──────────────────────────────
  //
  // First resume() emits ResetReason.start (cold start).
  // pause() clears resetReason to null.
  // Second resume() emits null (warm resume — distinct observable output).

  group('resume discriminator (`_hasStarted`)', () {
    test(
      'first resume emits ResetReason.start; pause clears it; second resume emits null',
      () async {
        // First activation — _hasStarted transitions false → true
        harness.resume();
        await pumpEventQueue();
        expectState(
          harness.states.last,
          lifecycle: BreathLifecycle.running,
          phase: BreathPhase.inhale,
          resetReason: ResetReason.start,
        );

        // Pause — engine emits status=pause and clears resetReason to null
        harness.pause();
        await pumpEventQueue();
        expectState(
          harness.states.last,
          lifecycle: BreathLifecycle.paused,
          resetReason: null,
        );

        // Second activation — _hasStarted already true, no start reason
        harness.resume();
        await pumpEventQueue();
        expectState(
          harness.states.last,
          lifecycle: BreathLifecycle.running,
          resetReason: null,
        );
      },
    );
  });

  // ── Task 3: restart after complete → fresh initial pause ──────────────────
  //
  // Uses a two-exercise session so that exerciseIndex=0 reset is observable.
  // Inner setUp disposes the default single-exercise harness from the outer
  // setUp and replaces it with a two-exercise one; outer tearDown disposes
  // whichever harness `harness` points to at that point.

  group('restart after complete → fresh initial pause', () {
    setUp(() async {
      harness.dispose();
      harness = BreathActivityHarness(
        session: makeSession([makeExercise(), makeExercise()]),
      );
      await harness.init();
      await pumpEventQueue();
    });

    test(
      'restartEngine resets exerciseIndex and re-arms _hasStarted',
      () async {
        harness.resume();
        await pumpEventQueue();

        // Exhaust exercise 0: 4 ticks → state machine advances to exercise 1
        for (var i = 0; i < 4; i++) {
          harness.tick();
          await pumpEventQueue();
        }

        // Exhaust exercise 1: 4 ticks → state machine calls complete()
        for (var i = 0; i < 4; i++) {
          harness.tick();
          await pumpEventQueue();
        }

        // Last emission must be complete at exerciseIndex=1 with remainingTicks=0
        expectState(
          harness.states.last,
          lifecycle: BreathLifecycle.completed,
          exerciseIndex: 1,
          remainingTicks: 0,
        );

        // restartEngine → _onModuleReset + _setupEngine builds a fresh machine:
        //   exerciseIndex=0, _hasStarted=false, initial pause, resetReason=null
        harness.restartEngine();
        await pumpEventQueue();

        expectState(
          harness.states.last,
          lifecycle: BreathLifecycle.notStarted,
          phase: BreathPhase.inhale,
          exerciseIndex: 0,
          remainingTicks: 2,
          resetReason: null,
        );

        // _hasStarted re-armed: resume after restart emits ResetReason.start again
        harness.resume();
        await pumpEventQueue();
        expectState(
          harness.states.last,
          resetReason: ResetReason.start,
        );
      },
    );
  });

  // ── Task 4: ticks ignored outside running ─────────────────────────────────
  //
  // _onTick returns early when status == pause || status == complete,
  // so no emission is produced and states.length is unchanged.

  group('ticks ignored outside running', () {
    test(
      'case A: ticks in initial pause (not started) do not advance state',
      () async {
        // Baseline: one emission already recorded (initial _setupEngine)
        final initialLength = harness.states.length;

        for (var i = 0; i < 3; i++) {
          harness.tick();
          await pumpEventQueue();
        }

        expect(
          harness.states.length,
          initialLength,
          reason: 'no emission expected: _onTick returns early in pause status',
        );
        expectState(
          harness.states.last,
          lifecycle: BreathLifecycle.notStarted,
          phase: BreathPhase.inhale,
          exerciseIndex: 0,
          remainingTicks: 2,
        );
      },
    );

    test(
      'case B: ticks after complete do not advance state',
      () async {
        harness.resume();
        await pumpEventQueue();

        harness.complete();
        await pumpEventQueue();

        // Snapshot length after reaching complete status
        final lengthAtComplete = harness.states.length;

        for (var i = 0; i < 3; i++) {
          harness.tick();
          await pumpEventQueue();
        }

        expect(
          harness.states.length,
          lengthAtComplete,
          reason: 'no emission expected: _onTick returns early in complete status',
        );
        expectState(
          harness.states.last,
          lifecycle: BreathLifecycle.completed,
        );
      },
    );
  });
}
