// ──────────────────────────────────────────────────────────────────────────────
// Reconnect / eviction / start-race concurrency contract — invariant catalogue
// ──────────────────────────────────────────────────────────────────────────────
//
// This is the durable "write them down" artefact for Phase 64's shared
// reconnect/reconcile surface (plan 22). Note 20 greens the
// eviction/close-classification and reconnect/reconcile invariants; note 19
// greens the start-race invariants. Red scenarios are driven by the breath +
// meditation adapters concurrently (note 24 §Red scenarios).
//
// Each invariant/scenario carries a one-line RED now / GREEN under
// note 19|20 / GREEN-now guard annotation. The annotation here mirrors the
// annotation actually attached to its test(s) in
// reconnect_eviction_contract_test.dart / start_race_contract_test.dart —
// if a test's empirically-observed status differs from what this catalogue
// predicted, the test file's annotation is authoritative and this catalogue
// was updated to match.
//
// ── Eviction / close-classification (note 20) ──────────────────────────────
//
// INV-1  Yield iff `session_error{code:'CONNECTION_SUPERSEDED'}` was seen on
//        this stream before close. Bare graceful `onDone` (no code) →
//        reconnect + reconcile. `onError` → reconnect.
//          SC-4 (SUPERSEDED then close): RED now.
//          SC-5 (bare close): GREEN-now guard.
//          onError (transport drop): GREEN-now guard.
// INV-2  The yield latch gates stream reopen — a connection-manager reopen
//        (connectivity / app-resume / auth) while yielded must NOT re-take
//        the session.
//          SC-6 (app-resume while yielded): RED now.
// INV-3  `takeOverHere()` clears the latch and reopens; the takeover
//        receives a clean root frame, no child frames.
//          skip: (needs note 20's not-yet-existing `takeOverHere()` seam).
//
// ── Reconnect / reconcile (note 20) ─────────────────────────────────────────
//
// INV-4  `rootId` is sourced from the RootStateChannel ROOT re-open, never
//        from the reconnect fan-out (which carries no root frame). A stale
//        pre-reconnect `rootId` must not silently persist across the
//        reconnect until that ROOT re-open lands.
//          RED now.
// INV-5  Registry rebuilt by reconcile-by-arrival from per-child RESUMED
//        frames; a cached child with no arriving frame within the settling
//        window is treated as gone.
//          SC-3: RED now.
// INV-6  Global-reset-then-adopt ordering: an `{abandoned}` reset is applied
//        before a subsequently-minted root repopulates the registry
//        (idempotent).
//          RED now.
// INV-7  Resumed children adopt their real `is_paused` from the RESUMED
//        frame.
//          GREEN-now guard.
//
// ── Start-race (note 19) ────────────────────────────────────────────────────
//
// INV-8  Retry a pending start only while unconfirmed → no duplicate.
//          SC-2: RED now.
//          Post-confirm (no retry once confirmed): GREEN-now guard.
//          SC-1 (two concurrent starts, both un-started): RED now.
// INV-9  Retry reuses the same `client_activity_id`; never regenerate.
//          SC-2: RED now (same test as INV-8/SC-2).
// INV-10 Before sending a fresh start, adopt an already-live child of that
//        type (`childOfType`) — and a live child of a *different* type must
//        NOT suppress a start of an un-started type.
//          Same-type adopt (SC-7): GREEN-now guard.
//          Cross-type suppression: RED now.
// INV-11 Within the settling window after reconnect, defer the
//        adopt-vs-new decision until reconcile completes.
//          Deferred-then-adopted case: RED now.
//          Deferred-then-released case (no RESUMED arrives): RED now.
// INV-12 Timings: confirm timeout 5s, max 2 retries (3 attempts total),
//        settling window 3s.
//          GREEN-now guard — no retry mechanism exists yet today, so "no
//          further activityStart after retries exhaust" already holds
//          vacuously; this pins the ceiling so note 19's retry loop cannot
//          overshoot it once the retry loop exists.
//
// ── Red scenarios (note 24 §Red scenarios) ──────────────────────────────────
// Driven by breath + meditation concurrently via `wireConcurrent`.
//
// SC-1  two concurrent starts (both un-started)               — RED now
// SC-2  start-then-drop-before-ACTIVE                          — RED now
// SC-3  reconnect-with-both-live (reconcile both)               — RED now
// SC-4  SUPERSEDED mid-session                                  — RED now
// SC-5  bare close mid-session                                  — GREEN-now guard
// SC-6  app-resume while yielded                                — RED now
// SC-7  app-restart mid-start (adopt on resume)
//          same-type adopt: GREEN-now guard
//          cross-type suppression: RED now
library;

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:grpc/grpc.dart' as grpc;

import 'package:breath_module/breath_module.dart'
    show BreathSessionState, BreathLifecycle, BreathPhase, SessionLoadState;
import 'package:meditation_module/meditation_module.dart'
    show MeditationSessionState, MeditationSessionStatus;

import 'package:mind/BreathModule/Core/BreathModuleInstructionStream.dart';
import 'package:mind/BreathModule/Core/BreathModuleStateChannel.dart';
import 'package:mind/Core/Grpc/GrpcConnectionManager.dart';
import 'package:mind/Core/Grpc/GrpcConnectionState.dart';
import 'package:mind/Core/Grpc/ModuleStateChannel.dart';
import 'package:mind/Core/Grpc/generated/module_state.pb.dart' as proto;
import 'package:mind/Core/Grpc/generated/module_state.pbgrpc.dart' as protosvc;
import 'package:mind/MeditationModule/Core/MeditationModuleStateChannel.dart';
import 'package:mind/User/Models/AuthState.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Fakes (copied in the style of module_state_channel_test.dart:18-91 — not
// imported from other test files, so this support file stays self-contained)
// ──────────────────────────────────────────────────────────────────────────────

/// Wraps a plain Stream as a ClientCall so ResponseStream can be constructed.
class FakeClientCall
    implements grpc.ClientCall<proto.StateRequest, proto.StateResponse> {
  final Stream<proto.StateResponse> _responses;
  FakeClientCall(this._responses);

  @override
  Stream<proto.StateResponse> get response => _responses;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// One recorded call to trackActivity — captures the `CallOptions` (to read
/// the `module-session-id` header), every sent `StateRequest` (to read
/// `client_activity_id` / `session_id` off the wire), and exposes a
/// `responseCtrl` to inject `StateResponse` frames from the server.
class TrackActivityCall {
  final grpc.CallOptions? options;
  final StreamController<proto.StateResponse> responseCtrl =
      StreamController<proto.StateResponse>();
  final List<proto.StateRequest> sentRequests = [];

  TrackActivityCall(this.options);
}

/// Fake `ModuleStateServiceClient` — records every `trackActivity`
/// invocation (reopen count), captures sent `StateRequest`s per call, and
/// lets the test inject `StateResponse` frames per call.
class FakeModuleStateServiceClient implements protosvc.ModuleStateServiceClient {
  final List<TrackActivityCall> calls = [];

  TrackActivityCall? get latestCall => calls.isEmpty ? null : calls.last;

  @override
  grpc.ResponseStream<proto.StateResponse> trackActivity(
    Stream<proto.StateRequest> request, {
    grpc.CallOptions? options,
  }) {
    final call = TrackActivityCall(options);
    calls.add(call);
    request.listen((req) => call.sentRequests.add(req));
    return grpc.ResponseStream<proto.StateResponse>(
        FakeClientCall(call.responseCtrl.stream));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake `GrpcConnectionManager` — backs `connectionState` with a broadcast
/// controller, tracks method calls, and exposes `pushConnected`/
/// `pushDisconnected` helpers to simulate app-resume / connectivity /
/// reconnect from the test.
class FakeConnectionManager implements GrpcConnectionManager {
  final connectionStateCtrl = StreamController<GrpcConnectionState>.broadcast();

  int confirmConnectedCount = 0;
  int disconnectCount = 0;
  int scheduleReconnectCount = 0;

  @override
  Stream<GrpcConnectionState> get connectionState => connectionStateCtrl.stream;

  @override
  void confirmConnected() => confirmConnectedCount++;

  @override
  void disconnect() => disconnectCount++;

  @override
  void scheduleReconnect() => scheduleReconnectCount++;

  void pushConnected() => connectionStateCtrl.add(GrpcConnectionState.connected);

  void pushDisconnected() =>
      connectionStateCtrl.add(GrpcConnectionState.disconnected);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake `BreathModuleInstructionStream` — records every `sendSample` call.
class FakeBreathInstructionStream implements BreathModuleInstructionStream {
  final List<(String, String, int, int, int)> sendSampleCalls = [];

  @override
  void sendSample(String sessionId, String phase, int tickCount, int offsetMs, int timestampMs) =>
      sendSampleCalls.add((sessionId, phase, tickCount, offsetMs, timestampMs));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ──────────────────────────────────────────────────────────────────────────────
// Frame builders — proto StateResponse helpers
// ──────────────────────────────────────────────────────────────────────────────

/// A ROOT frame (ACTIVE by default, or RESUMED via [status]).
proto.StateResponse rootFrame(
  String id, {
  proto.ActivityStatus status = proto.ActivityStatus.ACTIVE,
}) =>
    proto.StateResponse(
      sessionState: proto.StateEvent(
        status: status,
        moduleSessionId: id,
        activityType: proto.ActivityType.ROOT,
      ),
    );

/// A child ACTIVE frame for [type] (BREATH or MEDITATION).
proto.StateResponse childActiveFrame(
  proto.ActivityType type,
  String id, {
  bool isPaused = false,
}) =>
    proto.StateResponse(
      sessionState: proto.StateEvent(
        status: proto.ActivityStatus.ACTIVE,
        moduleSessionId: id,
        activityType: type,
        isPaused: isPaused,
      ),
    );

/// A child RESUMED frame for [type] with an explicit [isPaused].
proto.StateResponse childResumedFrame(
  proto.ActivityType type,
  String id, {
  required bool isPaused,
}) =>
    proto.StateResponse(
      sessionState: proto.StateEvent(
        status: proto.ActivityStatus.RESUMED,
        moduleSessionId: id,
        activityType: type,
        isPaused: isPaused,
      ),
    );

/// A `session_error{code:'CONNECTION_SUPERSEDED'}` frame — precedes a close
/// to signal INV-1's yield condition.
proto.StateResponse supersededErrorFrame() => proto.StateResponse(
      sessionError: proto.StateErrorEvent(
        code: 'CONNECTION_SUPERSEDED',
        message: 'session superseded by another connection',
      ),
    );

/// An `{abandoned}` global reset frame (ACTIVITY_STATUS_UNSPECIFIED — the
/// existing wire shape ModuleStateChannel._processProtoEvent maps to a full
/// registry clear, ModuleStateChannel.dart:184-190).
proto.StateResponse globalResetFrame() => proto.StateResponse(
      sessionState: proto.StateEvent(
        status: proto.ActivityStatus.ACTIVITY_STATUS_UNSPECIFIED,
      ),
    );

// ──────────────────────────────────────────────────────────────────────────────
// Session-state builders — breath / meditation
// ──────────────────────────────────────────────────────────────────────────────

/// A ready, running `BreathSessionState` — driving this on the breath
/// adapter's `stateStream` triggers `channel.start(type: breath, ...)` on
/// the first emission (BreathModuleStateChannel._handleLifecycle).
BreathSessionState runningBreathState({
  BreathPhase phase = BreathPhase.inhale,
  int exerciseIndex = 0,
  int currentPhaseTotalDuration = 1,
}) =>
    BreathSessionState(
      loadState: SessionLoadState.ready,
      phase: phase,
      exerciseIndex: exerciseIndex,
      remainingTicks: 0,
      currentIntervalMs: 4000,
      currentPhaseTotalDuration: currentPhaseTotalDuration,
      lifecycle: BreathLifecycle.running,
    );

/// An active `MeditationSessionState` — driving this on the meditation
/// adapter's `stateStream` triggers `channel.start(type: meditation, ...)`
/// on the first emission (MeditationModuleStateChannel._onState).
MeditationSessionState activeMeditationState({String poseId = 'pose-1'}) =>
    MeditationSessionState(status: MeditationSessionStatus.active, poseId: poseId);

/// An idle `MeditationSessionState`.
MeditationSessionState idleMeditationState({String poseId = 'pose-1'}) =>
    MeditationSessionState(status: MeditationSessionStatus.idle, poseId: poseId);

// ──────────────────────────────────────────────────────────────────────────────
// wireConcurrent — real ModuleStateChannel + real breath/meditation adapters
// ──────────────────────────────────────────────────────────────────────────────

typedef ConcurrentFixture = ({
  ModuleStateChannel channel,
  BreathModuleStateChannel breathAdapter,
  MeditationModuleStateChannel meditationAdapter,
  StreamController<BreathSessionState> breathStateCtrl,
  StreamController<MeditationSessionState> meditationStateCtrl,
  FakeModuleStateServiceClient service,
  FakeConnectionManager connManager,
  StreamController<AuthState> authCtrl,
  FakeBreathInstructionStream breathInstructionStream,
});

/// Builds ONE real [ModuleStateChannel] on the fake service + fake
/// connection manager and wires BOTH a real [BreathModuleStateChannel] and a
/// real [MeditationModuleStateChannel] to it (each driven via its own state
/// `StreamController`) — so registry / pending / close-classification state
/// is real, not stubbed (m36).
///
/// Ordering pin: callers MUST push `GrpcConnectionState.connected` (via
/// [connectAndFlush]) and flush BEFORE driving either adapter's
/// `stateStream` into a running/active state — otherwise `channel.start` is
/// silently dropped by the null-sink guard (ModuleStateChannel.dart:292-298)
/// and "start reached the wire" assertions never fire.
ConcurrentFixture wireConcurrent({
  String breathSessionId = 'breath-sess-1',
  String meditationRefId = 'med-sess-1',
}) {
  final service = FakeModuleStateServiceClient();
  final connManager = FakeConnectionManager();
  final authCtrl = StreamController<AuthState>.broadcast();
  final channel = ModuleStateChannel(
    moduleStateService: service,
    connectionManager: connManager,
    authStream: authCtrl.stream,
  );

  final breathStateCtrl = StreamController<BreathSessionState>.broadcast();
  final meditationStateCtrl = StreamController<MeditationSessionState>.broadcast();
  final breathInstructionStream = FakeBreathInstructionStream();

  final breathAdapter = BreathModuleStateChannel(
    channel: channel,
    stateStream: breathStateCtrl.stream,
    instructionStream: breathInstructionStream,
    sessionId: breathSessionId,
  );
  final meditationAdapter = MeditationModuleStateChannel(
    channel: channel,
    stateStream: meditationStateCtrl.stream,
    refId: meditationRefId,
  );

  return (
    channel: channel,
    breathAdapter: breathAdapter,
    meditationAdapter: meditationAdapter,
    breathStateCtrl: breathStateCtrl,
    meditationStateCtrl: meditationStateCtrl,
    service: service,
    connManager: connManager,
    authCtrl: authCtrl,
    breathInstructionStream: breathInstructionStream,
  );
}

/// Pushes `connected` on the fixture's fake connection manager and flushes
/// microtasks so `ModuleStateChannel._openSessionStream` runs and the
/// session sink becomes non-null (see the ordering pin on [wireConcurrent]).
void connectAndFlush(ConcurrentFixture f, FakeAsync async) {
  f.connManager.pushConnected();
  async.flushMicrotasks();
}

/// Pushes `disconnected` on the fixture's fake connection manager and
/// flushes microtasks.
void disconnectAndFlush(ConcurrentFixture f, FakeAsync async) {
  f.connManager.pushDisconnected();
  async.flushMicrotasks();
}
