import 'dart:async';
import 'dart:collection';

import 'package:fixnum/fixnum.dart';
import 'package:mind/Logger.dart';
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';

import 'package:mind/Core/Grpc/GrpcConnectionState.dart';
import 'package:mind/Core/Grpc/ModuleStateEvent.dart';
import 'package:mind/Core/Grpc/generated/module_biometric_stream.pbgrpc.dart'
    as $bio;
import 'BioSample.dart';

/// gRPC sink for the biometric pipeline.
///
/// Owns the [ModuleBiometricStreamService.streamData] bidi stream and the
/// current-module-session gating flag. [sendBatch] is a silent no-op when there
/// is no active session — by design (architecture note 26 §7).
/// On send failure, samples are enqueued into a bounded drop-oldest replay ring
/// (max 75). On stream reconnect the ring drains first before new samples are pushed.
/// Session ended / abandoned clears the ring — samples buffered for a completed
/// session are not worth re-shipping.
///
/// Reference: `.ai-factory/notes/28-biometric-stream-pipeline.md` "Milestone 7".
class BiometricStreamClient {
  final $bio.ModuleBiometricStreamServiceClient _grpcStub;
  late final StreamSubscription<GrpcConnectionState> _connectionSub;
  late final StreamSubscription<ModuleStateEvent> _lifecycleSub;
  StreamSubscription<String?>? _rootIdSub;

  String? _currentSessionId;
  bool _sessionConfirmed = false;

  final Queue<BioSample> _replayRing = Queue<BioSample>();
  static const int _replayRingMax = 75;

  /// Outbound bidi sink, lazy-opened on first send.
  StreamController<$bio.BioSampleBatch>? _sink;

  /// Server-side response stream subscription.
  StreamSubscription<$bio.BioStreamResponse>? _responseSub;

  /// Timestamp of the last stream-open attempt; used for the 2-second reopen cooldown.
  DateTime? _lastOpenAttempt;

  /// True once the server has emitted a `BioStreamReady` frame (or the fallback
  /// timer has fired). Reset to false on every `_ensureSinkOpen` so the gate
  /// re-arms for both cold-start and reconnect.
  bool _isReady = false;

  /// Fires after [_readyTimeout] if no `BioStreamReady` is received; drains the
  /// replay ring so the client degrades gracefully against an un-upgraded server.
  Timer? _readyTimer;

  /// Time source used for the 2-second reopen cooldown. Defaults to [DateTime.now].
  final DateTime Function() _clock;

  /// How long to wait for a `BioStreamReady` frame before draining the replay
  /// ring without it. Defaults to 5 seconds.
  final Duration _readyTimeout;

  BiometricStreamClient({
    required $bio.ModuleBiometricStreamServiceClient grpcStub,
    required Stream<ModuleStateEvent> moduleStateEvents,
    required Stream<GrpcConnectionState> connectionState,
    Stream<String?>? rootIdChanges,
    DateTime Function() clock = DateTime.now,
    Duration readyTimeout = const Duration(seconds: 5),
  })  : _grpcStub = grpcStub,
        _clock = clock,
        _readyTimeout = readyTimeout {
    _lifecycleSub = moduleStateEvents.listen(_onLifecycleEvent);
    _connectionSub = connectionState.listen((state) {
      switch (state) {
        case GrpcConnectionState.connected:
          _ensureSinkOpen();
        case GrpcConnectionState.disconnected:
          _teardownSink();
          _sessionConfirmed = false;
        case GrpcConnectionState.connecting:
          break;
      }
    });
    // note 17: this is the injection point where bio will be retargeted to
    // subscribe `_currentSessionId`/`_sessionConfirmed` off the root-id stream
    // instead of `_onLifecycleEvent`. Additive no-op for now — behavior unchanged.
    _rootIdSub = rootIdChanges?.listen(_onRootIdChanged);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void _onLifecycleEvent(ModuleStateEvent event) {
    switch (event) {
      case ModuleSessionStarted(:final moduleSessionId):
        _currentSessionId = moduleSessionId;
        _sessionConfirmed = true;
        _lastOpenAttempt = null;
      case ModuleSessionResumed(:final moduleSessionId):
        _currentSessionId = moduleSessionId;
        _sessionConfirmed = true;
        _lastOpenAttempt = null;
      case ModuleSessionPaused():
        break;
      case ModuleSessionUnpaused():
        break;
      case ModuleSessionEnded() || ModuleSessionAbandoned():
        _currentSessionId = null;
        _sessionConfirmed = false;
        _lastOpenAttempt = null;
        _replayRing.clear();
    }
  }

  /// No-op placeholder for the root-id seam (note 17 wires this into
  /// `_currentSessionId`/`_sessionConfirmed`). Intentionally does nothing yet.
  void _onRootIdChanged(String? rootId) {}

  // ── Public API ────────────────────────────────────────────────────────────

  void sendBatch(List<BioSample> samples) {
    if (_currentSessionId == null || !_sessionConfirmed) return;
    if (samples.isEmpty) return;
    _ensureSinkOpen();
    _encodeAndAdd(samples);
  }

  Future<void> dispose() async {
    _readyTimer?.cancel();
    _readyTimer = null;
    await _connectionSub.cancel();
    await _lifecycleSub.cancel();
    await _rootIdSub?.cancel();
    await _responseSub?.cancel();
    await _sink?.close();
    _sink = null;
    _responseSub = null;
    _replayRing.clear();
  }

  // ── Stream lifecycle ──────────────────────────────────────────────────────

  void _ensureSinkOpen() {
    if (_sink != null) return;

    if (_lastOpenAttempt != null &&
        _clock().difference(_lastOpenAttempt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastOpenAttempt = _clock();

    _isReady = false;
    _sink = StreamController<$bio.BioSampleBatch>();
    try {
      final response = _grpcStub.streamData(_sink!.stream);
      _responseSub = response.listen(
        ($bio.BioStreamResponse r) {
          switch (r.whichEvent()) {
            case $bio.BioStreamResponse_Event.ack:
              break; // no-op for this milestone
            case $bio.BioStreamResponse_Event.error:
              logPrint('[BiometricStreamClient] error: ${r.error.code} — ${r.error.message}');
            case $bio.BioStreamResponse_Event.ready:
              _isReady = true;
              _readyTimer?.cancel();
              _readyTimer = null;
              final replay = _replayRing.toList();
              _replayRing.clear();
              if (replay.isNotEmpty) _encodeAndAdd(replay);
            case $bio.BioStreamResponse_Event.notSet:
              break;
          }
        },
        onError: (Object e) {
          logPrint('[BiometricStreamClient] stream error: $e');
          _teardownSink();
        },
        onDone: () {
          logPrint('[BiometricStreamClient] stream done');
          _teardownSink();
        },
      );
    } catch (e) {
      logPrint('[BiometricStreamClient] stream open failed: $e');
      _teardownSink();
      return;
    }

    _readyTimer = Timer(_readyTimeout, () {
      if (!_isReady) {
        logPrint('[BiometricStreamClient] readiness timeout — draining without server ready');
        _isReady = true;
        final replay = _replayRing.toList();
        _replayRing.clear();
        if (replay.isNotEmpty) _encodeAndAdd(replay);
      }
    });
  }

  void _teardownSink() {
    _readyTimer?.cancel();
    _readyTimer = null;
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
    if (!_isReady) {
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
      logPrint('[BiometricStreamClient] stream send failed, enqueuing replay: $e');
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
