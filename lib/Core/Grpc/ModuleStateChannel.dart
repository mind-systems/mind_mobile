import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:mind/Logger.dart';

import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Core/Grpc/ConnectionLifecycle.dart';
import 'package:mind/Core/Grpc/GrpcConnectionManager.dart';
import 'package:mind/Core/Grpc/GrpcConnectionState.dart';
import 'package:mind/Core/Grpc/ModuleSession.dart';
import 'package:mind/Core/Grpc/ModuleState.dart';
import 'package:mind/Core/Grpc/ModuleStateEvent.dart';
import 'package:mind/Core/Grpc/SessionRegistry.dart';
import 'package:mind/Core/Grpc/generated/module_state.pbgrpc.dart' as proto;
import 'package:mind/User/Models/AuthState.dart';

/// A start attempt awaiting confirmation, tracked per `activity_type`.
///
/// Holds the exact fields needed to re-send the *same* `ActivityStartCmd`
/// (dup-safe, same `client_activity_id`) on a confirm-timeout retry —
/// `attempts` bounds the retry budget (note 19 §Pinned constants: 3 total
/// attempts) and `timer` is the live confirm-timeout/retry `Timer`, owned
/// exclusively by `ModuleStateChannel`.
class _PendingStart {
  final ActivityType type;
  final String? refId;
  final int? clientTimestampMs;
  final String? clientActivityId;
  int attempts = 0;
  Timer? timer;

  _PendingStart({
    required this.type,
    this.refId,
    this.clientTimestampMs,
    this.clientActivityId,
  });
}

class ModuleStateChannel {
  final proto.ModuleStateServiceClient _moduleStateService;
  final GrpcConnectionManager _connectionManager;

  // ── State and events ──────────────────────────────────────────────────────

  final _state = BehaviorSubject<ModuleState>.seeded(ModuleState.initial());
  final _events = PublishSubject<ModuleStateEvent>();

  Stream<ModuleState> get state => _state.stream;
  Stream<ModuleStateEvent> get events => _events.stream;
  ModuleState get currentState => _state.value;

  // ── Session registry (root + N children) ────────────────────────────────

  final SessionRegistry _registry = SessionRegistry();

  String? get rootId => _registry.rootId;
  ModuleSession? childOfType(ActivityType type) => _registry.childOfType(type);
  Stream<String?> get rootIdChanges => _registry.rootIdChanges;
  Stream<void> get registryChanges => _registry.changes;

  // ── Pending guards ────────────────────────────────────────────────────────

  /// One in-flight, unconfirmed start per `activity_type` — replaces the
  /// single shared `_isPendingStart` bool (note 19) so a live child of one
  /// type never suppresses a fresh start of another type. Cleared by the
  /// confirming ACTIVE/RESUMED frame for that type, by give-up after the
  /// retry budget is spent, or by a whole-tree reset.
  final Map<ActivityType, _PendingStart> _pendingStarts = {};

  bool _isPendingPause = false;

  // ── Reconcile-by-arrival (armed on every `_openSessionStream`) ───────────

  /// The settling window's timer — cancelled on the next reopen and in
  /// `dispose()` so a pending `Timer` never survives its owning stream.
  Timer? _reconcileTimer;

  /// Real child arrivals recorded on the current settling window, or `null`
  /// when no window is armed. Only ids present here survive the sweep at
  /// window-close; a snapshotted child id absent from this set is evicted.
  Set<String>? _arrivedChildIds;

  /// True only while a settling window opened by a *reconnect* (never the
  /// first connect) is armed — gates `start()`'s defer-vs-send choice. Set
  /// at `_openSessionStream` time, cleared when the window's reconcile timer
  /// fires (or on a whole-tree reset/dispose).
  bool _settlingActive = false;

  /// Starts tapped while `_settlingActive` — held (never sent) until the
  /// settling window closes, so reconcile can resolve adopt-vs-new first.
  /// Resolved by `_resolveSettling()`: adopted (discarded) if a same-type
  /// child arrived, else released as a first-class pending via `_beginStart`.
  final Map<ActivityType, _PendingStart> _deferredStarts = {};

  // ── Close classification (per-stream transient) ──────────────────────────

  /// Set when a `session_error{code:'CONNECTION_SUPERSEDED'}` frame is seen
  /// on the current stream; read by `onDone` to classify the close as a
  /// yield rather than a bare drop. Reset to `false` whenever the FSM enters
  /// `opening` — a transition guard, not a cross-handler latch.
  bool _supersededOnThisStream = false;

  // ── Connection lifecycle FSM ─────────────────────────────────────────────

  ConnectionLifecycle _lifecycle = ConnectionLifecycle.disconnected;

  /// Sole mutation point for `_lifecycle`. Logs the transition then assigns —
  /// no stream/socket side effects here; callers still perform those
  /// themselves around the call to `_transition`.
  void _transition(ConnectionLifecycle to) {
    logPrint('[ModuleStateChannel] lifecycle: $_lifecycle → $to');
    _lifecycle = to;
  }

  @visibleForTesting
  ConnectionLifecycle get lifecycle => _lifecycle;

  // ── Stream handles ────────────────────────────────────────────────────────

  StreamSubscription<proto.StateResponse>? _sessionSub;
  StreamController<proto.StateRequest>? _sessionSink;

  bool get isConnected => _sessionSub != null;

  /// Fires whenever the session stream sink has just been (re)opened — a
  /// deterministic "sink now exists" trigger for adapters (e.g.
  /// `RootStateChannel`) that need to send on connect and every reconnect.
  final _sessionStreamOpened = PublishSubject<void>();

  Stream<void> get sessionStreamOpened => _sessionStreamOpened.stream;

  // ── Subscriptions ─────────────────────────────────────────────────────────

  late final StreamSubscription<GrpcConnectionState> _connectionSub;
  late final StreamSubscription<AuthState> _authSub;

  // ── Constructor ───────────────────────────────────────────────────────────

  ModuleStateChannel({
    required proto.ModuleStateServiceClient moduleStateService,
    required GrpcConnectionManager connectionManager,
    required Stream<AuthState> authStream,
  })  : _moduleStateService = moduleStateService,
        _connectionManager = connectionManager {
    _connectionSub = connectionManager.connectionState.listen((state) {
      switch (state) {
        case GrpcConnectionState.connected:
          // A yielded session must not re-take on a connection-manager
          // reopen (connectivity / app-resume / auth) — only takeOverHere()
          // may leave `yielded`.
          if (_lifecycle == ConnectionLifecycle.yielded) break;
          _openSessionStream();
        case GrpcConnectionState.disconnected:
          _closeSessionStream();
          _transition(ConnectionLifecycle.reconnecting);
        case GrpcConnectionState.connecting:
          break;
      }
    });
    _authSub = authStream.listen((auth) {
      if (auth is GuestState) _reset();
    });
  }

  // ── Session stream management ─────────────────────────────────────────────

  void _openSessionStream() {
    // Read root.id before any reconcile step drops the pre-reconnect root
    // (note 20 Task 7), so the pre-reconnect root.id still reaches the
    // header. Never a child id (note 20 — "send root.id only when known").
    final rootId = _registry.rootId;
    // Settling applies only to a reconnect open — never the first connect
    // (entered from `disconnected`) — so first-connect starts reach the
    // wire immediately (INV-8/SC-2). Captured before `_transition` below
    // reassigns `_lifecycle`; a reconnect enters from `reconnecting`, a
    // takeover from `yielded`.
    final isReconnectOpen = _lifecycle != ConnectionLifecycle.disconnected;
    _supersededOnThisStream = false;
    _transition(ConnectionLifecycle.opening);

    // Reconcile-by-arrival: snapshot the currently-cached child ids, drop the
    // pre-reconnect root entry immediately (rootId is null until a fresh
    // ROOT frame lands), and arm a 3s settling window. Every real child
    // arrival is recorded into `_arrivedChildIds` by `_upsertRegistryEntry`;
    // whatever snapshotted id never re-arrives is evicted when the window
    // closes. Armed on every open, including the first connect, where the
    // snapshot is empty and the sweep is a no-op.
    _reconcileTimer?.cancel();
    final snapshotChildIds = _registry.childIds;
    if (rootId != null) _registry.removeById(rootId);
    _arrivedChildIds = <String>{};
    _settlingActive = isReconnectOpen;
    if (isReconnectOpen) {
      // Double-fire guard: for the window's duration, settling-window
      // resolution owns carried-pending starts exclusively — cancel each
      // one's own confirm timer so a re-armed offline timer cannot also fire
      // inside the 3s window. `_resolveSettling()` re-arms (via `_sendStart`)
      // whichever pendings it re-sends when the window closes.
      for (final p in _pendingStarts.values) {
        p.timer?.cancel();
        p.timer = null;
      }
    }
    _reconcileTimer = Timer(const Duration(seconds: 3), () {
      for (final id in snapshotChildIds) {
        if (!_arrivedChildIds!.contains(id)) {
          _registry.removeById(id);
        }
      }
      _arrivedChildIds = null;
      _reconcileTimer = null;
      if (isReconnectOpen) _resolveSettling();
      _settlingActive = false;
    });

    _sessionSink = StreamController<proto.StateRequest>();
    final options = (rootId != null && rootId.isNotEmpty)
        ? CallOptions(metadata: {'module-session-id': rootId})
        : null;
    final response = _moduleStateService.trackActivity(_sessionSink!.stream, options: options);
    _sessionSub = response.listen(
      (proto.StateResponse r) {
        if (_lifecycle == ConnectionLifecycle.opening) {
          _transition(ConnectionLifecycle.active);
          _connectionManager.confirmConnected();
        }
        switch (r.whichEvent()) {
          case proto.StateResponse_Event.sessionState:
            final event = r.sessionState;
            if (event.status == proto.ActivityStatus.DISCONNECTED) return;
            _processProtoEvent(event);
          case proto.StateResponse_Event.sessionError:
            logPrint('[ModuleStateChannel] session error: ${r.sessionError.code} — ${r.sessionError.message}');
            if (r.sessionError.code == 'no_active_session') {
              _state.add(ModuleState.initial());
              _registry.clear();
            } else if (r.sessionError.code == 'CONNECTION_SUPERSEDED') {
              // Do not reset state here — the close that follows drives the
              // transition (see onDone below).
              _supersededOnThisStream = true;
            }
          case proto.StateResponse_Event.notSet:
            break;
        }
      },
      onError: (Object e) {
        logPrint('[ModuleStateChannel] session stream error: $e');
        _closeSessionStream();
        _connectionManager.disconnect();
        _connectionManager.scheduleReconnect();
        _transition(ConnectionLifecycle.reconnecting);
      },
      onDone: () {
        logPrint('[ModuleStateChannel] session stream done');
        _closeSessionStream();
        if (_supersededOnThisStream) {
          _transition(ConnectionLifecycle.yielded);
          _resetWholeTree();
          _events.add(SessionTerminated(SessionTerminationReason.movedToAnotherDevice));
        } else {
          _connectionManager.disconnect();
          _connectionManager.scheduleReconnect();
          _transition(ConnectionLifecycle.reconnecting);
        }
      },
    );
    _sessionStreamOpened.add(null);
  }

  void _closeSessionStream() {
    _sessionSub?.cancel();
    _sessionSub = null;
    _sessionSink?.close();
    _sessionSink = null;
  }

  // ── Proto → typed mapping ─────────────────────────────────────────────────

  void _processProtoEvent(proto.StateEvent event) {
    final activityType = _mapActivityTypeFromProto(event.activityType);
    if (activityType == ActivityType.root) {
      _handleRootFrame(event);
      return;
    }
    final status = event.status;
    if (status == proto.ActivityStatus.RESUMED) {
      final isPaused = event.isPaused;
      final moduleSessionId = event.moduleSessionId;
      _clearPendingStart(activityType);
      _isPendingPause = false;
      _state.add(ModuleState(moduleSessionId: moduleSessionId, status: ModuleStateStatus.active, isPaused: isPaused));
      _events.add(ModuleSessionResumed(moduleSessionId: moduleSessionId));
      _upsertRegistryEntry(event);
    } else if (status == proto.ActivityStatus.ACTIVE) {
      final isPaused = event.isPaused;
      final moduleSessionId = event.moduleSessionId;
      final wasPaused = currentState.isPaused;
      final isNew = currentState.status != ModuleStateStatus.active;
      _clearPendingStart(activityType);
      _isPendingPause = false;
      _state.add(ModuleState(moduleSessionId: moduleSessionId, status: ModuleStateStatus.active, isPaused: isPaused));
      if (isNew) {
        _events.add(ModuleSessionStarted(moduleSessionId: moduleSessionId));
      } else if (!wasPaused && isPaused) {
        _events.add(ModuleSessionPaused());
      } else if (wasPaused && !isPaused) {
        _events.add(ModuleSessionUnpaused());
      }
      _upsertRegistryEntry(event);
    } else if (status == proto.ActivityStatus.COMPLETED || status == proto.ActivityStatus.INTERRUPTED) {
      _state.add(ModuleState.initial());
      _events.add(ModuleSessionEnded());
      _registry.removeTerminal(event.moduleSessionId);
    } else if (status == proto.ActivityStatus.ABANDONED) {
      _state.add(ModuleState.initial());
      _events.add(ModuleSessionAbandoned());
      _registry.removeTerminal(event.moduleSessionId);
    } else if (status == proto.ActivityStatus.ACTIVITY_STATUS_UNSPECIFIED) {
      // Whole-tree reset: an UNSPECIFIED frame can still carry a
      // moduleSessionId, so an upsert-skip alone would leave stale entries —
      // _resetWholeTree() is what matches the single-state reset and also
      // clears the pending guards.
      _resetWholeTree();
      _events.add(SessionTerminated(SessionTerminationReason.abandoned));
    } else {
      logPrint('[ModuleStateChannel] unhandled status: $status');
    }
  }

  /// Drives the session registry from a `RESUMED`/`ACTIVE` frame.
  ///
  /// Load-bearing assumption: every `ACTIVE`/`RESUMED` state frame from the
  /// server carries a populated `activity_type` (guaranteed by note 13's
  /// contract). Nothing else backfills the registry in this milestone
  /// (reconnect rebuild is note 20) — if the server omitted `activity_type`
  /// on a live frame, the single-state would go active while the registry
  /// stayed silently empty (`rootId == null` for a live root), the exact
  /// silent failure this milestone prevents.
  void _upsertRegistryEntry(proto.StateEvent event) {
    final activityType = _mapActivityTypeFromProto(event.activityType);
    if (activityType == null) return;
    // Reconcile-by-arrival: record every real child arrival while a settling
    // window is armed, so the sweep at window-close knows this id is alive.
    if (_arrivedChildIds != null && activityType != ActivityType.root) {
      _arrivedChildIds!.add(event.moduleSessionId);
    }
    _registry.upsert(ModuleSession(
      id: event.moduleSessionId,
      activityType: activityType,
      status: ModuleStateStatus.active,
      isPaused: event.isPaused,
    ));
  }

  /// Routes a `ROOT` frame to the registry only — the root never drives the
  /// legacy single-state and has no end/stop/pause/resume path.
  ///
  /// `COMPLETED`/`INTERRUPTED`/`ABANDONED` are handled defensively: the root
  /// should never end, but if the server ever sent a terminal frame for it,
  /// this is a whole-tree termination (note 26 groups `rootDeath` with
  /// `abandoned`/`movedToAnotherDevice`) — the reset must land before any
  /// freshly-minted root repopulates the registry. Any other status is
  /// ignored.
  void _handleRootFrame(proto.StateEvent event) {
    final status = event.status;
    if (status == proto.ActivityStatus.ACTIVE || status == proto.ActivityStatus.RESUMED) {
      _upsertRegistryEntry(event);
    } else if (status == proto.ActivityStatus.COMPLETED ||
        status == proto.ActivityStatus.INTERRUPTED ||
        status == proto.ActivityStatus.ABANDONED) {
      _resetWholeTree();
      _events.add(SessionTerminated(SessionTerminationReason.rootDeath));
    }
  }

  /// The one caller allowed to leave `yielded` — the `yielded → opening`
  /// transition. No-op unless currently `yielded`. Clears the close-latch
  /// and reopens a fresh session stream directly (bypassing the
  /// connected-handler guard above), which re-fires `sessionStreamOpened` so
  /// `RootStateChannel` re-mints a clean root with no children.
  void takeOverHere() {
    if (_lifecycle != ConnectionLifecycle.yielded) return;
    _supersededOnThisStream = false;
    _openSessionStream();
  }

  // ── Public session commands ───────────────────────────────────────────────

  void start({required ActivityType type, String? refId, int? clientTimestampMs, String? clientActivityId}) {
    // (1) Adopt-existing: an already-live child of this type means the
    // RESUMED/ACTIVE frame already populated the registry + single-state —
    // sending a fresh start would duplicate it. Checked first so adopt wins
    // even while a settling window is active (see the settling check below).
    if (_registry.childOfType(type) != null) return;
    // (2) Per-type pending guard: a start of this exact type is already
    // in flight (own confirm-timeout + retry lifecycle) — never the shared
    // single-state guard this replaces, which wrongly let a live child of a
    // *different* type suppress a fresh start of an un-started type.
    if (_pendingStarts.containsKey(type)) return;
    final pendingStart = _PendingStart(
      type: type,
      refId: refId,
      clientTimestampMs: clientTimestampMs,
      clientActivityId: clientActivityId,
    );
    // (3) Settling defer: within a reconnect's settling window, hold the
    // start until reconcile has a chance to resolve adopt-vs-new — sending
    // now could race a same-type RESUMED frame that is about to arrive and
    // duplicate it. Adopt (step 1) already wins over this.
    if (_settlingActive) {
      _deferredStarts[type] = pendingStart;
      return;
    }
    _beginStart(pendingStart);
  }

  /// Opens the root activity. Unlike [start], this bypasses the child
  /// single-session guard and never touches `_isPendingStart` — the root is
  /// idempotent server-side (same `root.id` on every call for a given user)
  /// and must be re-sent on every reconnect, including while a child is
  /// active. Root has no `refId` and no `clientTimestampMs`.
  void startRoot({String? clientActivityId}) {
    _sendSessionRequest(proto.StateRequest(
      activityStart: proto.ActivityStartCmd(
        activityType: proto.ActivityType.ROOT,
        clientActivityId: clientActivityId,
      ),
    ));
  }

  void pause({String? sessionId}) {
    if (currentState.status != ModuleStateStatus.active || currentState.isPaused || _isPendingPause) return;
    _isPendingPause = true;
    _sendSessionRequest(proto.StateRequest(activityPause: proto.ActivityPauseCmd(sessionId: sessionId)));
  }

  void unpause({String? sessionId}) {
    if (!currentState.isPaused) return;
    _isPendingPause = false;
    _sendSessionRequest(proto.StateRequest(activityResume: proto.ActivityResumeCmd(sessionId: sessionId)));
  }

  void end({int? clientTimestampMs, String? sessionId}) {
    if (currentState.status == ModuleStateStatus.idle) return;
    _sendSessionRequest(proto.StateRequest(
      activityEnd: proto.ActivityEndCmd(
        clientTimestampMs: clientTimestampMs != null ? Int64(clientTimestampMs) : null,
        sessionId: sessionId,
      ),
    ));
  }

  void stop({String? sessionId}) {
    if (currentState.status == ModuleStateStatus.idle) return;
    _sendSessionRequest(proto.StateRequest(activityStop: proto.ActivityStopCmd(sessionId: sessionId)));
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// The single entry that makes a start *pending* — registers [p] in
  /// `_pendingStarts[p.type]` (replacing any prior entry for that type,
  /// cancelling its timer) then sends it. Used by `start()`'s initial send
  /// and by the settling-window's deferred-start release, so a released
  /// deferred start gets the same confirm-timeout + bounded retry lifecycle
  /// as any other start.
  void _beginStart(_PendingStart p) {
    _pendingStarts[p.type]?.timer?.cancel();
    _pendingStarts[p.type] = p;
    _sendStart(p);
  }

  /// Sends the `ActivityStartCmd` built from [p]'s stored fields — never
  /// regenerates the token, so a retry reuses the exact same
  /// `client_activity_id`. Does not itself register the pending in
  /// `_pendingStarts`; by the time a retry calls this, the pending already
  /// exists. Arms the 5s confirm-timeout that drives [_onConfirmTimeout] —
  /// cancelling any prior timer first, so a retry never leaves two timers
  /// racing for the same pending start.
  void _sendStart(_PendingStart p) {
    p.attempts++;
    _sendSessionRequest(proto.StateRequest(
      activityStart: proto.ActivityStartCmd(
        activityType: _mapActivityType(p.type),
        refId: p.refId,
        clientTimestampMs: p.clientTimestampMs != null ? Int64(p.clientTimestampMs!) : null,
        clientActivityId: p.clientActivityId,
      ),
    ));
    p.timer?.cancel();
    p.timer = Timer(const Duration(seconds: 5), () => _onConfirmTimeout(p.type));
  }

  /// Fires 5s after a start attempt with no confirming ACTIVE/RESUMED frame
  /// for [type]. A no-op if the pending was already cleared by a confirming
  /// frame (INV-8 post-confirm). Otherwise either retries with the same
  /// token (budget permitting) or gives up and emits [SessionStartFailed] —
  /// note 19 §Pinned constants: 3 total attempts (initial + 2 retries).
  void _onConfirmTimeout(ActivityType type) {
    final p = _pendingStarts[type];
    if (p == null) return;
    if (p.attempts >= 3) {
      _giveUp(type);
      return;
    }
    if (isConnected) {
      _sendStart(p);
    } else {
      // Transport is down — do not consume a retry. Re-arm and wait; the
      // reconnect settling window (Task 4) owns resolution once the
      // transport comes back.
      p.timer = Timer(const Duration(seconds: 5), () => _onConfirmTimeout(type));
    }
  }

  /// Retry budget spent for [type] — removes its pending (cancelling the
  /// timer) and emits [SessionStartFailed]. Shared by `_onConfirmTimeout`
  /// and `_resolveSettling`'s carried-pending re-send so both retry paths
  /// enforce the same give-up (note 19 §Pinned constants: 3 total attempts).
  void _giveUp(ActivityType type) {
    _pendingStarts.remove(type)?.timer?.cancel();
    _events.add(SessionStartFailed(type));
  }

  /// Resolves both settling-window maps when the window closes (called from
  /// the reconcile timer callback, reconnect opens only). Deferred starts
  /// either adopt a now-live same-type child (discarded) or are released as
  /// first-class pendings via `_beginStart` (own confirm-timeout + bounded
  /// retry). Carried pendings — sends already on the wire before the window
  /// armed — are re-sent via `_sendStart` unless a confirming frame already
  /// cleared them from `_pendingStarts` during the window (`_clearPendingStart`),
  /// or the retry budget is already spent, in which case this gives up via
  /// `_giveUp` instead — without that check a carried pending could be
  /// re-sent once per reconnect forever, overshooting INV-12's 3-attempt
  /// ceiling and, past the server's idempotency window on a flapping
  /// connection, risking a duplicate child.
  /// `carriedTypes` is snapshotted before releasing deferred starts so a
  /// freshly-released deferred start is never re-sent a second time in the
  /// same pass.
  ///
  /// Both send paths are gated on `isConnected` — mirroring
  /// `_onConfirmTimeout`'s down-branch asymmetry (hold, don't consume a
  /// retry, when the sink is gone). Without this guard, a stream drop
  /// landing inside the settling window would let a resolved send hit the
  /// null-sink guard in `_sendSessionRequest`, burning an attempt on a
  /// request that never reached the wire; the next reconnect's settling
  /// window resolves whatever this pass held back.
  void _resolveSettling() {
    final deferred = Map<ActivityType, _PendingStart>.from(_deferredStarts);
    _deferredStarts.clear();
    final carriedTypes = _pendingStarts.keys.toList();
    for (final p in deferred.values) {
      if (_registry.childOfType(p.type) != null) continue;
      if (!isConnected) {
        _deferredStarts[p.type] = p;
        continue;
      }
      _beginStart(p);
    }
    for (final type in carriedTypes) {
      final p = _pendingStarts[type];
      if (p == null || !isConnected) continue;
      if (p.attempts >= 3) {
        _giveUp(type);
        continue;
      }
      _sendStart(p);
    }
  }

  /// Clears the pending start for [type] (cancelling its timer), if any.
  /// A no-op when [type] is `null` (frame carried no recognizable
  /// `activity_type`) or when nothing is pending for it — a confirming
  /// frame for an already-cleared type is not an error.
  void _clearPendingStart(ActivityType? type) {
    if (type == null) return;
    _pendingStarts.remove(type)?.timer?.cancel();
  }

  void _sendSessionRequest(proto.StateRequest request) {
    if (_sessionSink == null) {
      logPrint('[ModuleStateChannel] not connected, dropping request');
      return;
    }
    _sessionSink!.add(request);
  }

  proto.ActivityType _mapActivityType(ActivityType type) {
    switch (type) {
      case ActivityType.breath:
        return proto.ActivityType.BREATH;
      case ActivityType.meditation:
        return proto.ActivityType.MEDITATION;
      case ActivityType.root:
        return proto.ActivityType.ROOT;
    }
  }

  ActivityType? _mapActivityTypeFromProto(proto.ActivityType type) {
    switch (type) {
      case proto.ActivityType.BREATH:
        return ActivityType.breath;
      case proto.ActivityType.MEDITATION:
        return ActivityType.meditation;
      case proto.ActivityType.ROOT:
        return ActivityType.root;
      default:
        logPrint('[ModuleStateChannel] dropping unknown activity type: $type');
        return null;
    }
  }

  /// Whole-tree reset shared by every whole-tree termination site (SUPERSEDED
  /// yield, `{abandoned}` UNSPECIFIED, root-level terminal): clears the
  /// registry, resets single-state to idle, and clears both pending guards.
  /// Idempotent — a second reset lands cleanly. Callers emit their own
  /// `SessionTerminated(reason)` after calling this.
  void _resetWholeTree() {
    _registry.clear();
    _state.add(ModuleState.initial());
    for (final p in _pendingStarts.values) {
      p.timer?.cancel();
    }
    _pendingStarts.clear();
    _deferredStarts.clear();
    _settlingActive = false;
    _isPendingPause = false;
  }

  void _reset() {
    _resetWholeTree();
    _supersededOnThisStream = false;
    _transition(ConnectionLifecycle.disconnected);
  }

  // ── Disposal ──────────────────────────────────────────────────────────────

  void dispose() {
    _connectionSub.cancel();
    _authSub.cancel();
    _closeSessionStream();
    _reconcileTimer?.cancel();
    for (final p in _pendingStarts.values) {
      p.timer?.cancel();
    }
    _deferredStarts.clear();
    _state.close();
    _events.close();
    _sessionStreamOpened.close();
    _registry.dispose();
  }
}
