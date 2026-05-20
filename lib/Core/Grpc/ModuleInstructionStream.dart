import 'dart:async';
import 'dart:developer';

import 'package:fixnum/fixnum.dart';
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';

import 'package:mind/Core/Grpc/GrpcConnectionManager.dart';
import 'package:mind/Core/Grpc/GrpcConnectionState.dart';
import 'package:mind/Core/Grpc/InstructionAck.dart';
import 'package:mind/Core/Grpc/InstructionSample.dart';
import 'package:mind/Core/Grpc/generated/module_instruction_stream.pbgrpc.dart';

class ModuleInstructionStream {
  final GrpcConnectionManager _connectionManager;
  final ModuleInstructionStreamServiceClient _instructionStreamService;

  // ── Lazy-connect flags ────────────────────────────────────────────────────

  bool _isGrpcConnected = false;
  bool _streamRequested = false;
  bool _backoffConfirmed = false;

  // ── Stream handles ────────────────────────────────────────────────────────

  StreamSubscription<StreamResponse>? _streamSub;
  StreamController<StreamSample>? _streamSink;

  bool get isConnected => _streamSink != null;
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
    required ModuleInstructionStreamServiceClient instructionStreamService,
  })  : _connectionManager = connectionManager,
        _instructionStreamService = instructionStreamService {
    _connectionSub = connectionManager.connectionState.listen((state) {
      switch (state) {
        case GrpcConnectionState.connected:
          _isGrpcConnected = true;
          if (_streamRequested) _openStream();
        case GrpcConnectionState.disconnected:
          _isGrpcConnected = false;
          _streamSub?.cancel();
          _streamSub = null;
          _streamSink?.close();
          _streamSink = null;
        case GrpcConnectionState.connecting:
          break;
      }
    });
  }

  // ── Public API ────────────────────────────────────────────────────────────

  void emit(InstructionSample sample) {
    if (_streamSink == null) {
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
    _streamSink!.add(_toProto(sample));
  }

  void dispose() {
    _connectionSub.cancel();
    _streamSub?.cancel();
    _streamSink?.close();
    _ackController.close();
    _readyController.close();
  }

  // ── Stream lifecycle ──────────────────────────────────────────────────────

  void _openStream() {
    _backoffConfirmed = false;
    _streamSink = StreamController<StreamSample>();
    final response = _instructionStreamService.streamData(_streamSink!.stream);
    _streamSub = response.listen(
      (StreamResponse r) {
        if (!_backoffConfirmed) {
          _backoffConfirmed = true;
          _connectionManager.confirmConnected();
        }
        switch (r.whichEvent()) {
          case StreamResponse_Event.ack:
            final ack = r.ack;
            _ackController.add(InstructionAck(
              sessionId: ack.sessionId,
              receivedCount: ack.receivedCount.toInt(),
              droppedCount: ack.droppedCount.toInt(),
              maxSamplesPerSecond: ack.maxSamplesPerSecond,
              timestamp: ack.timestamp.toInt(),
            ));
          case StreamResponse_Event.error:
            log(
              '[ModuleInstructionStream] error: ${r.error.code} — ${r.error.message}',
              name: 'ModuleInstructionStream',
            );
          case StreamResponse_Event.notSet:
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
    _readyController.add(null);
  }

  // ── Proto conversion helpers ──────────────────────────────────────────────

  StreamSample _toProto(InstructionSample sample) {
    return StreamSample(
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
