import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' as grpc;

import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Core/Grpc/GrpcConnectionManager.dart';
import 'package:mind/Core/Grpc/GrpcConnectionState.dart';
import 'package:mind/Core/Grpc/ModuleState.dart';
import 'package:mind/Core/Grpc/ModuleStateChannel.dart';
import 'package:mind/Core/Grpc/ModuleStateEvent.dart';
import 'package:mind/Core/Grpc/generated/module_state.pb.dart' as proto;
import 'package:mind/Core/Grpc/generated/module_state.pbgrpc.dart' as protosvc;
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/Models/User.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Fakes
// ──────────────────────────────────────────────────────────────────────────────

/// Wraps a plain Stream as a ClientCall so ResponseStream can be constructed.
class _FakeClientCall
    implements grpc.ClientCall<proto.StateRequest, proto.StateResponse> {
  final Stream<proto.StateResponse> _responses;
  _FakeClientCall(this._responses);

  @override
  Stream<proto.StateResponse> get response => _responses;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// One recorded call to trackActivity.
class _TrackActivityCall {
  final grpc.CallOptions? options;
  final StreamController<proto.StateResponse> responseCtrl =
      StreamController<proto.StateResponse>();
  final List<proto.StateRequest> sentRequests = [];

  _TrackActivityCall(this.options);
}

/// Fake ModuleStateServiceClient — records every trackActivity invocation,
/// captures sent StateRequests, and lets the test inject StateResponse frames.
class _FakeModuleStateServiceClient implements protosvc.ModuleStateServiceClient {
  final List<_TrackActivityCall> calls = [];

  _TrackActivityCall? get latestCall => calls.isEmpty ? null : calls.last;

  @override
  grpc.ResponseStream<proto.StateResponse> trackActivity(
    Stream<proto.StateRequest> request, {
    grpc.CallOptions? options,
  }) {
    final call = _TrackActivityCall(options);
    calls.add(call);
    request.listen((req) => call.sentRequests.add(req));
    return grpc.ResponseStream<proto.StateResponse>(
        _FakeClientCall(call.responseCtrl.stream));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake GrpcConnectionManager — backs connectionState with a broadcast
/// controller and tracks method calls.
class _FakeConnectionManager implements GrpcConnectionManager {
  final _ctrl = StreamController<GrpcConnectionState>.broadcast();

  int confirmConnectedCount = 0;
  int disconnectCount = 0;
  int scheduleReconnectCount = 0;

  @override
  Stream<GrpcConnectionState> get connectionState => _ctrl.stream;

  @override
  void confirmConnected() => confirmConnectedCount++;

  @override
  void disconnect() => disconnectCount++;

  @override
  void scheduleReconnect() => scheduleReconnectCount++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────────

final _authenticatedUser = User(
  id: 'user-id',
  email: 'test@example.com',
  name: 'Test User',
  language: 'en',
  isGuest: false,
);

final _guestUser = User(
  id: 'guest-id',
  email: '',
  name: 'Guest',
  language: '',
  isGuest: true,
);

typedef _Fixture = ({
  ModuleStateChannel channel,
  _FakeModuleStateServiceClient service,
  _FakeConnectionManager connManager,
  StreamController<AuthState> authCtrl,
});

_Fixture _make() {
  final service = _FakeModuleStateServiceClient();
  final connManager = _FakeConnectionManager();
  final authCtrl = StreamController<AuthState>.broadcast();
  final channel = ModuleStateChannel(
    moduleStateService: service,
    connectionManager: connManager,
    authStream: authCtrl.stream,
  );
  return (
    channel: channel,
    service: service,
    connManager: connManager,
    authCtrl: authCtrl,
  );
}

/// Emits GrpcConnectionState.connected and pumps a microtask so
/// _openSessionStream runs and _sessionSink becomes non-null.
Future<void> _connect(_Fixture f) async {
  f.connManager._ctrl.add(GrpcConnectionState.connected);
  await Future<void>.delayed(Duration.zero);
}

Future<void> _disconnect(_Fixture f) async {
  f.connManager._ctrl.add(GrpcConnectionState.disconnected);
  await Future<void>.delayed(Duration.zero);
}

/// Connects + emits an ACTIVE StateResponse so currentState becomes active.
Future<void> _activateSession(
  _Fixture f, {
  String sessionId = 'test-sid',
}) async {
  await _connect(f);
  f.service.latestCall!.responseCtrl.add(proto.StateResponse(
    sessionState: proto.StateEvent(
      status: proto.ActivityStatus.ACTIVE,
      moduleSessionId: sessionId,
    ),
  ));
  await Future<void>.delayed(Duration.zero);
}

proto.StateResponse _sessionStateResponse(proto.ActivityStatus status,
    {String moduleSessionId = '', bool isPaused = false, proto.ActivityType? activityType}) {
  return proto.StateResponse(
    sessionState: proto.StateEvent(
      status: status,
      moduleSessionId: moduleSessionId,
      isPaused: isPaused,
      activityType: activityType,
    ),
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

void main() {
  // ── Group 1: RESUMED ───────────────────────────────────────────────────────

  group('ModuleStateChannel — RESUMED proto event', () {
    test(
      'should emit ModuleSessionResumed with the moduleSessionId when a RESUMED frame arrives',
      () async {
        final f = _make();
        await _connect(f);
        final received = <ModuleStateEvent>[];
        f.channel.events.listen(received.add);

        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.RESUMED,
          moduleSessionId: 'test-sid',
        ));
        await Future<void>.delayed(Duration.zero);

        expect(received, hasLength(1));
        expect(received.first, isA<ModuleSessionResumed>());
        expect(
          (received.first as ModuleSessionResumed).moduleSessionId,
          'test-sid',
        );

        f.channel.dispose();
      },
    );

    test(
      'should set currentState to active with the frame moduleSessionId on RESUMED',
      () async {
        final f = _make();
        await _connect(f);

        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.RESUMED,
          moduleSessionId: 'test-sid',
        ));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.currentState.status, ModuleStateStatus.active);
        expect(f.channel.currentState.moduleSessionId, 'test-sid');

        f.channel.dispose();
      },
    );

    test(
      'should set currentState.isPaused to true when RESUMED frame has isPaused=true',
      () async {
        final f = _make();
        await _connect(f);

        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.RESUMED,
          moduleSessionId: 'test-id',
          isPaused: true,
        ));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.currentState.isPaused, isTrue);

        f.channel.dispose();
      },
    );

    test(
      'should set currentState.isPaused to false when RESUMED frame has isPaused=false',
      () async {
        final f = _make();
        await _connect(f);

        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.RESUMED,
          moduleSessionId: 'test-id',
          isPaused: false,
        ));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.currentState.isPaused, isFalse);

        f.channel.dispose();
      },
    );

    test(
      'should not fold RESUMED into ModuleSessionStarted (emits Resumed, not Started)',
      () async {
        final f = _make();
        await _connect(f);
        final received = <ModuleStateEvent>[];
        f.channel.events.listen(received.add);

        // State is idle before the frame — RESUMED should still emit Resumed,
        // not go through the ACTIVE branch that emits Started.
        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.RESUMED,
          moduleSessionId: 'sid',
        ));
        await Future<void>.delayed(Duration.zero);

        expect(received, hasLength(1));
        expect(received.first, isA<ModuleSessionResumed>());
        expect(received.first, isNot(isA<ModuleSessionStarted>()));

        f.channel.dispose();
      },
    );

    test(
      'should clear pending-start and pending-pause guards on RESUMED so a subsequent pause is allowed',
      () async {
        final f = _make();
        await _activateSession(f, sessionId: 'sid');

        // Induce _isPendingPause=true by pausing.
        f.channel.pause();
        await Future<void>.delayed(Duration.zero);
        final countAfterFirstPause = f.service.latestCall!.sentRequests.length;

        // RESUMED clears both _isPendingStart and _isPendingPause.
        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.RESUMED,
          moduleSessionId: 'sid',
          isPaused: false,
        ));
        await Future<void>.delayed(Duration.zero);

        // isPaused is now false and _isPendingPause is cleared → pause is allowed.
        f.channel.pause();
        await Future<void>.delayed(Duration.zero);

        expect(
          f.service.latestCall!.sentRequests.length,
          greaterThan(countAfterFirstPause),
        );

        f.channel.dispose();
      },
    );
  });

  // ── Group 2: ABANDONED ────────────────────────────────────────────────────

  group('ModuleStateChannel — ABANDONED proto event', () {
    test(
      'should emit ModuleSessionAbandoned when an ABANDONED frame arrives',
      () async {
        final f = _make();
        await _activateSession(f, sessionId: 'active-id');
        final received = <ModuleStateEvent>[];
        f.channel.events.listen(received.add);

        f.service.latestCall!.responseCtrl.add(
          _sessionStateResponse(proto.ActivityStatus.ABANDONED),
        );
        await Future<void>.delayed(Duration.zero);

        expect(received, hasLength(1));
        expect(received.first, isA<ModuleSessionAbandoned>());

        f.channel.dispose();
      },
    );

    test(
      'should reset currentState to ModuleState.initial (idle, null id) on ABANDONED',
      () async {
        final f = _make();
        await _activateSession(f, sessionId: 'live-id');

        f.service.latestCall!.responseCtrl.add(
          _sessionStateResponse(proto.ActivityStatus.ABANDONED),
        );
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.currentState.status, ModuleStateStatus.idle);
        expect(f.channel.currentState.moduleSessionId, isNull);

        f.channel.dispose();
      },
    );
  });

  // ── Group 3: sessionError / no_active_session demotion ────────────────────

  group('ModuleStateChannel — sessionError handling', () {
    test(
      'should silently reset currentState to initial when sessionError code is no_active_session',
      () async {
        final f = _make();
        await _activateSession(f);

        f.service.latestCall!.responseCtrl.add(proto.StateResponse(
          sessionError: proto.StateErrorEvent(
            code: 'no_active_session',
            message: 'no session running',
          ),
        ));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.currentState.status, ModuleStateStatus.idle);
        expect(f.channel.currentState.moduleSessionId, isNull);

        f.channel.dispose();
      },
    );

    test(
      'should not emit any ModuleStateEvent when no_active_session error is received',
      () async {
        final f = _make();
        await _activateSession(f);
        final received = <ModuleStateEvent>[];
        f.channel.events.listen(received.add);

        f.service.latestCall!.responseCtrl.add(proto.StateResponse(
          sessionError: proto.StateErrorEvent(
            code: 'no_active_session',
            message: 'gone',
          ),
        ));
        await Future<void>.delayed(Duration.zero);

        expect(received, isEmpty);

        f.channel.dispose();
      },
    );

    test(
      'should not reset state when a sessionError with a different code arrives',
      () async {
        final f = _make();
        await _activateSession(f, sessionId: 'kept-id');

        f.service.latestCall!.responseCtrl.add(proto.StateResponse(
          sessionError: proto.StateErrorEvent(
            code: 'some_other_error',
            message: 'boom',
          ),
        ));
        await Future<void>.delayed(Duration.zero);

        // State must remain active — only 'no_active_session' triggers reset.
        expect(f.channel.currentState.status, ModuleStateStatus.active);
        expect(f.channel.currentState.moduleSessionId, 'kept-id');

        f.channel.dispose();
      },
    );
  });

  // ── Group 4: module-session-id metadata attachment ─────────────────────────

  group('ModuleStateChannel — CallOptions metadata', () {
    test(
      'should attach module-session-id metadata when currentState is active with a non-empty id',
      () async {
        final f = _make();
        // Activate so state = active('live-123')
        await _activateSession(f, sessionId: 'live-123');
        // Reconnect to open a fresh stream against the active state.
        await _disconnect(f);
        f.connManager._ctrl.add(GrpcConnectionState.connected);
        await Future<void>.delayed(Duration.zero);

        final latestOptions = f.service.latestCall!.options;
        expect(latestOptions, isNotNull);
        expect(latestOptions!.metadata['module-session-id'], 'live-123');

        f.channel.dispose();
      },
    );

    test(
      'should pass null options when currentState.status is not active',
      () async {
        final f = _make();
        // State = idle at first connection.
        await _connect(f);

        expect(f.service.calls.first.options, isNull);

        f.channel.dispose();
      },
    );

    test(
      'should pass null options when moduleSessionId is null',
      () async {
        final f = _make();
        // Manually transition: connect, send RESUMED with a known id, then
        // reset and reconnect with null id (hard to do without internal access).
        // Simpler: connect when state is idle — moduleSessionId is null.
        await _connect(f);
        expect(f.service.calls.first.options, isNull);

        f.channel.dispose();
      },
    );

    test(
      'should pass null options when moduleSessionId is an empty string',
      () async {
        final f = _make();
        // Activate with an empty moduleSessionId.
        await _connect(f);
        f.service.latestCall!.responseCtrl.add(proto.StateResponse(
          sessionState: proto.StateEvent(
            status: proto.ActivityStatus.ACTIVE,
            moduleSessionId: '',
          ),
        ));
        await Future<void>.delayed(Duration.zero);
        // Reconnect to trigger _openSessionStream with moduleSessionId=''.
        await _disconnect(f);
        f.connManager._ctrl.add(GrpcConnectionState.connected);
        await Future<void>.delayed(Duration.zero);

        expect(f.service.latestCall!.options, isNull);

        f.channel.dispose();
      },
    );

    test(
      'should recompute metadata from currentState on each reconnect (stream re-open)',
      () async {
        final f = _make();
        // First connect while state is idle → no metadata.
        await _connect(f);
        expect(f.service.calls.first.options, isNull);

        // Transition to active('s1') via ACTIVE frame.
        f.service.latestCall!.responseCtrl.add(proto.StateResponse(
          sessionState: proto.StateEvent(
            status: proto.ActivityStatus.ACTIVE,
            moduleSessionId: 's1',
          ),
        ));
        await Future<void>.delayed(Duration.zero);
        expect(f.channel.currentState.moduleSessionId, 's1');

        // Reconnect → _openSessionStream reads currentState which is now active.
        await _disconnect(f);
        f.connManager._ctrl.add(GrpcConnectionState.connected);
        await Future<void>.delayed(Duration.zero);

        expect(f.service.calls.length, 2);
        expect(f.service.latestCall!.options, isNotNull);
        expect(f.service.latestCall!.options!.metadata['module-session-id'], 's1');

        f.channel.dispose();
      },
    );
  });

  // ── Group 5: client timestamp forwarding ─────────────────────────────────

  group('ModuleStateChannel — client timestamp forwarding', () {
    test(
      'should forward clientTimestampMs as Int64 in ActivityStartCmd when start() is given a timestamp',
      () async {
        final f = _make();
        await _connect(f);

        f.channel.start(
          type: ActivityType.breath,
          refId: 'sess-1',
          clientTimestampMs: 1234567890,
        );
        await Future<void>.delayed(Duration.zero);

        final requests = f.service.latestCall!.sentRequests;
        expect(requests, hasLength(1));
        expect(requests.first.activityStart.clientTimestampMs, Int64(1234567890));

        f.channel.dispose();
      },
    );

    test(
      'should send Int64(0) in ActivityStartCmd when start() is given clientTimestampMs=0',
      () async {
        final f = _make();
        await _connect(f);

        f.channel.start(
          type: ActivityType.breath,
          refId: '',
          clientTimestampMs: 0,
        );
        await Future<void>.delayed(Duration.zero);

        final requests = f.service.latestCall!.sentRequests;
        expect(requests, hasLength(1));
        expect(requests.first.activityStart.hasClientTimestampMs(), isTrue);
        expect(requests.first.activityStart.clientTimestampMs, Int64(0));

        f.channel.dispose();
      },
    );

    test(
      'should leave ActivityStartCmd.clientTimestampMs unset when start() is called without a timestamp',
      () async {
        final f = _make();
        await _connect(f);

        f.channel.start(type: ActivityType.breath, refId: 'sess-1');
        await Future<void>.delayed(Duration.zero);

        final requests = f.service.latestCall!.sentRequests;
        expect(requests, hasLength(1));
        expect(requests.first.activityStart.hasClientTimestampMs(), isFalse);

        f.channel.dispose();
      },
    );

    test(
      'should forward clientTimestampMs as Int64 in ActivityEndCmd when end() is given a timestamp',
      () async {
        final f = _make();
        await _activateSession(f);

        f.channel.end(clientTimestampMs: 9876543210);
        await Future<void>.delayed(Duration.zero);

        final requests = f.service.latestCall!.sentRequests;
        // Session activation sends a start request; end is the last one.
        final endReq = requests.last;
        expect(endReq.activityEnd.clientTimestampMs, Int64(9876543210));

        f.channel.dispose();
      },
    );

    test(
      'should leave ActivityEndCmd.clientTimestampMs unset when end() is called without a timestamp',
      () async {
        final f = _make();
        await _activateSession(f);

        f.channel.end();
        await Future<void>.delayed(Duration.zero);

        final requests = f.service.latestCall!.sentRequests;
        final endReq = requests.last;
        expect(endReq.activityEnd.hasClientTimestampMs(), isFalse);

        f.channel.dispose();
      },
    );

    test(
      'should not call DateTime.now() internally — timestamp field is unset when arg is omitted',
      () async {
        final f = _make();
        await _connect(f);

        f.channel.start(type: ActivityType.breath);
        await Future<void>.delayed(Duration.zero);

        final req = f.service.latestCall!.sentRequests.first;
        expect(req.activityStart.hasClientTimestampMs(), isFalse);

        f.channel.dispose();
      },
    );
  });

  // ── Group 6: ACTIVE / COMPLETED / INTERRUPTED / UNSPECIFIED / DISCONNECTED ─

  group('ModuleStateChannel — ACTIVE state transitions', () {
    test(
      'should emit ModuleSessionStarted on the first ACTIVE frame from idle',
      () async {
        final f = _make();
        await _connect(f);
        final received = <ModuleStateEvent>[];
        f.channel.events.listen(received.add);

        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.ACTIVE,
          moduleSessionId: 'new-sid',
        ));
        await Future<void>.delayed(Duration.zero);

        expect(received, hasLength(1));
        expect(received.first, isA<ModuleSessionStarted>());
        expect(
          (received.first as ModuleSessionStarted).moduleSessionId,
          'new-sid',
        );

        f.channel.dispose();
      },
    );

    test(
      'should emit ModuleSessionPaused when an ACTIVE frame transitions isPaused false to true',
      () async {
        final f = _make();
        await _activateSession(f); // isPaused=false
        final received = <ModuleStateEvent>[];
        f.channel.events.listen(received.add);

        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.ACTIVE,
          moduleSessionId: 'test-sid',
          isPaused: true,
        ));
        await Future<void>.delayed(Duration.zero);

        expect(received, hasLength(1));
        expect(received.first, isA<ModuleSessionPaused>());

        f.channel.dispose();
      },
    );

    test(
      'should emit ModuleSessionUnpaused when an ACTIVE frame transitions isPaused true to false',
      () async {
        final f = _make();
        await _connect(f);
        // First ACTIVE with isPaused=true.
        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.ACTIVE,
          moduleSessionId: 'test-sid',
          isPaused: true,
        ));
        await Future<void>.delayed(Duration.zero);
        final received = <ModuleStateEvent>[];
        f.channel.events.listen(received.add);

        // Second ACTIVE with isPaused=false.
        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.ACTIVE,
          moduleSessionId: 'test-sid',
          isPaused: false,
        ));
        await Future<void>.delayed(Duration.zero);

        expect(received, hasLength(1));
        expect(received.first, isA<ModuleSessionUnpaused>());

        f.channel.dispose();
      },
    );

    test(
      'should not emit a lifecycle event when an ACTIVE frame repeats the same paused state',
      () async {
        final f = _make();
        await _activateSession(f); // isPaused=false
        final received = <ModuleStateEvent>[];
        f.channel.events.listen(received.add);

        // Same isPaused=false — no pause/unpause event.
        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.ACTIVE,
          moduleSessionId: 'test-sid',
          isPaused: false,
        ));
        await Future<void>.delayed(Duration.zero);

        expect(received, isEmpty);

        f.channel.dispose();
      },
    );

    test(
      'should emit ModuleSessionEnded and reset to initial when a COMPLETED frame arrives',
      () async {
        final f = _make();
        await _activateSession(f);
        final received = <ModuleStateEvent>[];
        f.channel.events.listen(received.add);

        f.service.latestCall!.responseCtrl.add(
          _sessionStateResponse(proto.ActivityStatus.COMPLETED),
        );
        await Future<void>.delayed(Duration.zero);

        expect(received, hasLength(1));
        expect(received.first, isA<ModuleSessionEnded>());
        expect(f.channel.currentState.status, ModuleStateStatus.idle);
        expect(f.channel.currentState.moduleSessionId, isNull);

        f.channel.dispose();
      },
    );

    test(
      'should emit ModuleSessionEnded and reset to initial when an INTERRUPTED frame arrives',
      () async {
        final f = _make();
        await _activateSession(f);
        final received = <ModuleStateEvent>[];
        f.channel.events.listen(received.add);

        f.service.latestCall!.responseCtrl.add(
          _sessionStateResponse(proto.ActivityStatus.INTERRUPTED),
        );
        await Future<void>.delayed(Duration.zero);

        expect(received, hasLength(1));
        expect(received.first, isA<ModuleSessionEnded>());
        expect(f.channel.currentState.status, ModuleStateStatus.idle);

        f.channel.dispose();
      },
    );

    test(
      'should reset to initial and clear pending-start on an ACTIVITY_STATUS_UNSPECIFIED frame',
      () async {
        final f = _make();
        await _activateSession(f);
        final received = <ModuleStateEvent>[];
        f.channel.events.listen(received.add);

        f.service.latestCall!.responseCtrl.add(
          _sessionStateResponse(proto.ActivityStatus.ACTIVITY_STATUS_UNSPECIFIED),
        );
        await Future<void>.delayed(Duration.zero);

        // State resets; no event emitted.
        expect(f.channel.currentState.status, ModuleStateStatus.idle);
        expect(received, isEmpty);

        f.channel.dispose();
      },
    );

    test(
      'should ignore a DISCONNECTED frame (no state change, no event emitted)',
      () async {
        final f = _make();
        await _activateSession(f, sessionId: 'live');
        final received = <ModuleStateEvent>[];
        f.channel.events.listen(received.add);
        final stateBefore = f.channel.currentState;

        f.service.latestCall!.responseCtrl.add(
          _sessionStateResponse(proto.ActivityStatus.DISCONNECTED),
        );
        await Future<void>.delayed(Duration.zero);

        expect(received, isEmpty);
        expect(f.channel.currentState.status, stateBefore.status);
        expect(f.channel.currentState.moduleSessionId, stateBefore.moduleSessionId);

        f.channel.dispose();
      },
    );
  });

  // ── Group 7: stream lifecycle ──────────────────────────────────────────────

  group('ModuleStateChannel — connection-state driven stream open/close', () {
    test(
      'should open the trackActivity stream and report isConnected=true when connectionState becomes connected',
      () async {
        final f = _make();
        expect(f.channel.isConnected, isFalse);

        await _connect(f);

        expect(f.channel.isConnected, isTrue);
        expect(f.service.calls, hasLength(1));

        f.channel.dispose();
      },
    );

    test(
      'should close the stream and report isConnected=false when connectionState becomes disconnected',
      () async {
        final f = _make();
        await _connect(f);
        expect(f.channel.isConnected, isTrue);

        await _disconnect(f);

        expect(f.channel.isConnected, isFalse);

        f.channel.dispose();
      },
    );

    test(
      'should do nothing on connectionState=connecting',
      () async {
        final f = _make();
        f.connManager._ctrl.add(GrpcConnectionState.connecting);
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.isConnected, isFalse);
        expect(f.service.calls, isEmpty);

        f.channel.dispose();
      },
    );
  });

  group('ModuleStateChannel — backoff confirmation and transport failures', () {
    test(
      'should call confirmConnected exactly once on the first received frame after opening a stream',
      () async {
        final f = _make();
        await _connect(f);

        f.service.latestCall!.responseCtrl.add(
          _sessionStateResponse(proto.ActivityStatus.ACTIVE),
        );
        await Future<void>.delayed(Duration.zero);

        expect(f.connManager.confirmConnectedCount, 1);

        f.channel.dispose();
      },
    );

    test(
      'should not call confirmConnected again on subsequent frames',
      () async {
        final f = _make();
        await _connect(f);

        f.service.latestCall!.responseCtrl
            .add(_sessionStateResponse(proto.ActivityStatus.ACTIVE));
        await Future<void>.delayed(Duration.zero);

        f.service.latestCall!.responseCtrl
            .add(_sessionStateResponse(proto.ActivityStatus.ACTIVE));
        await Future<void>.delayed(Duration.zero);

        expect(f.connManager.confirmConnectedCount, 1);

        f.channel.dispose();
      },
    );

    test(
      'should close stream, disconnect, and scheduleReconnect when the response stream errors',
      () async {
        final f = _make();
        await _connect(f);
        expect(f.channel.isConnected, isTrue);

        f.service.latestCall!.responseCtrl.addError(Exception('transport error'));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.isConnected, isFalse);
        expect(f.connManager.disconnectCount, 1);
        expect(f.connManager.scheduleReconnectCount, 1);

        f.channel.dispose();
      },
    );

    test(
      'should close stream, disconnect, and scheduleReconnect when the response stream is done',
      () async {
        final f = _make();
        await _connect(f);

        await f.service.latestCall!.responseCtrl.close();
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.isConnected, isFalse);
        expect(f.connManager.disconnectCount, 1);
        expect(f.connManager.scheduleReconnectCount, 1);

        f.channel.dispose();
      },
    );
  });

  // ── Group 8: auth reset ───────────────────────────────────────────────────

  group('ModuleStateChannel — auth-driven reset', () {
    test(
      'should reset currentState to initial when authStream emits GuestState',
      () async {
        final f = _make();
        await _activateSession(f, sessionId: 'test');
        expect(f.channel.currentState.status, ModuleStateStatus.active);

        f.authCtrl.add(GuestState(_guestUser));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.currentState.status, ModuleStateStatus.idle);
        expect(f.channel.currentState.moduleSessionId, isNull);

        f.channel.dispose();
      },
    );

    test(
      'should not reset currentState when authStream emits AuthenticatedState',
      () async {
        final f = _make();
        await _activateSession(f, sessionId: 'test');

        f.authCtrl.add(AuthenticatedState(_authenticatedUser));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.currentState.status, ModuleStateStatus.active);

        f.channel.dispose();
      },
    );

    test(
      'should reset on GuestState even while the session stream is disconnected',
      () async {
        final f = _make();
        await _activateSession(f, sessionId: 'test');
        await _disconnect(f);
        // State is still active after disconnect (stream close doesn't reset state).
        expect(f.channel.currentState.status, ModuleStateStatus.active);

        f.authCtrl.add(GuestState(_guestUser));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.currentState.status, ModuleStateStatus.idle);

        f.channel.dispose();
      },
    );
  });

  // ── Group 9: _sendSessionRequest connectivity guard ───────────────────────

  group('ModuleStateChannel — sendSessionRequest connectivity guard', () {
    test(
      'should drop the request and not throw when start() is called while sink is null (not connected)',
      () async {
        final f = _make();
        // Not connected → _sessionSink is null.
        expect(f.channel.isConnected, isFalse);

        expect(
          () => f.channel.start(type: ActivityType.breath, refId: 'sess'),
          returnsNormally,
        );
        await Future<void>.delayed(Duration.zero);

        // No trackActivity call was made.
        expect(f.service.calls, isEmpty);

        f.channel.dispose();
      },
    );

    test(
      'should deliver exactly one StateRequest to the stub when start() is called while connected',
      () async {
        final f = _make();
        await _connect(f);

        f.channel.start(type: ActivityType.breath, refId: 'sess-1');
        await Future<void>.delayed(Duration.zero);

        expect(f.service.latestCall!.sentRequests, hasLength(1));

        f.channel.dispose();
      },
    );
  });

  // ── Group 10: disposal ────────────────────────────────────────────────────

  group('ModuleStateChannel — dispose teardown', () {
    test(
      'should stop reacting to connectionState emissions after dispose',
      () async {
        final f = _make();
        await _connect(f);
        expect(f.service.calls, hasLength(1));

        f.channel.dispose();

        f.connManager._ctrl.add(GrpcConnectionState.connected);
        await Future<void>.delayed(Duration.zero);

        // No new trackActivity call after dispose.
        expect(f.service.calls, hasLength(1));
      },
    );

    test(
      'should stop reacting to authStream emissions after dispose',
      () async {
        final f = _make();
        await _activateSession(f);
        f.channel.dispose();

        // After dispose, GuestState should not trigger a reset listener.
        // No exception should be thrown either.
        expect(
          () => f.authCtrl.add(GuestState(_guestUser)),
          returnsNormally,
        );
        await Future<void>.delayed(Duration.zero);
        // If the listener fired, _reset() would have called _state.add() on
        // a closed subject — which would throw. Reaching here without exception
        // confirms the subscription was cancelled.
      },
    );

    test(
      'should close the session stream and report isConnected=false after dispose',
      () async {
        final f = _make();
        await _connect(f);
        expect(f.channel.isConnected, isTrue);

        f.channel.dispose();

        expect(f.channel.isConnected, isFalse);
      },
    );

    test(
      'should close the state and events streams on dispose',
      () async {
        final f = _make();
        final stateDone = Completer<void>();
        final eventsDone = Completer<void>();
        f.channel.state.listen(null, onDone: stateDone.complete);
        f.channel.events.listen(null, onDone: eventsDone.complete);

        f.channel.dispose();
        await Future<void>.delayed(Duration.zero);

        expect(stateDone.isCompleted, isTrue);
        expect(eventsDone.isCompleted, isTrue);
      },
    );
  });

  // ── Group 11: session registry routing ────────────────────────────────────

  group('ModuleStateChannel — session registry routing', () {
    test(
      'should hold two distinct entries resolvable via rootId and childOfType(breath) after a root and breath ACTIVE frame',
      () async {
        final f = _make();
        await _connect(f);

        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.ACTIVE,
          moduleSessionId: 'root-1',
          activityType: proto.ActivityType.ROOT,
        ));
        await Future<void>.delayed(Duration.zero);
        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.ACTIVE,
          moduleSessionId: 'breath-1',
          activityType: proto.ActivityType.BREATH,
        ));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.rootId, 'root-1');
        expect(f.channel.childOfType(ActivityType.breath)?.id, 'breath-1');

        f.channel.dispose();
      },
    );

    test(
      'should remove only the child on a child COMPLETED frame, leaving the root resolvable',
      () async {
        final f = _make();
        await _connect(f);

        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.ACTIVE,
          moduleSessionId: 'root-1',
          activityType: proto.ActivityType.ROOT,
        ));
        await Future<void>.delayed(Duration.zero);
        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.ACTIVE,
          moduleSessionId: 'breath-1',
          activityType: proto.ActivityType.BREATH,
        ));
        await Future<void>.delayed(Duration.zero);

        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.COMPLETED,
          moduleSessionId: 'breath-1',
        ));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.childOfType(ActivityType.breath), isNull);
        expect(f.channel.rootId, 'root-1');

        f.channel.dispose();
      },
    );

    test(
      'should update the stored entry in place (not duplicate) when a second ACTIVE frame for the same child id flips isPaused',
      () async {
        final f = _make();
        await _connect(f);

        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.ACTIVE,
          moduleSessionId: 'breath-1',
          activityType: proto.ActivityType.BREATH,
          isPaused: false,
        ));
        await Future<void>.delayed(Duration.zero);
        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.ACTIVE,
          moduleSessionId: 'breath-1',
          activityType: proto.ActivityType.BREATH,
          isPaused: true,
        ));
        await Future<void>.delayed(Duration.zero);

        final child = f.channel.childOfType(ActivityType.breath);
        expect(child, isNotNull);
        expect(child!.id, 'breath-1');
        expect(child.isPaused, isTrue);

        f.channel.dispose();
      },
    );

    test(
      'should populate the registry from a normal breath ACTIVE frame with activityType set (regression guard)',
      () async {
        final f = _make();
        await _connect(f);

        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.ACTIVE,
          moduleSessionId: 'breath-1',
          activityType: proto.ActivityType.BREATH,
        ));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.childOfType(ActivityType.breath)?.id, 'breath-1');

        f.channel.dispose();
      },
    );

    test(
      'should clear the registry (rootId == null) and reset single-state to idle on an ACTIVITY_STATUS_UNSPECIFIED frame',
      () async {
        final f = _make();
        await _connect(f);

        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.ACTIVE,
          moduleSessionId: 'root-1',
          activityType: proto.ActivityType.ROOT,
        ));
        await Future<void>.delayed(Duration.zero);
        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.ACTIVE,
          moduleSessionId: 'breath-1',
          activityType: proto.ActivityType.BREATH,
        ));
        await Future<void>.delayed(Duration.zero);

        f.service.latestCall!.responseCtrl.add(
          _sessionStateResponse(proto.ActivityStatus.ACTIVITY_STATUS_UNSPECIFIED),
        );
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.currentState.status, ModuleStateStatus.idle);
        expect(f.channel.rootId, isNull);

        f.channel.dispose();
      },
    );

    test(
      'should clear the registry (rootId == null) when authStream emits GuestState (logout)',
      () async {
        final f = _make();
        await _connect(f);
        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.ACTIVE,
          moduleSessionId: 'root-1',
          activityType: proto.ActivityType.ROOT,
        ));
        await Future<void>.delayed(Duration.zero);
        expect(f.channel.rootId, 'root-1');

        f.authCtrl.add(GuestState(_guestUser));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.rootId, isNull);

        f.channel.dispose();
      },
    );

    test(
      'should clear the registry (rootId == null) on a no_active_session sessionError',
      () async {
        final f = _make();
        await _connect(f);
        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.ACTIVE,
          moduleSessionId: 'root-1',
          activityType: proto.ActivityType.ROOT,
        ));
        await Future<void>.delayed(Duration.zero);
        expect(f.channel.rootId, 'root-1');

        f.service.latestCall!.responseCtrl.add(proto.StateResponse(
          sessionError: proto.StateErrorEvent(
            code: 'no_active_session',
            message: 'no session running',
          ),
        ));
        await Future<void>.delayed(Duration.zero);

        expect(f.channel.rootId, isNull);

        f.channel.dispose();
      },
    );

    test(
      'should still emit the legacy ModuleSessionStarted -> ModuleSessionEnded sequence for a single-session breath-only flow (additive-wiring characterization)',
      () async {
        final f = _make();
        await _connect(f);
        final received = <ModuleStateEvent>[];
        f.channel.events.listen(received.add);

        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.ACTIVE,
          moduleSessionId: 'breath-1',
          activityType: proto.ActivityType.BREATH,
        ));
        await Future<void>.delayed(Duration.zero);
        f.service.latestCall!.responseCtrl.add(_sessionStateResponse(
          proto.ActivityStatus.COMPLETED,
          moduleSessionId: 'breath-1',
        ));
        await Future<void>.delayed(Duration.zero);

        expect(received, hasLength(2));
        expect(received[0], isA<ModuleSessionStarted>());
        expect(received[1], isA<ModuleSessionEnded>());

        f.channel.dispose();
      },
    );
  });
}
