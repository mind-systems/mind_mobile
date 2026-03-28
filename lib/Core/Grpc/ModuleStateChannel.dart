import 'dart:async';
import 'dart:developer';

import 'package:rxdart/rxdart.dart';

import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Core/Grpc/GrpcConnectionManager.dart';
import 'package:mind/Core/Grpc/GrpcConnectionState.dart';
import 'package:mind/Core/Grpc/ModuleState.dart';
import 'package:mind/Core/Grpc/ModuleStateEvent.dart';
import 'package:mind/Core/Grpc/generated/live.pbgrpc.dart' as proto;
import 'package:mind/User/Models/AuthState.dart';

class ModuleStateChannel {
  final proto.LiveServiceClient _liveService;
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

  // ── Stream handles ────────────────────────────────────────────────────────

  StreamSubscription<proto.LiveResponse>? _liveSub;
  StreamController<proto.LiveRequest>? _liveSink;

  bool get isConnected => _liveSub != null;

  // ── Subscriptions ─────────────────────────────────────────────────────────

  late final StreamSubscription<GrpcConnectionState> _connectionSub;
  late final StreamSubscription<AuthState> _authSub;

  // ── Constructor ───────────────────────────────────────────────────────────

  ModuleStateChannel({
    required proto.LiveServiceClient liveService,
    required GrpcConnectionManager connectionManager,
    required Stream<AuthState> authStream,
  })  : _liveService = liveService,
        _connectionManager = connectionManager {
    _connectionSub = connectionManager.connectionState.listen((state) {
      switch (state) {
        case GrpcConnectionState.connected:
          _openLiveStream();
        case GrpcConnectionState.disconnected:
          _closeLiveStream();
        case GrpcConnectionState.connecting:
          break;
      }
    });
    _authSub = authStream.listen((auth) {
      if (auth is GuestState) _reset();
    });
  }

  // ── Live stream management ────────────────────────────────────────────────

  void _openLiveStream() {
    _liveSink = StreamController<proto.LiveRequest>();
    final response = _liveService.liveSession(_liveSink!.stream);
    _liveSub = response.listen(
      (proto.LiveResponse r) {
        switch (r.whichEvent()) {
          case proto.LiveResponse_Event.sessionState:
            final event = r.sessionState;
            if (event.status == proto.SessionStatus.DISCONNECTED) return;
            _processProtoEvent(event);
          case proto.LiveResponse_Event.sessionError:
            log(
              '[ModuleStateChannel] session error: ${r.sessionError.code} — ${r.sessionError.message}',
              name: 'ModuleStateChannel',
            );
          case proto.LiveResponse_Event.notSet:
            break;
        }
      },
      onError: (Object e) {
        log('[ModuleStateChannel] live stream error: $e', name: 'ModuleStateChannel');
        _closeLiveStream();
        _connectionManager.disconnect();
        _connectionManager.scheduleReconnect();
      },
      onDone: () {
        log('[ModuleStateChannel] live stream done', name: 'ModuleStateChannel');
        _closeLiveStream();
        _connectionManager.disconnect();
        _connectionManager.scheduleReconnect();
      },
    );
    _connectionManager.confirmConnected();
  }

  void _closeLiveStream() {
    _liveSub?.cancel();
    _liveSub = null;
    _liveSink?.close();
    _liveSink = null;
  }

  // ── Proto → typed mapping ─────────────────────────────────────────────────

  void _processProtoEvent(proto.SessionStateEvent event) {
    final status = event.status;
    if (status == proto.SessionStatus.ACTIVE || status == proto.SessionStatus.RESUMED) {
      final isPaused = event.isPaused;
      final liveSessionId = event.liveSessionId;
      final wasPaused = currentState.isPaused;
      final isNew = currentState.status != ModuleStateStatus.active;
      _isPendingStart = false;
      _isPendingPause = false;
      _state.add(ModuleState(liveSessionId: liveSessionId, status: ModuleStateStatus.active, isPaused: isPaused));
      if (isNew) {
        _events.add(ModuleSessionStarted(liveSessionId: liveSessionId));
      } else if (!wasPaused && isPaused) {
        _events.add(ModuleSessionPaused());
      } else if (wasPaused && !isPaused) {
        _events.add(ModuleSessionUnpaused());
      }
    } else if (status == proto.SessionStatus.COMPLETED || status == proto.SessionStatus.INTERRUPTED) {
      _state.add(ModuleState.initial());
      _events.add(ModuleSessionEnded());
    } else if (status == proto.SessionStatus.ABANDONED) {
      _state.add(ModuleState.initial());
      _events.add(ModuleSessionAbandoned());
    } else if (status == proto.SessionStatus.SESSION_STATUS_UNSPECIFIED) {
      _isPendingStart = false;
      _state.add(ModuleState.initial());
    } else {
      log('[ModuleStateChannel] unhandled status: $status', name: 'ModuleStateChannel', level: 900);
    }
  }

  // ── Public session commands ───────────────────────────────────────────────

  void start({required ActivityType type, String? refId}) {
    if (currentState.status == ModuleStateStatus.active || _isPendingStart) return;
    _isPendingStart = true;
    _sendLiveRequest(proto.LiveRequest(
      activityStart: proto.ActivityStartCmd(
        activityType: _mapActivityType(type),
        refId: refId ?? '',
      ),
    ));
  }

  void pause() {
    if (currentState.status != ModuleStateStatus.active || currentState.isPaused || _isPendingPause) return;
    _isPendingPause = true;
    _sendLiveRequest(proto.LiveRequest(activityPause: proto.ActivityPauseCmd()));
  }

  void unpause() {
    if (!currentState.isPaused) return;
    _isPendingPause = false;
    _sendLiveRequest(proto.LiveRequest(activityResume: proto.ActivityResumeCmd()));
  }

  void end() {
    if (currentState.status == ModuleStateStatus.idle) return;
    _sendLiveRequest(proto.LiveRequest(activityEnd: proto.ActivityEndCmd()));
  }

  void stop() {
    if (currentState.status == ModuleStateStatus.idle) return;
    _sendLiveRequest(proto.LiveRequest(activityStop: proto.ActivityStopCmd()));
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _sendLiveRequest(proto.LiveRequest request) {
    if (_liveSink == null) {
      log('[ModuleStateChannel] not connected, dropping request', name: 'ModuleStateChannel');
      return;
    }
    _liveSink!.add(request);
  }

  proto.ActivityType _mapActivityType(ActivityType type) {
    switch (type) {
      case ActivityType.breath:
        return proto.ActivityType.BREATH;
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
    _closeLiveStream();
    _state.close();
    _events.close();
  }
}
