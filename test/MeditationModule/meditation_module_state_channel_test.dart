import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Core/Grpc/ModuleState.dart';
import 'package:mind/Core/Grpc/ModuleStateChannel.dart';
import 'package:mind/Core/Grpc/ModuleStateEvent.dart';
import 'package:mind/MeditationModule/Core/MeditationModuleStateChannel.dart';
import 'package:meditation_module/meditation_module.dart' show MeditationSessionState, MeditationSessionStatus;

// ──────────────────────────────────────────────────────────────────────────────
// Fakes
// ──────────────────────────────────────────────────────────────────────────────

class _FakeChannel implements ModuleStateChannel {
  final List<(ActivityType, String?)> startCalls = [];
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
  void start({required ActivityType type, String? refId, int? clientTimestampMs}) =>
      startCalls.add((type, refId));

  @override
  void end({int? clientTimestampMs}) => endCount++;

  @override
  void stop() => stopCount++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────────

MeditationSessionState _state({required MeditationSessionStatus status}) {
  return MeditationSessionState(status: status, poseId: 'p');
}

typedef _Fixture = ({
  _FakeChannel channel,
  StreamController<MeditationSessionState> stateCtrl,
  MeditationModuleStateChannel target,
});

_Fixture _make({String refId = 'pose-uuid-1'}) {
  final channel = _FakeChannel();
  final stateCtrl = StreamController<MeditationSessionState>.broadcast();
  final target = MeditationModuleStateChannel(
    channel: channel,
    stateStream: stateCtrl.stream,
    refId: refId,
  );
  return (
    channel: channel,
    stateCtrl: stateCtrl,
    target: target,
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

void main() {
  // ── Phase 1: scaffolding ──────────────────────────────────────────────────

  group('MeditationModuleStateChannel — scaffolding', () {
    test('should construct without throwing when all required parameters are provided', () {
      final f = _make();
      expect(f.target, isNotNull);
      f.target.dispose();
    });

    test('should return null for moduleSessionId before any ModuleState arrives', () {
      final f = _make();
      expect(f.target.moduleSessionId, isNull);
      f.target.dispose();
    });
  });

  // ── Phase 2: start transitions ────────────────────────────────────────────

  group('MeditationModuleStateChannel — start transitions', () {
    test(
      'should call channel.start with ActivityType.meditation and the constructor refId when the first emitted state has status=active',
      () async {
        final f = _make(refId: 'pose-ref-1');
        f.stateCtrl.add(_state(status: MeditationSessionStatus.active));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.startCalls, hasLength(1));
        expect(f.channel.startCalls.first.$1, ActivityType.meditation);
        expect(f.channel.startCalls.first.$2, 'pose-ref-1');

        f.target.dispose();
      },
    );

    test(
      'should call channel.start with ActivityType.meditation and the constructor refId when transitioning from idle to active for the first time',
      () async {
        final f = _make(refId: 'pose-ref-1');
        f.stateCtrl.add(_state(status: MeditationSessionStatus.idle));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: MeditationSessionStatus.active));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.startCalls, hasLength(1));
        expect(f.channel.startCalls.first.$1, ActivityType.meditation);
        expect(f.channel.startCalls.first.$2, 'pose-ref-1');

        f.target.dispose();
      },
    );

    test(
      'should not re-invoke start when the same active state is emitted twice in a row',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: MeditationSessionStatus.active));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: MeditationSessionStatus.active));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.startCalls, hasLength(1));

        f.target.dispose();
      },
    );

    test(
      'should pass refId through unchanged when refId is an empty string',
      () async {
        final f = _make(refId: '');
        f.stateCtrl.add(_state(status: MeditationSessionStatus.active));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.startCalls, hasLength(1));
        expect(f.channel.startCalls.first.$2, '');

        f.target.dispose();
      },
    );
  });

  // ── Phase 3: re-arm transitions ───────────────────────────────────────────

  group('MeditationModuleStateChannel — re-arm transitions', () {
    test(
      'should call channel.end exactly once when transitioning from active to idle',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: MeditationSessionStatus.active));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: MeditationSessionStatus.idle));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.endCount, 1);

        f.target.dispose();
      },
    );

    test(
      'should not call channel.end when idle is emitted before any active',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: MeditationSessionStatus.idle));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.endCount, 0);

        f.target.dispose();
      },
    );

    test(
      'should allow a fresh start when active is emitted again after an active to idle cycle',
      () async {
        final f = _make();
        // First cycle
        f.stateCtrl.add(_state(status: MeditationSessionStatus.active));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: MeditationSessionStatus.idle));
        await Future<void>.delayed(Duration.zero);
        // Second start — re-arm should have reset _started = false
        f.stateCtrl.add(_state(status: MeditationSessionStatus.active));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.startCalls, hasLength(2));
        expect(f.channel.endCount, 1);

        f.target.dispose();
      },
    );

    test(
      'should call start twice and end twice across two full active to idle cycles',
      () async {
        final f = _make();
        // First cycle
        f.stateCtrl.add(_state(status: MeditationSessionStatus.active));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: MeditationSessionStatus.idle));
        await Future<void>.delayed(Duration.zero);
        // Second cycle
        f.stateCtrl.add(_state(status: MeditationSessionStatus.active));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: MeditationSessionStatus.idle));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.startCalls, hasLength(2));
        expect(f.channel.endCount, 2);

        f.target.dispose();
      },
    );
  });

  // ── Phase 4: status-unchanged idempotence ─────────────────────────────────

  group('MeditationModuleStateChannel — status-unchanged idempotence', () {
    test(
      'should not call start or end when the same idle state is emitted twice in a row',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: MeditationSessionStatus.idle));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: MeditationSessionStatus.idle));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.startCalls, isEmpty);
        expect(f.channel.endCount, 0);

        f.target.dispose();
      },
    );

    test(
      'should call end only once when an active to idle to idle sequence is emitted',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: MeditationSessionStatus.active));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: MeditationSessionStatus.idle));
        await Future<void>.delayed(Duration.zero);
        // Duplicate idle — status-unchanged guard short-circuits
        f.stateCtrl.add(_state(status: MeditationSessionStatus.idle));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.endCount, 1);

        f.target.dispose();
      },
    );

    test(
      'should handle rapid active to idle to active to idle to active cycles with three start calls and two end calls',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: MeditationSessionStatus.active));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: MeditationSessionStatus.idle));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: MeditationSessionStatus.active));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: MeditationSessionStatus.idle));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: MeditationSessionStatus.active));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.startCalls, hasLength(3));
        expect(f.channel.endCount, 2);

        f.target.dispose();
      },
    );
  });

  // ── Phase 5: moduleSessionId capture ─────────────────────────────────────

  group('MeditationModuleStateChannel — moduleSessionId capture', () {
    test(
      'should capture moduleSessionId when channel.state emits a ModuleState with a non-null id',
      () async {
        final f = _make();
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'session-abc', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);

        expect(f.target.moduleSessionId, 'session-abc');

        f.target.dispose();
      },
    );

    test(
      'should not update moduleSessionId when channel.state emits a ModuleState with a null id after a non-null id',
      () async {
        final f = _make();
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'session-abc', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: null, status: ModuleStateStatus.idle),
        );
        await Future<void>.delayed(Duration.zero);

        // Null emission must not overwrite the previously captured id
        expect(f.target.moduleSessionId, 'session-abc');

        f.target.dispose();
      },
    );
  });

  // ── Phase 6: dispose ──────────────────────────────────────────────────────

  group('MeditationModuleStateChannel — dispose', () {
    test(
      'should not call channel.stop when dispose is invoked before any state has been emitted',
      () {
        final f = _make();
        f.target.dispose();

        expect(f.channel.stopCount, 0);
      },
    );

    test(
      'should call channel.stop exactly once when dispose is invoked while the session is active',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: MeditationSessionStatus.active));
        await Future<void>.delayed(Duration.zero);
        f.target.dispose();

        expect(f.channel.stopCount, 1);
      },
    );

    test(
      'should not call channel.stop when dispose is invoked after an active to idle cycle',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: MeditationSessionStatus.active));
        await Future<void>.delayed(Duration.zero);
        f.stateCtrl.add(_state(status: MeditationSessionStatus.idle));
        await Future<void>.delayed(Duration.zero);
        f.target.dispose();

        expect(f.channel.stopCount, 0);
      },
    );

    test(
      'should not dispatch any further lifecycle calls when state emissions arrive after dispose',
      () async {
        final f = _make();
        f.stateCtrl.add(_state(status: MeditationSessionStatus.active));
        await Future<void>.delayed(Duration.zero);
        f.target.dispose();
        // _stateSub is cancelled; further emissions must not reach _onState
        f.stateCtrl.add(_state(status: MeditationSessionStatus.idle));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.endCount, 0);
      },
    );

    test(
      'should not update moduleSessionId when a ModuleState is pushed after dispose',
      () async {
        final f = _make();
        f.target.dispose();
        // _channelSub is cancelled; this must not update moduleSessionId
        f.channel.stateController.add(
          const ModuleState(moduleSessionId: 'sid-after-dispose', status: ModuleStateStatus.active),
        );
        await Future<void>.delayed(Duration.zero);

        expect(f.target.moduleSessionId, isNull);
      },
    );
  });
}
