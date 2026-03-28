import 'dart:async';
import 'dart:developer';

import 'package:fixnum/fixnum.dart';
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';

import 'package:mind/Core/Grpc/GrpcConnectionManager.dart';
import 'package:mind/Core/Grpc/GrpcConnectionState.dart';
import 'package:mind/Core/Grpc/InstructionAck.dart';
import 'package:mind/Core/Grpc/InstructionSample.dart';
import 'package:mind/Core/Grpc/generated/telemetry.pb.dart';
import 'package:mind/Core/Grpc/generated/telemetry.pbgrpc.dart';

class ModuleInstructionStream {
  final GrpcConnectionManager _connectionManager;
  final TelemetryServiceClient _telemetryService;

  // ── Lazy-connect flags ────────────────────────────────────────────────────

  bool _isGrpcConnected = false;
  bool _streamRequested = false;

  // ── Stream handles ────────────────────────────────────────────────────────

  StreamSubscription<TelemetryResponse>? _telemetrySub;
  StreamController<TelemetryData>? _telemetrySink;

  bool get isConnected => _telemetrySink != null;
  bool get isGrpcConnected => _isGrpcConnected;

  // ── Output streams ────────────────────────────────────────────────────────

  final _ackController = StreamController<InstructionAck>.broadcast();
  final _readyController = StreamController<void>.broadcast();

  Stream<InstructionAck> get acks => _ackController.stream;
  Stream<void> get readyEvents => _readyController.stream;

  // ── Connection state subscription ─────────────────────────────────────────

  late final StreamSubscription<GrpcConnectionState> _connectionSub;

  // ── Constructor ───────────────────────────────────────────────────────────

  ModuleInstructionStream({
    required GrpcConnectionManager connectionManager,
    required TelemetryServiceClient telemetryService,
  })  : _connectionManager = connectionManager,
        _telemetryService = telemetryService {
    _connectionSub = connectionManager.connectionState.listen((state) {
      switch (state) {
        case GrpcConnectionState.connected:
          _isGrpcConnected = true;
          if (_streamRequested) _openStream();
        case GrpcConnectionState.disconnected:
          _isGrpcConnected = false;
          _telemetrySub?.cancel();
          _telemetrySub = null;
          _telemetrySink?.close();
          _telemetrySink = null;
        case GrpcConnectionState.connecting:
          break;
      }
    });
  }

  // ── Public API ────────────────────────────────────────────────────────────

  void emit(InstructionSample sample) {
    if (_telemetrySink == null) {
      if (!_isGrpcConnected) {
        log(
          '[ModuleInstructionStream] not connected, dropping sample',
          name: 'ModuleInstructionStream',
        );
        return;
      }
      _streamRequested = true;
      _openStream();
    }
    _telemetrySink!.add(_toProto(sample));
  }

  void dispose() {
    _connectionSub.cancel();
    _telemetrySub?.cancel();
    _telemetrySink?.close();
    _ackController.close();
    _readyController.close();
  }

  // ── Stream lifecycle ──────────────────────────────────────────────────────

  void _openStream() {
    _telemetrySink = StreamController<TelemetryData>();
    final response = _telemetryService.streamTelemetry(_telemetrySink!.stream);
    _telemetrySub = response.listen(
      (TelemetryResponse r) {
        switch (r.whichEvent()) {
          case TelemetryResponse_Event.ack:
            final ack = r.ack;
            _ackController.add(InstructionAck(
              sessionId: ack.sessionId,
              receivedCount: ack.receivedCount.toInt(),
              droppedCount: ack.droppedCount.toInt(),
              maxSamplesPerSecond: ack.maxSamplesPerSecond,
              timestamp: ack.timestamp.toInt(),
            ));
          case TelemetryResponse_Event.error:
            log(
              '[ModuleInstructionStream] error: ${r.error.code} — ${r.error.message}',
              name: 'ModuleInstructionStream',
            );
          case TelemetryResponse_Event.notSet:
            break;
        }
      },
      onError: (Object e) {
        log(
          '[ModuleInstructionStream] stream error: $e',
          name: 'ModuleInstructionStream',
        );
        _streamRequested = false;
        _connectionManager.disconnect();
        _connectionManager.scheduleReconnect();
      },
      onDone: () {
        log(
          '[ModuleInstructionStream] stream done',
          name: 'ModuleInstructionStream',
        );
        _streamRequested = false;
        _connectionManager.disconnect();
        _connectionManager.scheduleReconnect();
      },
    );
    _connectionManager.confirmConnected();
    _readyController.add(null);
  }

  // ── Proto conversion helpers ──────────────────────────────────────────────

  TelemetryData _toProto(InstructionSample sample) {
    return TelemetryData(
      sessionId: sample.sessionId,
      timestamp: Int64(sample.timestamp),
      moduleId: sample.moduleId,
      instructionType: sample.instructionType,
      data: _mapToStruct(sample.data),
    );
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
    throw ArgumentError('Unsupported type for proto Value: ${v.runtimeType}');
  }
}
