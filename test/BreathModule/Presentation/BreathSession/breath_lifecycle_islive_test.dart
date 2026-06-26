import 'package:flutter_test/flutter_test.dart';
import 'package:breath_module/breath_module.dart'
    show BreathLifecycle, BreathExerciseDTO;
import '../../Support/BreathActivityHarness.dart';
import '../../Fakes/BreathActivityFakes.dart';

void main() {
  late BreathActivityHarness harness;

  tearDown(() => harness.dispose());

  // ── 1. Initial (pre-resume) state ─────────────────────────────────────────
  //
  // The first recorded emission from _setupEngine has status=pause and
  // _hasStarted=false → lifecycle must be notStarted, isLive must be false.

  test('initial state → lifecycle == notStarted, isLive == false', () async {
    harness = BreathActivityHarness();
    await harness.init();
    await pumpEventQueue();

    expect(
      harness.states.last.lifecycle,
      BreathLifecycle.notStarted,
      reason: 'pre-resume pause with _hasStarted=false → notStarted',
    );
    expect(
      harness.states.last.isLive,
      false,
      reason: 'notStarted is not a live lifecycle',
    );
  });

  // ── 2. After resume() → running ───────────────────────────────────────────

  test('after resume() → lifecycle == running, isLive == true', () async {
    harness = BreathActivityHarness();
    await harness.init();
    await pumpEventQueue();

    harness.resume();
    await pumpEventQueue();

    expect(
      harness.states.last.lifecycle,
      BreathLifecycle.running,
      reason: 'status=breath after first resume → running',
    );
    expect(
      harness.states.last.isLive,
      true,
      reason: 'running is a live lifecycle',
    );
  });

  // ── 3. After pause() that follows a resume() → paused (keep-alive) ────────

  test('after pause() following resume() → lifecycle == paused, isLive == true',
      () async {
    harness = BreathActivityHarness();
    await harness.init();
    await pumpEventQueue();

    harness.resume();
    await pumpEventQueue();

    harness.pause();
    await pumpEventQueue();

    expect(
      harness.states.last.lifecycle,
      BreathLifecycle.paused,
      reason: 'status=pause with _hasStarted=true → paused',
    );
    expect(
      harness.states.last.isLive,
      true,
      reason: 'paused keeps the live window open',
    );
  });

  // ── 4. After complete() → completed ──────────────────────────────────────

  test('after complete() → lifecycle == completed, isLive == false', () async {
    harness = BreathActivityHarness();
    await harness.init();
    await pumpEventQueue();

    harness.resume();
    await pumpEventQueue();

    harness.complete();
    await pumpEventQueue();

    expect(
      harness.states.last.lifecycle,
      BreathLifecycle.completed,
      reason: 'status=complete → completed',
    );
    expect(
      harness.states.last.isLive,
      false,
      reason: 'completed is not a live lifecycle',
    );
  });

  // ── 5. Rest-phase running emit → running ─────────────────────────────────
  //
  // The default harness session (inhale=2/exhale=2) never emits status=rest.
  // Build a rest-only exercise (steps: [], restDuration=3) so resume() puts
  // the machine directly into status=rest → lifecycle must still be running.

  test('rest-phase emit → lifecycle == running', () async {
    harness = BreathActivityHarness(
      session: makeSession([
        BreathExerciseDTO(
          steps: [],
          restDuration: 3,
          repeatCount: 1,
          shape: null,
        ),
      ]),
    );
    await harness.init();
    await pumpEventQueue();

    harness.resume();
    await pumpEventQueue();

    expect(
      harness.states.last.lifecycle,
      BreathLifecycle.running,
      reason: 'status=rest during active session → running',
    );
    expect(
      harness.states.last.isLive,
      true,
      reason: 'rest phase is still live',
    );
  });
}
