import 'dart:async';
import 'dart:collection';
import 'dart:developer';

import 'package:fixnum/fixnum.dart';
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';

import 'package:mind/Core/Grpc/ModuleStateEvent.dart';
import 'package:mind/Core/Grpc/generated/module_biometric_stream.pbgrpc.dart'
    as $bio;
import 'BioSample.dart';

/// gRPC sink for the biometric pipeline.
///
/// Owns the [ModuleBiometricStreamService.streamData] bidi stream and the
/// current-module-session gating flag. [sendBatch] is a silent no-op when there
/// is no active session or the session is paused — by design (architecture note 26 §7).
/// On send failure, samples are enqueued into a bounded drop-oldest replay ring
/// (max 75). On stream reconnect the ring drains first before new samples are pushed.
/// Session ended / abandoned clears the ring — samples buffered for a completed
/// session are not worth re-shipping.
///
/// Reference: `.ai-factory/notes/28-biometric-stream-pipeline.md` "Milestone 7".
class BiometricStreamClient {
  final $bio.ModuleBiometricStreamServiceClient _grpcStub;
  late final StreamSubscription<ModuleStateEvent> _lifecycleSub;

  String? _currentSessionId;
  bool _isPaused = false;

  final Queue<BioSample> _replayRing = Queue<BioSample>();
  static const int _replayRingMax = 75;

  /// Outbound bidi sink, lazy-opened on first send.
  StreamController<$bio.BioSampleBatch>? _sink;

  /// Server-side response stream subscription.
  StreamSubscription<$bio.BioStreamResponse>? _responseSub;

  BiometricStreamClient({
    required $bio.ModuleBiometricStreamServiceClient grpcStub,
    required Stream<ModuleStateEvent> moduleStateEvents,
  }) : _grpcStub = grpcStub {
    _lifecycleSub = moduleStateEvents.listen(_onLifecycleEvent);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void _onLifecycleEvent(ModuleStateEvent event) {
    switch (event) {
      case ModuleSessionStarted(:final moduleSessionId):
        _currentSessionId = moduleSessionId;
        _isPaused = false;
      case ModuleSessionPaused():
        _isPaused = true;
      case ModuleSessionUnpaused():
        _isPaused = false;
      case ModuleSessionEnded() || ModuleSessionAbandoned():
        _currentSessionId = null;
        _isPaused = false;
        _replayRing.clear();
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  void sendBatch(List<BioSample> samples) {
    if (_currentSessionId == null || _isPaused) return;
    if (samples.isEmpty) return;
    _ensureSinkOpen();
    _encodeAndAdd(samples);
  }

  Future<void> dispose() async {
    await _lifecycleSub.cancel();
    await _responseSub?.cancel();
    await _sink?.close();
    _sink = null;
    _responseSub = null;
    _replayRing.clear();
  }

  // ── Stream lifecycle ──────────────────────────────────────────────────────

  void _ensureSinkOpen() {
    if (_sink != null) return;

    _sink = StreamController<$bio.BioSampleBatch>();
    try {
      final response = _grpcStub.streamData(_sink!.stream);
      _responseSub = response.listen(
        ($bio.BioStreamResponse r) {
          switch (r.whichEvent()) {
            case $bio.BioStreamResponse_Event.ack:
              break; // no-op for this milestone
            case $bio.BioStreamResponse_Event.error:
              log(
                '[BiometricStreamClient] error: ${r.error.code} — ${r.error.message}',
                name: 'BiometricStreamClient',
              );
            case $bio.BioStreamResponse_Event.notSet:
              break;
          }
        },
        onError: (Object e) {
          log(
            '[BiometricStreamClient] stream error: $e',
            name: 'BiometricStreamClient',
          );
          _teardownSink();
        },
        onDone: () {
          log(
            '[BiometricStreamClient] stream done',
            name: 'BiometricStreamClient',
          );
          _teardownSink();
        },
      );
    } catch (e) {
      log(
        '[BiometricStreamClient] stream open failed: $e',
        name: 'BiometricStreamClient',
      );
      _teardownSink();
      return;
    }

    if (_currentSessionId != null) {
      final replay = _replayRing.toList();
      _replayRing.clear();
      if (replay.isNotEmpty) _encodeAndAdd(replay);
    }
  }

  void _teardownSink() {
    _responseSub?.cancel();
    _responseSub = null;
    _sink?.close();
    _sink = null;
  }

  // ── Encoding ──────────────────────────────────────────────────────────────

  void _encodeAndAdd(List<BioSample> samples) {
    final sessionId = _currentSessionId;
    if (sessionId == null) return;
    if (_sink == null) {
      for (final s in samples) {
        _enqueueReplay(s);
      }
      return;
    }

    final wireSamples = samples
        .map((sample) => $bio.BioSample(
              sessionId: sessionId,
              timestamp: Int64(sample.timestampMs),
              sampleType: sample.sampleType,
              data: _mapToStruct(sample.data),
            ))
        .toList();

    final batch = $bio.BioSampleBatch(samples: wireSamples);
    try {
      _sink!.add(batch);
    } catch (e) {
      log(
        '[BiometricStreamClient] stream send failed, enqueuing replay: $e',
        name: 'BiometricStreamClient',
      );
      for (final sample in samples) {
        _enqueueReplay(sample);
      }
      _teardownSink();
    }
  }

  void _enqueueReplay(BioSample sample) {
    if (_replayRing.length >= _replayRingMax) {
      _replayRing.removeFirst();
    }
    _replayRing.add(sample);
  }

  // ── Proto conversion helpers ──────────────────────────────────────────────

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
