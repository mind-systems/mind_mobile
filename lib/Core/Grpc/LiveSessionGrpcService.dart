import 'dart:async';
import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fixnum/fixnum.dart';
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';

import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Core/Grpc/generated/live.pbgrpc.dart' as proto;
import 'package:mind/Core/Grpc/generated/telemetry.pbgrpc.dart';
import 'package:mind/Core/Grpc/GrpcConnectionManager.dart';
import 'package:mind/Core/Grpc/GrpcConnectionState.dart';
import 'package:mind/Core/Grpc/ILiveSessionService.dart';
import 'package:mind/User/Models/AuthState.dart';

class LiveSessionGrpcService implements ILiveSessionService {
  final proto.LiveServiceClient _liveService;
  final TelemetryServiceClient _telemetryService;

  // ── Connection manager ────────────────────────────────────────────────────

  late final GrpcConnectionManager _connectionManager;

  Stream<GrpcConnectionState> get connectionState =>
      _connectionManager.connectionState;

  // ── Session event streams ─────────────────────────────────────────────────

  final _sessionStateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _telemetryStateController = StreamController<void>.broadcast();
  final _dataAckController =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get sessionStateEvents =>
      _sessionStateController.stream;

  Stream<void> get telemetryStateEvents => _telemetryStateController.stream;

  Stream<Map<String, dynamic>> get dataAckEvents => _dataAckController.stream;

  // ── Stream handles ────────────────────────────────────────────────────────

  StreamSubscription<proto.LiveResponse>? _liveSub;
  StreamSubscription<TelemetryResponse>? _telemetrySub;

  StreamController<proto.LiveRequest>? _liveSink;
  StreamController<TelemetryData>? _telemetrySink;

  bool get isConnected => _liveSub != null && _telemetrySub != null;

  // ── Constructor ───────────────────────────────────────────────────────────

  LiveSessionGrpcService({
    required proto.LiveServiceClient liveService,
    required TelemetryServiceClient telemetryService,
    required Stream<AuthState> authStream,
    required Stream<List<ConnectivityResult>> connectivityStream,
    required Stream<void> resumeStream,
  })  : _liveService = liveService,
        _telemetryService = telemetryService {
    _connectionManager = GrpcConnectionManager(
      authStream: authStream,
      connectivityStream: connectivityStream,
      resumeStream: resumeStream,
      onConnect: _connect,
      onDisconnect: _disconnect,
      isConnected: () => isConnected,
    );
  }

  // ── Private connection callbacks ──────────────────────────────────────────

  Future<void> _connect() async {
    await Future.wait([_openLiveStream(), _openTelemetryStream()]);
  }

  void _disconnect() {
    log('[LiveSessionGrpc] disconnect()', name: 'LiveSessionGrpcService');
    _liveSub?.cancel();
    _liveSub = null;
    _telemetrySub?.cancel();
    _telemetrySub = null;
    _liveSink?.close();
    _liveSink = null;
    _telemetrySink?.close();
    _telemetrySink = null;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void dispose() {
    _connectionManager.dispose();
    _sessionStateController.close();
    _telemetryStateController.close();
    _dataAckController.close();
  }

  // ── Live bidi stream ──────────────────────────────────────────────────────

  Future<void> _openLiveStream() async {
    _liveSink = StreamController<proto.LiveRequest>();
    final response = _liveService.liveSession(_liveSink!.stream);
    _liveSub = response.listen(
      (proto.LiveResponse r) {
        switch (r.whichEvent()) {
          case proto.LiveResponse_Event.sessionState:
            final event = r.sessionState;
            // DISCONNECTED is a transport-level status — do not forward it as
            // a session lifecycle event to avoid noise in LiveBreathSessionNotifier.
            if (event.status == proto.SessionStatus.DISCONNECTED) return;
            final data = <String, dynamic>{
              'status': _mapSessionStatus(event.status),
              'liveSessionId': event.liveSessionId,
              'isPaused': event.isPaused,
            };
            _sessionStateController.add(data);
          case proto.LiveResponse_Event.sessionError:
            log(
              '[LiveSessionGrpc] session error: ${r.sessionError.code} — ${r.sessionError.message}',
              name: 'LiveSessionGrpcService',
            );
          case proto.LiveResponse_Event.notSet:
            break;
        }
      },
      onError: (Object e) {
        log(
          '[LiveSessionGrpc] live stream error: $e',
          name: 'LiveSessionGrpcService',
        );
        _connectionManager.disconnect();
        _connectionManager.scheduleReconnect();
      },
      onDone: () {
        log(
          '[LiveSessionGrpc] live stream done',
          name: 'LiveSessionGrpcService',
        );
        _connectionManager.disconnect();
        _connectionManager.scheduleReconnect();
      },
    );
  }

  String _mapSessionStatus(proto.SessionStatus status) {
    switch (status) {
      case proto.SessionStatus.ACTIVE:
        return 'active';
      case proto.SessionStatus.RESUMED:
        return 'resumed';
      case proto.SessionStatus.COMPLETED:
        return 'completed';
      case proto.SessionStatus.ABANDONED:
        return 'abandoned';
      case proto.SessionStatus.INTERRUPTED:
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
        _connectionManager.disconnect();
        _connectionManager.scheduleReconnect();
      },
      onDone: () {
        log(
          '[LiveSessionGrpc] telemetry stream done',
          name: 'LiveSessionGrpcService',
        );
        _connectionManager.disconnect();
        _connectionManager.scheduleReconnect();
      },
    );
    // Signal to BreathTelemetryService that the telemetry channel is ready
    _telemetryStateController.add(null);
  }

  // ── Public API ────────────────────────────────────────────────────────────

  @override
  void sendActivityStart({required ActivityType type, String? refId}) {
    _sendLiveRequest(proto.LiveRequest(
      activityStart: proto.ActivityStartCmd(
        activityType: _mapActivityType(type),
        refId: refId ?? '',
      ),
    ));
  }

  @override
  void sendActivityEnd() {
    _sendLiveRequest(proto.LiveRequest(activityEnd: proto.ActivityEndCmd()));
  }

  @override
  void sendActivityStop() {
    _sendLiveRequest(proto.LiveRequest(activityStop: proto.ActivityStopCmd()));
  }

  @override
  void sendActivityPause() {
    _sendLiveRequest(proto.LiveRequest(activityPause: proto.ActivityPauseCmd()));
  }

  @override
  void sendActivityResume() {
    _sendLiveRequest(proto.LiveRequest(activityResume: proto.ActivityResumeCmd()));
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
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _sendLiveRequest(proto.LiveRequest request) {
    if (_liveSink == null) {
      log(
        '[LiveSessionGrpc] not connected, dropping request',
        name: 'LiveSessionGrpcService',
      );
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
