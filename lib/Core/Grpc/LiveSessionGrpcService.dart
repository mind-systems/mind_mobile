import 'dart:async';
import 'dart:developer';

import 'package:fixnum/fixnum.dart';
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';

import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Core/Grpc/GrpcConnectionManager.dart';
import 'package:mind/Core/Grpc/GrpcConnectionState.dart';
import 'package:mind/Core/Grpc/ILiveSessionService.dart';
import 'package:mind/Core/Grpc/ModuleStateChannel.dart';
import 'package:mind/Core/Grpc/generated/live.pbgrpc.dart' as proto;
import 'package:mind/Core/Grpc/generated/telemetry.pbgrpc.dart';

class LiveSessionGrpcService implements ILiveSessionService {
  final GrpcConnectionManager _connectionManager;
  final ModuleStateChannel _channel;
  final TelemetryServiceClient _telemetryService;

  // ── Connection state ──────────────────────────────────────────────────────

  Stream<GrpcConnectionState> get connectionState =>
      _connectionManager.connectionState;

  bool get isConnected => _channel.isConnected && _telemetrySub != null;

  // ── Telemetry stream ──────────────────────────────────────────────────────

  final _telemetryStateController = StreamController<void>.broadcast();
  final _dataAckController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<void> get telemetryStateEvents => _telemetryStateController.stream;

  Stream<Map<String, dynamic>> get dataAckEvents => _dataAckController.stream;

  StreamSubscription<TelemetryResponse>? _telemetrySub;
  StreamController<TelemetryData>? _telemetrySink;

  // ── Connection state subscription ─────────────────────────────────────────

  late final StreamSubscription<GrpcConnectionState> _connectionStateSub;

  // ── Constructor ───────────────────────────────────────────────────────────

  LiveSessionGrpcService({
    required GrpcConnectionManager connectionManager,
    required ModuleStateChannel channel,
    required TelemetryServiceClient telemetryService,
  })  : _connectionManager = connectionManager,
        _channel = channel,
        _telemetryService = telemetryService {
    _connectionStateSub = connectionManager.connectionState.listen((state) {
      switch (state) {
        case GrpcConnectionState.connected:
          _openTelemetryStream();
        case GrpcConnectionState.disconnected:
          _telemetrySub?.cancel();
          _telemetrySub = null;
          _telemetrySink?.close();
          _telemetrySink = null;
        case GrpcConnectionState.connecting:
          break;
      }
    });
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void dispose() {
    _connectionStateSub.cancel();
    _telemetrySub?.cancel();
    _telemetrySink?.close();
    _telemetryStateController.close();
    _dataAckController.close();
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
    _connectionManager.confirmConnected();
    // Signal to BreathTelemetryService that the telemetry channel is ready
    _telemetryStateController.add(null);
  }

  // ── ILiveSessionService backward-compat delegation ────────────────────────

  @override
  Stream<Map<String, dynamic>> get sessionStateEvents =>
      _channel.rawSessionEvents.map((e) => <String, dynamic>{
            'status': _mapSessionStatus(e.status),
            'liveSessionId': e.liveSessionId,
            'isPaused': e.isPaused,
          });

  @override
  void sendActivityStart({required ActivityType type, String? refId}) {
    _channel.start(type: type, refId: refId);
  }

  @override
  void sendActivityEnd() {
    _channel.end();
  }

  @override
  void sendActivityStop() {
    _channel.stop();
  }

  @override
  void sendActivityPause() {
    _channel.pause();
  }

  @override
  void sendActivityResume() {
    _channel.unpause();
  }

  // ── Telemetry public API ──────────────────────────────────────────────────

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
