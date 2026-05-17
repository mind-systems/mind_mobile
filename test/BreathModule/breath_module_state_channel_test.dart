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
  void sendSample(String sessionId, String phase, int durationMs) =>
      sendSampleCalls.add((sessionId, phase, durationMs));

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
}) {
  return BreathSessionState(
    loadState: loadState,
    status: status,
    phase: phase,
    exerciseIndex: exerciseIndex,
    remainingTicks: 0,
    currentIntervalMs: currentIntervalMs,
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
}
