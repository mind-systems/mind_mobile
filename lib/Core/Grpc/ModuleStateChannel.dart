import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:mind/Logger.dart';

import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Core/Grpc/GrpcConnectionManager.dart';
import 'package:mind/Core/Grpc/GrpcConnectionState.dart';
import 'package:mind/Core/Grpc/ModuleState.dart';
import 'package:mind/Core/Grpc/ModuleStateEvent.dart';
import 'package:mind/Core/Grpc/generated/module_state.pbgrpc.dart' as proto;
import 'package:mind/User/Models/AuthState.dart';

class ModuleStateChannel {
  final proto.ModuleStateServiceClient _moduleStateService;
  final GrpcConnectionManager _connectionManager;

  // ── State and events ──────────────────────────────────────────────────────

  final _state = BehaviorSubject<ModuleState>.seeded(ModuleState.initial());
  final _events = PublishSubject<ModuleStateEvent>();

  Stream<ModuleState> get state => _state.stream;
  Stream<ModuleStateEvent> get events => _events.stream;
  ModuleState get currentState => _state.value;

  // ── Pending guards ────────────────────────────────────────────────────────

  bool _isPendingStart = false;
  bool _isPendingPause = false;
  bool _backoffConfirmed = false;

  // ── Stream handles ────────────────────────────────────────────────────────

  StreamSubscription<proto.StateResponse>? _sessionSub;
  StreamController<proto.StateRequest>? _sessionSink;

  bool get isConnected => _sessionSub != null;

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
          _openSessionStream();
        case GrpcConnectionState.disconnected:
          _closeSessionStream();
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
    _backoffConfirmed = false;
    _sessionSink = StreamController<proto.StateRequest>();
    final liveId = currentState.moduleSessionId;
    final options = (currentState.status == ModuleStateStatus.active &&
            liveId != null && liveId.isNotEmpty)
        ? CallOptions(metadata: {'module-session-id': liveId})
        : null;
    final response = _moduleStateService.trackActivity(_sessionSink!.stream, options: options);
    _sessionSub = response.listen(
      (proto.StateResponse r) {
        if (!_backoffConfirmed) {
          _backoffConfirmed = true;
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
      },
      onDone: () {
        logPrint('[ModuleStateChannel] session stream done');
        _closeSessionStream();
        _connectionManager.disconnect();
        _connectionManager.scheduleReconnect();
      },
    );
  }

  void _closeSessionStream() {
    _sessionSub?.cancel();
    _sessionSub = null;
    _sessionSink?.close();
    _sessionSink = null;
  }

  // ── Proto → typed mapping ─────────────────────────────────────────────────

  void _processProtoEvent(proto.StateEvent event) {
    final status = event.status;
    if (status == proto.ActivityStatus.RESUMED) {
      final isPaused = event.isPaused;
      final moduleSessionId = event.moduleSessionId;
      _isPendingStart = false;
      _isPendingPause = false;
      _state.add(ModuleState(moduleSessionId: moduleSessionId, status: ModuleStateStatus.active, isPaused: isPaused));
      _events.add(ModuleSessionResumed(moduleSessionId: moduleSessionId));
    } else if (status == proto.ActivityStatus.ACTIVE) {
      final isPaused = event.isPaused;
      final moduleSessionId = event.moduleSessionId;
      final wasPaused = currentState.isPaused;
      final isNew = currentState.status != ModuleStateStatus.active;
      _isPendingStart = false;
      _isPendingPause = false;
      _state.add(ModuleState(moduleSessionId: moduleSessionId, status: ModuleStateStatus.active, isPaused: isPaused));
      if (isNew) {
        _events.add(ModuleSessionStarted(moduleSessionId: moduleSessionId));
      } else if (!wasPaused && isPaused) {
        _events.add(ModuleSessionPaused());
      } else if (wasPaused && !isPaused) {
        _events.add(ModuleSessionUnpaused());
      }
    } else if (status == proto.ActivityStatus.COMPLETED || status == proto.ActivityStatus.INTERRUPTED) {
      _state.add(ModuleState.initial());
      _events.add(ModuleSessionEnded());
    } else if (status == proto.ActivityStatus.ABANDONED) {
      _state.add(ModuleState.initial());
      _events.add(ModuleSessionAbandoned());
    } else if (status == proto.ActivityStatus.ACTIVITY_STATUS_UNSPECIFIED) {
      _isPendingStart = false;
      _state.add(ModuleState.initial());
    } else {
      logPrint('[ModuleStateChannel] unhandled status: $status');
    }
  }

  // ── Public session commands ───────────────────────────────────────────────

  void start({required ActivityType type, String? refId, int? clientTimestampMs}) {
    if (currentState.status == ModuleStateStatus.active || _isPendingStart) return;
    _isPendingStart = true;
    _sendSessionRequest(proto.StateRequest(
      activityStart: proto.ActivityStartCmd(
        activityType: _mapActivityType(type),
        refId: refId ?? '',
        clientTimestampMs: clientTimestampMs != null ? Int64(clientTimestampMs) : null,
      ),
    ));
  }

  void pause() {
    if (currentState.status != ModuleStateStatus.active || currentState.isPaused || _isPendingPause) return;
    _isPendingPause = true;
    _sendSessionRequest(proto.StateRequest(activityPause: proto.ActivityPauseCmd()));
  }

  void unpause() {
    if (!currentState.isPaused) return;
    _isPendingPause = false;
    _sendSessionRequest(proto.StateRequest(activityResume: proto.ActivityResumeCmd()));
  }

  void end({int? clientTimestampMs}) {
    if (currentState.status == ModuleStateStatus.idle) return;
    _sendSessionRequest(proto.StateRequest(
      activityEnd: proto.ActivityEndCmd(
        clientTimestampMs: clientTimestampMs != null ? Int64(clientTimestampMs) : null,
      ),
    ));
  }

  void stop() {
    if (currentState.status == ModuleStateStatus.idle) return;
    _sendSessionRequest(proto.StateRequest(activityStop: proto.ActivityStopCmd()));
  }

  // ── Private helpers ───────────────────────────────────────────────────────

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
    }
  }

  void _reset() {
    _isPendingStart = false;
    _isPendingPause = false;
    _state.add(ModuleState.initial());
  }

  // ── Disposal ──────────────────────────────────────────────────────────────

  void dispose() {
    _connectionSub.cancel();
    _authSub.cancel();
    _closeSessionStream();
    _state.close();
    _events.close();
  }
}
