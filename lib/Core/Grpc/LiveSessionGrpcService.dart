import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:fixnum/fixnum.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';
import 'package:rxdart/rxdart.dart';

import 'package:mind/Core/Grpc/generated/live.pbgrpc.dart';
import 'package:mind/Core/Grpc/generated/telemetry.pbgrpc.dart';
import 'package:mind/Core/Socket/ILiveSocketService.dart';
import 'package:mind/Core/Socket/SocketConnectionState.dart';
import 'package:mind/User/Models/AuthState.dart';

class LiveSessionGrpcService implements ILiveSocketService {
  final LiveServiceClient _liveService;
  final TelemetryServiceClient _telemetryService;

  // ── Connection state ──────────────────────────────────────────────────────

  final _connectionState = BehaviorSubject<SocketConnectionState>.seeded(
    SocketConnectionState.disconnected,
  );

  final _sessionStateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _telemetryStateController = StreamController<void>.broadcast();
  final _dataAckController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<SocketConnectionState> get connectionState =>
      _connectionState.stream;

  @override
  Stream<Map<String, dynamic>> get sessionStateEvents =>
      _sessionStateController.stream;

  /// Sync changes are handled by SyncGrpcListener — this service returns an
  /// empty stream so that ILiveSocketService consumers compile without changes.
  @override
  Stream<Map<String, dynamic>> get syncChangedEvents =>
      Stream<Map<String, dynamic>>.empty();

  Stream<void> get telemetryStateEvents => _telemetryStateController.stream;

  Stream<Map<String, dynamic>> get dataAckEvents => _dataAckController.stream;

  final ValueNotifier<String> lastSentMessage = ValueNotifier('');
  final ValueNotifier<String> lastReceivedMessage = ValueNotifier('');

  // ── Stream handles ────────────────────────────────────────────────────────

  StreamSubscription<LiveResponse>? _liveSub;
  StreamSubscription<TelemetryResponse>? _telemetrySub;

  StreamController<LiveRequest>? _liveSink;
  StreamController<TelemetryData>? _telemetrySink;

  // ── Auth + connection guards ──────────────────────────────────────────────

  bool _isAuthenticated = false;
  late final StreamSubscription<AuthState> _authSubscription;
  bool _isConnecting = false;

  bool get isConnected => _liveSub != null && _telemetrySub != null;

  // ── Reconnect state ───────────────────────────────────────────────────────

  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  static const Duration _initialDelay = Duration(seconds: 1);
  static const Duration _maxDelay = Duration(seconds: 30);

  // ── Constructor ───────────────────────────────────────────────────────────

  LiveSessionGrpcService({
    required LiveServiceClient liveService,
    required TelemetryServiceClient telemetryService,
    required Stream<AuthState> authStream,
  })  : _liveService = liveService,
        _telemetryService = telemetryService {
    _authSubscription = authStream.listen((state) {
      if (state is AuthenticatedState) {
        _isAuthenticated = true;
        connect();
      } else if (state is GuestState) {
        _isAuthenticated = false;
        disconnect();
      }
    });
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> connect() async {
    if (isConnected || _isConnecting) {
      log(
        '[LiveSessionGrpc] connect() skipped: isConnected=$isConnected _isConnecting=$_isConnecting',
        name: 'LiveSessionGrpcService',
      );
      return;
    }
    _isConnecting = true;
    _connectionState.add(SocketConnectionState.connecting);
    log('[LiveSessionGrpc] connect() start', name: 'LiveSessionGrpcService');

    try {
      await Future.wait([_openLiveStream(), _openTelemetryStream()]);
      _resetBackoff();
      _connectionState.add(SocketConnectionState.connected);
      log(
        '[LiveSessionGrpc] connect() succeeded',
        name: 'LiveSessionGrpcService',
      );
    } catch (e) {
      log(
        '[LiveSessionGrpc] connect() failed: $e',
        name: 'LiveSessionGrpcService',
      );
      disconnect();
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void disconnect() {
    log('[LiveSessionGrpc] disconnect()', name: 'LiveSessionGrpcService');
    _isConnecting = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _liveSub?.cancel();
    _liveSub = null;
    _telemetrySub?.cancel();
    _telemetrySub = null;
    _liveSink?.close();
    _liveSink = null;
    _telemetrySink?.close();
    _telemetrySink = null;
    _connectionState.add(SocketConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _authSubscription.cancel();
    _connectionState.close();
    _sessionStateController.close();
    _telemetryStateController.close();
    _dataAckController.close();
    lastSentMessage.dispose();
    lastReceivedMessage.dispose();
  }

  // ── Reconnect infrastructure ──────────────────────────────────────────────

  Duration _nextDelay() {
    final base = _initialDelay * math.pow(2, _reconnectAttempt);
    final clamped =
        base.inMilliseconds < _maxDelay.inMilliseconds ? base : _maxDelay;
    final jitter =
        (clamped.inMilliseconds * 0.25 * (math.Random().nextDouble() * 2 - 1))
            .round();
    _reconnectAttempt++;
    final ms =
        (clamped.inMilliseconds + jitter).clamp(0, _maxDelay.inMilliseconds);
    return Duration(milliseconds: ms);
  }

  void _scheduleReconnect() {
    if (!_isAuthenticated) return;
    _reconnectTimer?.cancel();
    final delay = _nextDelay();
    log(
      '[LiveSessionGrpc] reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempt)',
      name: 'LiveSessionGrpcService',
    );
    _reconnectTimer = Timer(delay, () {
      if (_isAuthenticated) connect();
    });
  }

  void _resetBackoff() {
    _reconnectAttempt = 0;
  }

  // ── Live bidi stream ──────────────────────────────────────────────────────

  Future<void> _openLiveStream() async {
    _liveSink = StreamController<LiveRequest>();
    final response = _liveService.liveSession(_liveSink!.stream);
    _liveSub = response.listen(
      (LiveResponse r) {
        switch (r.whichEvent()) {
          case LiveResponse_Event.sessionState:
            final event = r.sessionState;
            // DISCONNECTED is a transport-level status — do not forward it as
            // a session lifecycle event to avoid noise in LiveBreathSessionNotifier.
            if (event.status == SessionStatus.DISCONNECTED) return;
            final data = <String, dynamic>{
              'status': _mapSessionStatus(event.status),
              'liveSessionId': event.liveSessionId,
              'isPaused': event.isPaused,
            };
            _sessionStateController.add(data);
            if (WidgetsBinding.instance.schedulerPhase ==
                SchedulerPhase.idle) {
              lastReceivedMessage.value =
                  'live: session:state → ${data['status']}';
            }
          case LiveResponse_Event.sessionError:
            log(
              '[LiveSessionGrpc] session error: ${r.sessionError.code} — ${r.sessionError.message}',
              name: 'LiveSessionGrpcService',
            );
          case LiveResponse_Event.notSet:
            break;
        }
      },
      onError: (Object e) {
        log(
          '[LiveSessionGrpc] live stream error: $e',
          name: 'LiveSessionGrpcService',
        );
        disconnect();
        _scheduleReconnect();
      },
      onDone: () {
        log(
          '[LiveSessionGrpc] live stream done',
          name: 'LiveSessionGrpcService',
        );
        disconnect();
        _scheduleReconnect();
      },
    );
  }

  String _mapSessionStatus(SessionStatus status) {
    switch (status) {
      case SessionStatus.ACTIVE:
        return 'active';
      case SessionStatus.RESUMED:
        return 'resumed';
      case SessionStatus.COMPLETED:
        return 'completed';
      case SessionStatus.ABANDONED:
        return 'abandoned';
      case SessionStatus.INTERRUPTED:
        return 'interrupted';
      default:
        return 'unknown';
    }
  }

  // ── Telemetry bidi stream ─────────────────────────────────────────────────

  Future<void> _openTelemetryStream() async {
    _telemetrySink = StreamController<TelemetryData>();
    final response =
        _telemetryService.streamTelemetry(_telemetrySink!.stream);
    _telemetrySub = response.listen(
      (TelemetryResponse r) {
        switch (r.whichEvent()) {
          case TelemetryResponse_Event.ack:
            final ack = r.ack;
            final data = <String, dynamic>{
              'maxSamplesPerSecond': ack.maxSamplesPerSecond,
              'sessionId': ack.sessionId,
            };
            _dataAckController.add(data);
            if (WidgetsBinding.instance.schedulerPhase ==
                SchedulerPhase.idle) {
              lastReceivedMessage.value = 'telemetry: data:ack';
            }
          case TelemetryResponse_Event.error:
            log(
              '[LiveSessionGrpc] telemetry error: ${r.error.code} — ${r.error.message}',
              name: 'LiveSessionGrpcService',
            );
          case TelemetryResponse_Event.notSet:
            break;
        }
      },
      onError: (Object e) {
        log(
          '[LiveSessionGrpc] telemetry stream error: $e',
          name: 'LiveSessionGrpcService',
        );
        disconnect();
        _scheduleReconnect();
      },
      onDone: () {
        log(
          '[LiveSessionGrpc] telemetry stream done',
          name: 'LiveSessionGrpcService',
        );
        disconnect();
        _scheduleReconnect();
      },
    );
    // Signal to BreathTelemetryService that the telemetry channel is open,
    // matching the _telemetrySocket!.onConnect behaviour in LiveSocketService.
    _telemetryStateController.add(null);
  }

  // ── Public API ────────────────────────────────────────────────────────────

  @override
  void emitLive(String event, [Map<String, dynamic>? data]) {
    LiveRequest request;
    switch (event) {
      case 'activity:start':
        request = LiveRequest(
          activityStart: ActivityStartCmd(
            activityType:
                _mapActivityType(data?['activityType'] as String?),
            refId: data?['activityRefId'] as String? ?? '',
          ),
        );
      case 'activity:end':
        request = LiveRequest(activityEnd: ActivityEndCmd());
      case 'activity:stop':
        request = LiveRequest(activityStop: ActivityStopCmd());
      case 'activity:pause':
        request = LiveRequest(activityPause: ActivityPauseCmd());
      case 'activity:resume':
        request = LiveRequest(activityResume: ActivityResumeCmd());
      default:
        log(
          '[LiveSessionGrpc] emitLive: unknown event "$event"',
          name: 'LiveSessionGrpcService',
        );
        return;
    }

    if (_liveSink == null) {
      log(
        '[LiveSessionGrpc] emitLive: not connected, dropping "$event"',
        name: 'LiveSessionGrpcService',
      );
      return;
    }

    _liveSink!.add(request);
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      lastSentMessage.value = 'live: $event';
    }
  }

  void emitTelemetry(String event, [dynamic data]) {
    if (_telemetrySink == null) {
      log(
        '[LiveSessionGrpc] emitTelemetry: not connected, dropping "$event"',
        name: 'LiveSessionGrpcService',
      );
      return;
    }

    if (data is! Map<String, dynamic>) {
      log(
        '[LiveSessionGrpc] emitTelemetry: unexpected data type ${data?.runtimeType}',
        name: 'LiveSessionGrpcService',
      );
      return;
    }

    final telemetryData = TelemetryData(
      sessionId: data['sessionId'] as String? ?? '',
      timestamp: Int64(data['timestamp'] as int? ?? 0),
      moduleId: data['module_id'] as String? ?? '',
      instructionType: data['instruction_type'] as String? ?? '',
      data: _mapToStruct(
          (data['data'] as Map<String, dynamic>?) ?? <String, dynamic>{}),
    );

    _telemetrySink!.add(telemetryData);
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      lastSentMessage.value = 'telemetry: $event';
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  ActivityType _mapActivityType(String? type) {
    return type == 'breath'
        ? ActivityType.BREATH
        : ActivityType.ACTIVITY_TYPE_UNSPECIFIED;
  }

  Struct _mapToStruct(Map<String, dynamic> map) {
    return Struct(
      fields: map.entries.map((e) => MapEntry(e.key, _valueFrom(e.value))),
    );
  }

  Value _valueFrom(dynamic v) {
    if (v == null) return Value(nullValue: NullValue.NULL_VALUE);
    if (v is String) return Value(stringValue: v);
    if (v is int) return Value(numberValue: v.toDouble());
    if (v is double) return Value(numberValue: v);
    if (v is bool) return Value(boolValue: v);
    if (v is Map<String, dynamic>) return Value(structValue: _mapToStruct(v));
    if (v is List) {
      return Value(
        listValue: ListValue(values: v.map(_valueFrom).toList()),
      );
    }
    throw ArgumentError(
        'Unsupported type for proto Value: ${v.runtimeType}');
  }
}
