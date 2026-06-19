import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:mind/Logger.dart';
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';

import 'package:mind/Core/Grpc/GrpcConnectionManager.dart';
import 'package:mind/Core/Grpc/GrpcConnectionState.dart';
import 'package:mind/Core/Grpc/InstructionSample.dart';
import 'package:mind/Core/Grpc/generated/module_instruction_stream.pbgrpc.dart';

class ModuleInstructionStream {
  final GrpcConnectionManager _connectionManager;
  final ModuleInstructionStreamServiceClient _instructionStreamService;

  // ── Connect flags ─────────────────────────────────────────────────────────

  bool _isGrpcConnected = false;
  bool _backoffConfirmed = false;

  // ── Rate-limit ────────────────────────────────────────────────────────────

  int _maxSamplesPerSecond = 10;
  DateTime? _lastSendTime;

  // ── Readiness gate ────────────────────────────────────────────────────────

  bool _isReady = false;
  final List<StreamSample> _outbox = [];
  Timer? _readyTimer;

  static const _readyTimeout = Duration(seconds: 5);

  // ── Stream handles ────────────────────────────────────────────────────────

  StreamSubscription<StreamResponse>? _streamSub;
  StreamController<StreamSample>? _streamSink;

  bool get isConnected => _streamSink != null;

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
          _openStream();
        case GrpcConnectionState.disconnected:
          _isGrpcConnected = false;
          _readyTimer?.cancel();
          _isReady = false;
          _lastSendTime = null;
          _outbox.clear();
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
        logPrint('[ModuleInstructionStream] not connected, dropping sample');
        return;
      }
      _openStream();
    }
    final proto = _toProto(sample);
    if (_isReady) {
      final minIntervalMs = 1000 ~/ _maxSamplesPerSecond;
      if (_lastSendTime != null &&
          DateTime.now().difference(_lastSendTime!).inMilliseconds < minIntervalMs) {
        // Over-cap: drop. The cap is a best-effort guard — for the only current
        // consumer (breath) phase changes are seconds apart so this branch is
        // effectively never taken.
        logPrint('[ModuleInstructionStream] over-cap, dropping sample');
        return;
      }
      _streamSink!.add(proto);
      _lastSendTime = DateTime.now();
    } else {
      _outbox.add(proto);
    }
  }

  void dispose() {
    _readyTimer?.cancel();
    _connectionSub.cancel();
    _streamSub?.cancel();
    _streamSink?.close();
  }

  // ── Stream lifecycle ──────────────────────────────────────────────────────

  void _openStream() {
    _readyTimer?.cancel();
    _isReady = false;
    _lastSendTime = null;
    _outbox.clear();
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
            if (ack.maxSamplesPerSecond > 0) {
              _maxSamplesPerSecond = ack.maxSamplesPerSecond;
            }
          case StreamResponse_Event.ready:
            _readyTimer?.cancel();
            if (r.ready.maxSamplesPerSecond > 0) {
              _maxSamplesPerSecond = r.ready.maxSamplesPerSecond;
            }
            _becomeReady();
          case StreamResponse_Event.error:
            logPrint('[ModuleInstructionStream] error: ${r.error.code} — ${r.error.message}');
          case StreamResponse_Event.notSet:
            break;
        }
      },
      onError: (Object e) {
        logPrint('[ModuleInstructionStream] stream error: $e');
        _readyTimer?.cancel();
        _isReady = false;
        _outbox.clear();
        _connectionManager.disconnect();
        _connectionManager.scheduleReconnect();
      },
      onDone: () {
        logPrint('[ModuleInstructionStream] stream done');
        _readyTimer?.cancel();
        _isReady = false;
        _outbox.clear();
        _connectionManager.disconnect();
        _connectionManager.scheduleReconnect();
      },
    );
    _readyTimer = Timer(_readyTimeout, _onReadyTimeout);
  }

  void _onReadyTimeout() {
    if (_isReady) return;
    logPrint('[ModuleInstructionStream] readiness timeout — flushing without server ready');
    _becomeReady();
  }

  void _becomeReady() {
    _isReady = true;
    _drainOutbox();
  }

  void _drainOutbox() {
    _outbox.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    for (final s in _outbox) {
      _streamSink!.add(s);
    }
    _outbox.clear();
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
