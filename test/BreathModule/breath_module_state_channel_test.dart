import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Core/Grpc/ModuleState.dart';
import 'package:mind/Core/Grpc/ModuleStateChannel.dart';
import 'package:mind/BreathModule/Core/BreathModuleInstructionStream.dart';
import 'package:mind/BreathModule/Core/BreathModuleStateChannel.dart';
import 'package:breath_module/breath_module.dart'
    show BreathSessionState, BreathSessionStatus, BreathPhase, SessionLoadState;

// ──────────────────────────────────────────────────────────────────────────────
// Fakes
// ──────────────────────────────────────────────────────────────────────────────

class _FakeChannel implements ModuleStateChannel {
  final List<(ActivityType, String?)> startCalls = [];
  int unpauseCount = 0;
  int pauseCount = 0;
  int endCount = 0;
  int stopCount = 0;

  // No seeded events — SUT does not assume an initial moduleSessionId.
  // Seeding one would silently change instruction-path tests in the follow-up plan.
  final stateController = StreamController<ModuleState>.broadcast();

  @override
  Stream<ModuleState> get state => stateController.stream;

  @override
  void start({required ActivityType type, String? refId}) =>
      startCalls.add((type, refId));

  @override
  void unpause() => unpauseCount++;

  @override
  void pause() => pauseCount++;

  @override
  void end() => endCount++;

  @override
  void stop() => stopCount++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeInstructionStream implements BreathModuleInstructionStream {
  final List<(String, String, int)> sendSampleCalls = [];

  @override
  void sendSample(String sessionId, String phase, int tickCount, int offsetMs, int timestampMs) =>
      sendSampleCalls.add((sessionId, phase, tickCount));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────────

/// Builds a [BreathSessionState] for lifecycle tests.
///
/// Note: [currentIntervalMs] default of 4000 and [remainingTicks] default of 0
/// are scoped to lifecycle tests; neither field is read by _handleLifecycle.
/// Revisit when instruction-stream tests are added — the real initial state
/// uses currentIntervalMs: -1, and positive defaults may mask off-by-one bugs.
BreathSessionState _state({
  required BreathSessionStatus status,
  BreathPhase phase = BreathPhase.inhale,
  int exerciseIndex = 0,
  SessionLoadState loadState = SessionLoadState.ready,
  int currentIntervalMs = 4000,
  int currentPhaseTotalDuration = 1,
}) {
  return BreathSessionState(
    loadState: loadState,
    status: status,
    phase: phase,
    exerciseIndex: exerciseIndex,
    remainingTicks: 0,
    currentIntervalMs: currentIntervalMs,
    currentPhaseTotalDuration: currentPhaseTotalDuration,
  );
}

typedef _Fixture = ({
  _FakeChannel channel,
  _FakeInstructionStream instructionStream,
  StreamController<BreathSessionState> stateCtrl,
  BreathModuleStateChannel target,
});

_Fixture _make({String sessionId = 'sess-1'}) {
  final channel = _FakeChannel();
  final instructionStream = _FakeInstructionStream();
  final stateCtrl = StreamController<BreathSessionState>.broadcast();
  final target = BreathModuleStateChannel(
    channel: channel,
    stateStream: stateCtrl.stream,
    instructionStream: instructionStream,
    sessionId: sessionId,
  );
  return (
    channel: channel,
    instructionStream: instructionStream,
    stateCtrl: stateCtrl,
    target: target,
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

void main() {
  // ── Phase 1: scaffolding ──────────────────────────────────────────────────

  group('BreathModuleStateChannel — scaffolding', () {
    test('should construct without throwing', () {
      final f = _make();
      expect(f.target, isNotNull);
      f.target.dispose();
    });
  });

  // ── Phase 2: start transitions ────────────────────────────────────────────

  group('BreathModuleStateChannel — start transitions', () {
    test(
      'should call channel.start with ActivityType.breath and the constructor sessionId when the first emitted state has status=breath',
      () async {
        final f = _make(sessionId: 'my-session');
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.startCalls, hasLength(1));
        expect(f.channel.startCalls.first.$1, ActivityType.breath);
        expect(f.channel.startCalls.first.$2, 'my-session');

        f.target.dispose();
      },
    );

    test(
      'should call channel.start with ActivityType.breath and the constructor sessionId when transitioning from pause to breath for the first time',
      () async {
        final f = _make(sessionId: 'my-session');
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.startCalls, hasLength(1));
        expect(f.channel.startCalls.first.$1, ActivityType.breath);
        expect(f.channel.startCalls.first.$2, 'my-session');

        f.target.dispose();
      },
    );

    test(
      'should not call unpause or pause when start is dispatched on the first active transition',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.unpauseCount, 0);
        expect(f.channel.pauseCount, 0);

        f.target.dispose();
      },
    );

    test(
      'should not re-invoke start when the same breath state is emitted twice in a row',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.startCalls, hasLength(1));

        f.target.dispose();
      },
    );
  });

  // ── Phase 3: subsequent active / unpause transitions ──────────────────────

  group('BreathModuleStateChannel — unpause transitions', () {
    test(
      'should call unpause exactly once when transitioning pause -> breath after start has already happened',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.unpauseCount, 1);

        f.target.dispose();
      },
    );

    test(
      'should call unpause exactly once when transitioning pause -> rest after start has already happened',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.rest));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.unpauseCount, 1);

        f.target.dispose();
      },
    );

    test(
      'should not call start again on a pause -> breath transition once a session has already been started',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);

        // start called once (initial), not again on resume
        expect(f.channel.startCalls, hasLength(1));

        f.target.dispose();
      },
    );

    test(
      'should call start (not unpause) when the very first emission is status=rest with no prior emission',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.rest));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.startCalls, hasLength(1));
        expect(f.channel.unpauseCount, 0);

        f.target.dispose();
      },
    );

    test(
      'should not call start, unpause, or pause when transitioning breath -> rest while active',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.rest));
        await Future<void>.delayed(Duration.zero);

        // Only one start call total (from the initial breath emission)
        expect(f.channel.startCalls, hasLength(1));
        expect(f.channel.unpauseCount, 0);
        expect(f.channel.pauseCount, 0);

        f.target.dispose();
      },
    );

    test(
      'should not call start, unpause, or pause when transitioning rest -> breath while active',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.rest));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);

        // Only one start call total; active↔active transitions are silent
        expect(f.channel.startCalls, hasLength(1));
        expect(f.channel.unpauseCount, 0);
        expect(f.channel.pauseCount, 0);

        f.target.dispose();
      },
    );
  });

  // ── Phase 4: pause transitions ────────────────────────────────────────────

  group('BreathModuleStateChannel — pause transitions', () {
    test(
      'should call channel.pause exactly once when transitioning breath -> pause',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.pauseCount, 1);

        f.target.dispose();
      },
    );

    test(
      'should call channel.pause exactly once when transitioning rest -> pause',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.rest));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.pauseCount, 1);

        f.target.dispose();
      },
    );

    test(
      'should not call pause when the very first emission is status=pause (wasActive=false short-circuits the pause branch)',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.pauseCount, 0);

        f.target.dispose();
      },
    );

    test(
      'should not call pause when transitioning pause -> pause (status-unchanged short-circuit at the top of _handleLifecycle)',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.pauseCount, 0);

        f.target.dispose();
      },
    );
  });

  // ── Phase 5: end transitions ──────────────────────────────────────────────

  group('BreathModuleStateChannel — end transitions', () {
    test(
      'should call channel.end exactly once when transitioning breath -> complete',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.complete));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.endCount, 1);

        f.target.dispose();
      },
    );

    test(
      'should call channel.end exactly once when transitioning rest -> complete',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.rest));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.complete));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.endCount, 1);

        f.target.dispose();
      },
    );

    test(
      'should call channel.end exactly once when transitioning pause -> complete after the session was started',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.complete));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.endCount, 1);

        f.target.dispose();
      },
    );

    test(
      'should not call channel.end on a second complete emission (status-unchanged short-circuit)',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.complete));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.complete));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.endCount, 1);

        f.target.dispose();
      },
    );

    test(
      'should not call channel.end when complete is emitted before any start (the _started guard in the complete branch suppresses end)',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.complete));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.endCount, 0);

        f.target.dispose();
      },
    );

    test(
      'should not call channel.end a second time when a complete -> pause -> complete sequence is emitted (the _ended guard prevents duplicate end)',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.complete));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.complete));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.endCount, 1);

        f.target.dispose();
      },
    );
  });

  // ── Phase 6: loadState filter ─────────────────────────────────────────────

  group('BreathModuleStateChannel — loadState filter', () {
    test(
      'should not call start when a state with status=breath and loadState=loading is emitted',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(
          status: BreathSessionStatus.breath,
          loadState: SessionLoadState.loading,
        ));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.startCalls, isEmpty);

        f.target.dispose();
      },
    );

    test(
      'should not call pause when a state with status=pause and loadState=loading is emitted between two ready breath states',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(
          status: BreathSessionStatus.pause,
          loadState: SessionLoadState.loading,
        ));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.pauseCount, 0);

        f.target.dispose();
      },
    );

    test(
      'should not call end when a state with status=complete and loadState=error is emitted',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(
          status: BreathSessionStatus.complete,
          loadState: SessionLoadState.error,
        ));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.endCount, 0);

        f.target.dispose();
      },
    );

    test(
      'should not update _previousStatus when a non-ready emission is filtered, verified by emitting ready breath -> non-ready pause -> ready breath and asserting no unpause call was dispatched between the two breath emissions',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        // Non-ready pause is filtered; _previousStatus must stay breath
        f.stateCtrl.add(_state(
          status: BreathSessionStatus.pause,
          loadState: SessionLoadState.loading,
        ));
        await Future<void>.delayed(Duration.zero);
        // If _previousStatus had been updated to pause, this breath would trigger unpause
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.unpauseCount, 0);

        f.target.dispose();
      },
    );

    test(
      'should resume dispatching lifecycle calls correctly once a ready emission follows a filtered one, verified by ready breath -> non-ready breath -> ready pause emitting exactly one pause',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        // Non-ready breath is filtered; _previousStatus stays breath
        f.stateCtrl.add(_state(
          status: BreathSessionStatus.breath,
          loadState: SessionLoadState.loading,
        ));
        await Future<void>.delayed(Duration.zero);
        // Ready pause — wasActive (previousStatus=breath) triggers pause
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.pauseCount, 1);

        f.target.dispose();
      },
    );
  });

  // ── Phase 7: dispose() / stop() ───────────────────────────────────────────

  group('BreathModuleStateChannel — dispose() / stop()', () {
    test(
      'should not call channel.stop when dispose is invoked before any state has been emitted',
      () {
        final f = _make();
        f.target.dispose();

        expect(f.channel.stopCount, 0);
      },
    );

    test(
      'should not call channel.stop when dispose is invoked after only non-ready emissions have arrived',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(
          status: BreathSessionStatus.breath,
          loadState: SessionLoadState.loading,
        ));
        await Future<void>.delayed(Duration.zero);
        f.target.dispose();

        expect(f.channel.stopCount, 0);
      },
    );

    test(
      'should call channel.stop exactly once when dispose is invoked while the session is started and not yet ended (breath -> dispose)',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        f.target.dispose();

        expect(f.channel.stopCount, 1);
      },
    );

    test(
      'should call channel.stop exactly once when dispose is invoked while the session is paused after being started (breath -> pause -> dispose)',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause));
        await Future<void>.delayed(Duration.zero);
        f.target.dispose();

        expect(f.channel.stopCount, 1);
      },
    );

    test(
      'should not call channel.stop when dispose is invoked after the session has already completed (breath -> complete -> dispose)',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.complete));
        await Future<void>.delayed(Duration.zero);
        f.target.dispose();

        expect(f.channel.stopCount, 0);
      },
    );

    test(
      'should not dispatch any further lifecycle calls when state emissions arrive after dispose has run',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        f.target.dispose();
        // _stateSub is cancelled; further emissions must not reach _onState
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.pauseCount, 0);
      },
    );
  });

  // ── Phase 8: reset() ──────────────────────────────────────────────────────

  group('BreathModuleStateChannel — reset()', () {
    test(
      'should call channel.start (not unpause) on the next breath emission after reset, even if the session had previously been started',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause));
        await Future<void>.delayed(Duration.zero);
        f.target.reset();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);

        // start called twice (initial + post-reset); unpause never called
        expect(f.channel.startCalls, hasLength(2));
        expect(f.channel.unpauseCount, 0);

        f.target.dispose();
      },
    );

    test(
      'should call channel.start (not unpause) on the next rest emission after reset, exercising the wasPaused=null branch',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        f.target.reset();
        f.stateCtrl.add(_state(status: BreathSessionStatus.rest));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.startCalls, hasLength(2));
        expect(f.channel.unpauseCount, 0);

        f.target.dispose();
      },
    );

    test(
      'should not call channel.end when complete is emitted after reset with no fresh start in between',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        f.target.reset();
        f.stateCtrl.add(_state(status: BreathSessionStatus.complete));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.endCount, 0);

        f.target.dispose();
      },
    );

    test(
      'should keep the stateStream subscription alive across reset, verified by driving a ready breath on the same stateCtrl after reset and observing a second start call',
      () async {
        final f = _make();
        // Pre-reset: start a session
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        expect(f.channel.startCalls, hasLength(1));
        // Reset — subscriptions stay alive
        f.target.reset();
        // Post-reset: drive another breath on the exact same stateCtrl
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath));
        await Future<void>.delayed(Duration.zero);
        // Second start call proves the subscription survived reset
        expect(f.channel.startCalls, hasLength(2));

        f.target.dispose();
      },
    );
  });

  // ── Phase 9: instruction dispatch ────────────────────────────────────────

  group('BreathModuleStateChannel — instruction dispatch', () {
    test(
      'should call instructionStream.sendSample with the moduleSessionId, phase name, and tickCount when phase changes while status=breath and a moduleSessionId is available',
      () async {
        final f = _make();
        // Seed moduleSessionId
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);
        // Prime _previousPhase and _previousExerciseIndex
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause, phase: BreathPhase.inhale, exerciseIndex: 0));
        await Future<void>.delayed(Duration.zero);
        // Phase change: inhale → exhale
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale, exerciseIndex: 0, currentIntervalMs: 5000, currentPhaseTotalDuration: 3));
        await Future<void>.delayed(Duration.zero);

        expect(f.instructionStream.sendSampleCalls, hasLength(1));
        expect(f.instructionStream.sendSampleCalls.first, ('sid', 'exhale', 3));

        f.target.dispose();
      },
    );

    test(
      'should call instructionStream.sendSample when exerciseIndex changes while phase stays the same, status=breath, and a moduleSessionId is available',
      () async {
        final f = _make();
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause, phase: BreathPhase.inhale, exerciseIndex: 0));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.inhale, exerciseIndex: 1, currentIntervalMs: 5000, currentPhaseTotalDuration: 4));
        await Future<void>.delayed(Duration.zero);

        expect(f.instructionStream.sendSampleCalls, hasLength(1));
        expect(f.instructionStream.sendSampleCalls.first, ('sid', 'inhale', 4));

        f.target.dispose();
      },
    );

    test(
      'should call instructionStream.sendSample exactly once when phase and exerciseIndex change simultaneously',
      () async {
        final f = _make();
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause, phase: BreathPhase.inhale, exerciseIndex: 0));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale, exerciseIndex: 1, currentIntervalMs: 5000));
        await Future<void>.delayed(Duration.zero);

        expect(f.instructionStream.sendSampleCalls, hasLength(1));

        f.target.dispose();
      },
    );

    test(
      'should not call instructionStream.sendSample when a state emission keeps phase and exerciseIndex unchanged',
      () async {
        final f = _make();
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);
        // First emission — dispatches (first-emission phase change is implicit: inhale != null)
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.inhale, exerciseIndex: 0));
        await Future<void>.delayed(Duration.zero);
        // Same phase and exerciseIndex, different currentIntervalMs — no second dispatch
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.inhale, exerciseIndex: 0, currentIntervalMs: 5000));
        await Future<void>.delayed(Duration.zero);

        expect(f.instructionStream.sendSampleCalls, hasLength(1));

        f.target.dispose();
      },
    );

    test(
      'should not call instructionStream.sendSample when a state emission has status=pause regardless of phase change',
      () async {
        final f = _make();
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);
        // First breath emission — dispatches
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.inhale, exerciseIndex: 0));
        await Future<void>.delayed(Duration.zero);
        // Pause with different phase — !isActive guard prevents dispatch
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause, phase: BreathPhase.exhale));
        await Future<void>.delayed(Duration.zero);

        expect(f.instructionStream.sendSampleCalls, hasLength(1));

        f.target.dispose();
      },
    );

    test(
      'should not call instructionStream.sendSample when a phase change occurs after the session has ended',
      () async {
        final f = _make();
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);
        // First breath emission — dispatches
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.inhale, exerciseIndex: 0));
        await Future<void>.delayed(Duration.zero);
        expect(f.instructionStream.sendSampleCalls, hasLength(1));
        // Complete — lifecycle calls end(), sets _ended=true
        f.stateCtrl.add(_state(status: BreathSessionStatus.complete));
        await Future<void>.delayed(Duration.zero);
        // Post-complete breath with phase change — _ended guard prevents dispatch
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale));
        await Future<void>.delayed(Duration.zero);

        expect(f.instructionStream.sendSampleCalls, hasLength(1));
        // No spurious second start call after complete (Note 8)
        expect(f.channel.startCalls, hasLength(1));

        f.target.dispose();
      },
    );

    test(
      'should call instructionStream.sendSample when status=rest and phase changes while a moduleSessionId is available',
      () async {
        final f = _make();
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);
        // Prime _previousPhase=inhale, _previousExerciseIndex=0
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause, phase: BreathPhase.inhale, exerciseIndex: 0));
        await Future<void>.delayed(Duration.zero);
        // Breath starts the session; _handleLifecycle resets _previousPhase=null so the
        // first active emission always dispatches (inhale != null → phaseChanged=true)
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.inhale, exerciseIndex: 0));
        await Future<void>.delayed(Duration.zero);
        // Rest with phase change — active check covers both breath and rest; 2nd dispatch
        f.stateCtrl.add(_state(status: BreathSessionStatus.rest, phase: BreathPhase.exhale, currentIntervalMs: 6000, currentPhaseTotalDuration: 5));
        await Future<void>.delayed(Duration.zero);

        expect(f.instructionStream.sendSampleCalls, hasLength(2));
        expect(f.instructionStream.sendSampleCalls.last, ('sid', 'exhale', 5));

        f.target.dispose();
      },
    );

    test(
      'should dispatch tickCount from currentPhaseTotalDuration regardless of currentIntervalMs value (e.g. -1 no longer poisons the payload)',
      () async {
        final f = _make();
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);
        // Prime
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause, phase: BreathPhase.inhale, exerciseIndex: 0));
        await Future<void>.delayed(Duration.zero);
        // Phase change with currentIntervalMs=-1 — tickCount comes from currentPhaseTotalDuration, not currentIntervalMs
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale, exerciseIndex: 0, currentIntervalMs: -1, currentPhaseTotalDuration: 7));
        await Future<void>.delayed(Duration.zero);

        expect(f.instructionStream.sendSampleCalls, hasLength(1));
        expect(f.instructionStream.sendSampleCalls.first, ('sid', 'exhale', 7));

        f.target.dispose();
      },
    );
  });

  // ── Phase 10: pending flush ───────────────────────────────────────────────

  group('BreathModuleStateChannel — pending flush', () {
    test(
      'should not call instructionStream.sendSample immediately when a phase change occurs while moduleSessionId is null',
      () async {
        final f = _make();
        // No ModuleState seeded — _moduleSessionId stays null
        // Prime _previousPhase so the next emission is a genuine phase change
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause, phase: BreathPhase.inhale));
        await Future<void>.delayed(Duration.zero);
        // Phase change — sessionId null → buffered, not dispatched
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale, currentIntervalMs: 5000));
        await Future<void>.delayed(Duration.zero);

        expect(f.instructionStream.sendSampleCalls, isEmpty);

        f.target.dispose();
      },
    );

    test(
      'should call instructionStream.sendSample exactly once with the buffered phase and tickCount when a ModuleState with a non-null moduleSessionId arrives after a buffered phase change',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause, phase: BreathPhase.inhale));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale, currentIntervalMs: 5000, currentPhaseTotalDuration: 6));
        await Future<void>.delayed(Duration.zero);
        // moduleSessionId becomes available — triggers _flushPending
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);

        expect(f.instructionStream.sendSampleCalls, hasLength(1));
        expect(f.instructionStream.sendSampleCalls.first, ('sid', 'exhale', 6));

        f.target.dispose();
      },
    );

    test(
      'should not call instructionStream.sendSample again when a second ModuleState with the same moduleSessionId arrives after a buffered phase change has already been flushed',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause, phase: BreathPhase.inhale));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale, currentIntervalMs: 5000));
        await Future<void>.delayed(Duration.zero);
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);
        // Second ModuleState — buffer already cleared on first flush
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);

        expect(f.instructionStream.sendSampleCalls, hasLength(1));

        f.target.dispose();
      },
    );

    test(
      'should not call instructionStream.sendSample when a ModuleState with a non-null moduleSessionId arrives before any phase change has occurred',
      () async {
        final f = _make();
        // Push ModuleState immediately after construction — no BreathSessionState emitted yet
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);

        expect(f.instructionStream.sendSampleCalls, isEmpty);

        f.target.dispose();
      },
    );

    test(
      'should overwrite the pending instruction with the latest state when multiple phase changes occur before moduleSessionId becomes available, flushing only the most recent one',
      () async {
        final f = _make();
        // Prime
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause, phase: BreathPhase.inhale));
        await Future<void>.delayed(Duration.zero);
        // First phase change — buffered
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale, currentIntervalMs: 5000));
        await Future<void>.delayed(Duration.zero);
        // Second phase change — lifecycle short-circuits (same status=breath), but _handleInstruction
        // still runs from _onState and overwrites _pendingInstruction with the latest state
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.inhale, exerciseIndex: 1, currentIntervalMs: 6000, currentPhaseTotalDuration: 8));
        await Future<void>.delayed(Duration.zero);
        // Flush
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);

        expect(f.instructionStream.sendSampleCalls, [('sid', 'inhale', 8)]);

        f.target.dispose();
      },
    );

    test(
      'should call instructionStream.sendSample with the arguments derived from the buffered state, not from any non-ready state emitted between buffering and flush',
      () async {
        final f = _make();
        // Prime
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause, phase: BreathPhase.inhale));
        await Future<void>.delayed(Duration.zero);
        // Phase change — buffered
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale, currentIntervalMs: 5000, currentPhaseTotalDuration: 9));
        await Future<void>.delayed(Duration.zero);
        // Non-ready state — _onState returns early, _pendingInstruction is not touched
        f.stateCtrl.add(_state(
          status: BreathSessionStatus.breath,
          loadState: SessionLoadState.loading,
          phase: BreathPhase.hold,
          currentIntervalMs: 9000,
        ));
        await Future<void>.delayed(Duration.zero);
        // Flush
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);

        expect(f.instructionStream.sendSampleCalls, hasLength(1));
        expect(f.instructionStream.sendSampleCalls.first, ('sid', 'exhale', 9));

        f.target.dispose();
      },
    );
  });

  // ── Phase 11: reset() clears instruction state ────────────────────────────

  group('BreathModuleStateChannel — reset() clears instruction state', () {
    test(
      'should clear moduleSessionId on reset, verified by emitting a phase change after reset and then pushing a new ModuleState — the new sessionId must appear in the dispatched instruction args',
      () async {
        final f = _make();
        // Seed sid-A
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid-A', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);
        // First phase change — dispatches with sid-A
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.inhale, exerciseIndex: 0));
        await Future<void>.delayed(Duration.zero);
        expect(f.instructionStream.sendSampleCalls, hasLength(1));
        // Reset — clears _moduleSessionId
        f.target.reset();
        // Post-reset phase change — _moduleSessionId=null → buffered (not dispatched immediately)
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale, currentIntervalMs: 5000));
        await Future<void>.delayed(Duration.zero);
        expect(f.instructionStream.sendSampleCalls, hasLength(1));
        // Push sid-B — flushed with the new sessionId, proving sid-A was cleared
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid-B', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);

        expect(f.instructionStream.sendSampleCalls, hasLength(2));
        expect(f.instructionStream.sendSampleCalls.last.$1, 'sid-B');
        expect(f.channel.startCalls, hasLength(2));

        f.target.dispose();
      },
    );

    test(
      'should clear _pendingInstruction on reset, verified by buffering a phase change, calling reset, then pushing a ModuleState and observing no sendSample call',
      () async {
        final f = _make();
        // Prime (no ModuleState seeded)
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause, phase: BreathPhase.inhale));
        await Future<void>.delayed(Duration.zero);
        // Phase change — buffered
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale, currentIntervalMs: 5000));
        await Future<void>.delayed(Duration.zero);
        // Reset — clears _pendingInstruction
        f.target.reset();
        // Push ModuleState — _flushPending finds nothing (buffer cleared by reset)
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);

        expect(f.instructionStream.sendSampleCalls, isEmpty);

        f.target.dispose();
      },
    );

    test(
      'should clear _previousPhase on reset, verified by emitting the same phase before and after reset while moduleSessionId is available and observing a fresh sendSample call after reset',
      () async {
        final f = _make();
        // Seed moduleSessionId
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);
        // Prime
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause, phase: BreathPhase.inhale, exerciseIndex: 0));
        await Future<void>.delayed(Duration.zero);
        // First dispatch (inhale → exhale)
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale, exerciseIndex: 0, currentIntervalMs: 4000));
        await Future<void>.delayed(Duration.zero);
        expect(f.instructionStream.sendSampleCalls, hasLength(1));
        // Reset — clears _previousPhase (and _moduleSessionId)
        f.target.reset();
        // Re-seed: restore _moduleSessionId (reset() cleared it; needed before phase-change emission)
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);
        // Prime again (same starting phase as before reset)
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause, phase: BreathPhase.inhale, exerciseIndex: 0));
        await Future<void>.delayed(Duration.zero);
        // Second dispatch — same phase transition as before, but _previousPhase was cleared → phaseChanged=true
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale, exerciseIndex: 0, currentIntervalMs: 5000, currentPhaseTotalDuration: 10));
        await Future<void>.delayed(Duration.zero);

        expect(f.instructionStream.sendSampleCalls, hasLength(2));
        expect(f.instructionStream.sendSampleCalls.last, ('sid', 'exhale', 10));
        expect(f.channel.startCalls, hasLength(2));

        f.target.dispose();
      },
    );

    test(
      'should clear _previousExerciseIndex on reset, verified by emitting the same exerciseIndex pattern before and after reset and observing a fresh sendSample call after reset',
      () async {
        final f = _make();
        // Seed moduleSessionId
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);
        // Prime
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause, phase: BreathPhase.inhale, exerciseIndex: 0));
        await Future<void>.delayed(Duration.zero);
        // First dispatch (exerciseIndex 0 → 1)
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.inhale, exerciseIndex: 1, currentIntervalMs: 4000));
        await Future<void>.delayed(Duration.zero);
        expect(f.instructionStream.sendSampleCalls, hasLength(1));
        // Reset — clears _previousExerciseIndex (and _moduleSessionId)
        f.target.reset();
        // Re-seed: restore _moduleSessionId
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);
        // Prime again
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause, phase: BreathPhase.inhale, exerciseIndex: 0));
        await Future<void>.delayed(Duration.zero);
        // Second dispatch — same exerciseIndex transition, but _previousExerciseIndex was cleared → phaseChanged=true
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.inhale, exerciseIndex: 1, currentIntervalMs: 5000, currentPhaseTotalDuration: 11));
        await Future<void>.delayed(Duration.zero);

        expect(f.instructionStream.sendSampleCalls, hasLength(2));
        expect(f.instructionStream.sendSampleCalls.last, ('sid', 'inhale', 11));
        expect(f.channel.startCalls, hasLength(2));

        f.target.dispose();
      },
    );

    test(
      'should keep the channel.state subscription alive across reset, verified by pushing a new ModuleState after reset and observing the updated moduleSessionId is used on the next phase-change instruction dispatch',
      () async {
        final f = _make();
        // Reset immediately — no pre-reset start
        f.target.reset();
        // Push new ModuleState — subscription must still be alive after reset
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid-new', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);
        // Prime
        f.stateCtrl.add(_state(status: BreathSessionStatus.pause, phase: BreathPhase.inhale, exerciseIndex: 0));
        await Future<void>.delayed(Duration.zero);
        // Phase change — uses sid-new from the live subscription
        f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale, currentIntervalMs: 5000));
        await Future<void>.delayed(Duration.zero);

        expect(f.instructionStream.sendSampleCalls, hasLength(1));
        expect(f.instructionStream.sendSampleCalls.first.$1, 'sid-new');
        expect(f.channel.startCalls, hasLength(1));

        f.target.dispose();
      },
    );
  });

  // ── Phase 12: dispose() subscription bookkeeping ─────────────────────────

  group('BreathModuleStateChannel — dispose() subscription bookkeeping', () {
    test(
      'should cancel the channel.state subscription on dispose, verified by reading the moduleSessionId getter after pushing a ModuleState post-dispose',
      () async {
        final f = _make();
        f.target.dispose();
        // Post-dispose: push a ModuleState — _channelSub must be cancelled so this has no effect
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid-after-dispose', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);

        // moduleSessionId stays null — listener did not fire
        expect(f.target.moduleSessionId, isNull);
        expect(f.instructionStream.sendSampleCalls, isEmpty);
      },
    );
  });
}
