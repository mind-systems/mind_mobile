# Biometric Stream Pipeline — Sample, Router, Client, Batcher, Wiring

**Date:** 2026-05-24
**Used by:** ROADMAP Phase 21 milestones 5–9
**Architecture contract:** [26-biometric-stream-architecture.md](26-biometric-stream-architecture.md)
**Depends on:** [27-biometrics-refactor.md](27-biometrics-refactor.md) (capability mixins must exist)

The pipeline turns capability-source streams into batched proto messages on a single bidi gRPC stream, gated by the current module session. Five sequential milestones — each independently shippable.

Data flow:

```
NeiryBciProvider ──IHeartRateSource───┐
                 ──IRrIntervalSource──┤
                 ──IEegBandsSource────┼──▶ BioStreamRouter ──Stream<BioSample>──▶ BiometricBatcher ──List<BioSample>──▶ BiometricStreamClient ──gRPC bidi──▶ API
                 ──IEmotionsSource────┤
                 ──IMotionSource──────┘
                                                                                                       ▲
                                                                                                       │
                                                                              ModuleStateChannel.events (start/pause/resume/end)
```

---

## Milestone 5 — `BioSample` value object + per-type encoder

Single file `lib/Biometrics/BioSample.dart`. Pure data — no I/O, no streams.

```dart
import 'package:mind/Bci/Models/BciEmotionsData.dart';
import 'package:mind/Bci/Models/BciNfbData.dart';
import 'Models/CardioData.dart';
import 'Models/MotionData.dart';
import 'Models/RrInterval.dart';

final class BioSample {
  final int timestampMs;
  final String sampleType;
  final Map<String, dynamic> data;

  const BioSample({
    required this.timestampMs,
    required this.sampleType,
    required this.data,
  });

  factory BioSample.fromRr(RrInterval rr) {
    return BioSample(
      timestampMs: rr.timestamp.millisecondsSinceEpoch,
      sampleType: 'rr',
      data: {
        'intervalMs': rr.intervalMs,
        'isArtifact': rr.isArtifact,
        'source': rr.source.name,
      },
    );
  }

  factory BioSample.fromCardio(CardioData cardio) {
    return BioSample(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      sampleType: 'cardio',
      data: {
        'heartRate': cardio.heartRate,
        'metricsAvailable': cardio.metricsAvailable,
        'hasArtifacts': cardio.hasArtifacts,
        'source': cardio.source.name,
        if (cardio.hrv != null)
          'hrv': {
            'rmssd': cardio.hrv!.rmssd,
            'sdnn': cardio.hrv!.sdnn,
            'pnn50': cardio.hrv!.pnn50,
            'lf': cardio.hrv!.lf,
            'hf': cardio.hrv!.hf,
            'lfhf': cardio.hrv!.lfhf,
          },
      },
    );
  }

  factory BioSample.fromNfb(BciNfbData nfb) {
    return BioSample(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      sampleType: 'nfb',
      data: {
        'delta': nfb.delta,
        'theta': nfb.theta,
        'alpha': nfb.alpha,
        'smr': nfb.smr,
        'beta': nfb.beta,
        'source': 'neiry',
      },
    );
  }

  factory BioSample.fromEmotions(BciEmotionsData emotions) {
    return BioSample(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      sampleType: 'emotions',
      data: {
        'attention': emotions.attention,
        'relaxation': emotions.relaxation,
        'cognitiveLoad': emotions.cognitiveLoad,
        'cognitiveControl': emotions.cognitiveControl,
        'selfControl': emotions.selfControl,
        'source': 'neiry',
      },
    );
  }

  factory BioSample.fromMotion(MotionData motion) {
    return BioSample(
      timestampMs: motion.timestamp.millisecondsSinceEpoch,
      sampleType: 'motion',
      data: {
        'ax': motion.accelerometer.x,
        'ay': motion.accelerometer.y,
        'az': motion.accelerometer.z,
        'gx': motion.gyroscope.x,
        'gy': motion.gyroscope.y,
        'gz': motion.gyroscope.z,
        'source': motion.source.name,
      },
    );
  }
}
```

### Why no `sessionId` on `BioSample`

The session ID is known only by `BiometricStreamClient` (subscriber to `ModuleStateChannel.events`). `BioSample` is the producer-side model; `sessionId` is injected at wire-encoding time inside `sendBatch`. Keeps Router/encoder hardware-agnostic and session-agnostic.

### Why `source` is hardcoded for `nfb`/`emotions`

EEG classifiers only run on a BCI device, and Neiry is the only BCI we support. When a second EEG source lands, add a `source` field to `BciNfbData` / `BciEmotionsData` and read from it (mirroring how `CardioData` / `RrInterval` already work).

### Why `rr.timestamp` and `motion.timestamp` (not `DateTime.now()`)

`RrInterval.timestamp` is the **moment of the beat that completed the interval** — measured by the SDK at the PPG-pick level. `MotionData.timestamp` comes from the native MEMS sampler, which stamps each sample at the inertial-sensor level (this matters because `MEMSClassifier.memsStream` ships in batches — `DateTime.now()` would collapse a whole batch onto one wall-clock instant and destroy the within-batch movement timeline). Using SDK-supplied timestamps for both preserves true physiological / inertial cadence, including any SDK→Flutter dispatch latency. The other three sample types (`cardio`/`nfb`/`emotions`) come from `stateStream`s with no per-sample timestamp, so `DateTime.now()` is the best available approximation.

---

## Milestone 6 — `BioStreamRouter`

Single file `lib/Biometrics/BioStreamRouter.dart`. Registers any number of capability sources per capability, merges all of them into one `Stream<BioSample>` without dedup. Source identity is preserved on every sample via the `source` field — server-side analytics is responsible for comparison, artifact rejection, or any chosen dedup policy.

```dart
import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'BioSample.dart';
import 'IEegBandsSource.dart';
import 'IEmotionsSource.dart';
import 'IHeartRateSource.dart';
import 'IMotionSource.dart';
import 'IRrIntervalSource.dart';

class BioStreamRouter {
  final List<IHeartRateSource> _heartRates = [];
  final List<IRrIntervalSource> _rrIntervals = [];
  final List<IEegBandsSource> _eegBands = [];
  final List<IEmotionsSource> _emotions = [];
  final List<IMotionSource> _motions = [];

  Stream<BioSample>? _merged;

  void registerHeartRateSource(IHeartRateSource source) {
    _heartRates.add(source);
    _merged = null;
  }

  void registerRrIntervalSource(IRrIntervalSource source) {
    _rrIntervals.add(source);
    _merged = null;
  }

  void registerEegBandsSource(IEegBandsSource source) {
    _eegBands.add(source);
    _merged = null;
  }

  void registerEmotionsSource(IEmotionsSource source) {
    _emotions.add(source);
    _merged = null;
  }

  void registerMotionSource(IMotionSource source) {
    _motions.add(source);
    _merged = null;
  }

  /// Merged broadcast stream of all registered capability sources.
  ///
  /// Constructed lazily on first read; capabilities with no sources are
  /// omitted from the merge. Multiple sources for the same capability
  /// (e.g. Neiry + Garmin both supplying HR) are merged in parallel —
  /// every sample carries its origin in `data['source']`, so the server
  /// can distinguish, compare, or reject artifacts per source. No
  /// client-side dedup.
  ///
  /// Invariant: register every source BEFORE the first subscriber reads
  /// `samples`. After the first read the merged stream is cached and
  /// subsequent `register*` calls invalidate the cache, but an already-
  /// subscribed consumer keeps the old merged stream and will not see
  /// the newly added source. In practice `App.initialize()` registers
  /// all sources before `BiometricBatcher` subscribes, so this never
  /// bites — but document and respect it.
  Stream<BioSample> get samples {
    final cached = _merged;
    if (cached != null) return cached;
    final streams = <Stream<BioSample>>[
      for (final s in _heartRates)  s.cardioStream.map((c) => BioSample.fromCardio(c)),
      for (final s in _rrIntervals) s.rrStream.map((r) => BioSample.fromRr(r)),
      for (final s in _eegBands)    s.nfbStream.map((n) => BioSample.fromNfb(n)),
      for (final s in _emotions)    s.emotionsStream.map((e) => BioSample.fromEmotions(e)),
      for (final s in _motions)     s.motionStream.map((m) => BioSample.fromMotion(m)),
    ];
    final merged = Rx.merge(streams).asBroadcastStream();
    _merged = merged;
    return merged;
  }
}
```

### Why no client-side dedup

When two sources supply the same capability (e.g. Neiry headband PPG + Garmin watch HR), each sample carries its `source` tag and both flow through to the server. Comparison, averaging, artifact rejection, or "prefer dedicated sensor" logic lives in analytics where the full data is visible — the client does not have enough context to choose. Forwarding both preserves information; dropping client-side would discard it irreversibly.

### Why broadcast

`BiometricBatcher` is the only subscriber today, but `BioStreamRouter.samples` is exposed publicly. Broadcast keeps the door open for diagnostics taps without requiring re-merge.

### Register-before-subscribe invariant

The lazy `_merged` cache means: once a subscriber reads `samples`, that subscriber is bound to whatever sources were registered at that moment. Adding a source after the fact invalidates the cache but does not retroactively patch the existing subscription — a fresh subscriber sees the new source, the old one does not. For the current `App.initialize()` flow (all sources registered before any subscriber attaches) this is correct and simple. If a future dynamic-source scenario lands, switch `samples` to a `StreamGroup` or similar.

---

## Milestone 7 — `BiometricStreamClient`

Single file `lib/Biometrics/BiometricStreamClient.dart`. Owns the bidi gRPC stream, the session-lifecycle gating flag, and the disconnect replay ring.

### Fields

```dart
class BiometricStreamClient {
  final ModuleBiometricStreamServiceClient _grpcStub;
  final StreamSubscription<ModuleStateEvent> _lifecycleSub;

  String? _currentSessionId;
  bool _isPaused = false;
  final Queue<BioSample> _replayRing = Queue<BioSample>();
  static const int _replayRingMax = 75;

  // Underlying bidi stream handle; details follow ModuleInstructionStream pattern.
  // ...
}
```

### Constructor

```dart
BiometricStreamClient({
  required ModuleBiometricStreamServiceClient grpcStub,
  required Stream<ModuleStateEvent> moduleStateEvents,
}) : _grpcStub = grpcStub {
  _lifecycleSub = moduleStateEvents.listen(_onLifecycleEvent);
}
```

### Lifecycle gating

```dart
void _onLifecycleEvent(ModuleStateEvent event) {
  switch (event) {
    case ModuleSessionStarted(:final moduleSessionId):
      _currentSessionId = moduleSessionId;
      _isPaused = false;
    case ModuleSessionPaused():
      _isPaused = true;
    case ModuleSessionUnpaused():
      _isPaused = false;
    case ModuleSessionEnded():
    case ModuleSessionAbandoned():
      _currentSessionId = null;
      _isPaused = false;
      _replayRing.clear();
  }
}
```

### Send path

```dart
void sendBatch(List<BioSample> samples) {
  if (_currentSessionId == null || _isPaused) return;     // silent drop, by design
  if (samples.isEmpty) return;
  final sessionId = _currentSessionId!;
  for (final sample in samples) {
    final wire = BioSampleProto()
      ..sessionId = sessionId
      ..timestamp = Int64(sample.timestampMs)
      ..sampleType = sample.sampleType
      ..data = _toStruct(sample.data);
    try {
      _sink.add(BioStreamRequest(samples: [wire]));   // exact API per generated stubs
    } catch (e) {
      logPrint('BiometricStreamClient: stream send failed, enqueuing replay: $e');
      _enqueueReplay(sample);
    }
  }
}

void _enqueueReplay(BioSample sample) {
  if (_replayRing.length >= _replayRingMax) {
    _replayRing.removeFirst();   // drop oldest
  }
  _replayRing.add(sample);
}
```

The exact proto class names (`BioSampleProto`, `BioStreamRequest`) come from milestone 4's generated stubs — adjust to match. The wire `data` field is `google.protobuf.Struct`; convert `Map<String, dynamic>` via the standard generated `Struct` constructor.

### Reconnect replay

When the underlying gRPC stream reconnects (mirror the `ModuleInstructionStream` reconnect hook — likely a callback wired in App.dart at construction time, or a subscription to `GrpcConnectionManager.connectionState`), drain the replay ring first via `sendBatch(_replayRing.toList()); _replayRing.clear();`. Implementation detail follows whatever the existing `ModuleInstructionStream` does — the goal is parity, not invention.

### Dispose

```dart
Future<void> dispose() async {
  await _lifecycleSub.cancel();
  // Close the gRPC sink / cancel any underlying subscription.
}
```

### Why pause drops samples (does not buffer)

Per the architecture contract (note 26 §7): during pause the user is doing something undefined; analytics weight is already low for paused sessions; not worth shipping bytes. Symmetric with `ModuleInstructionStream` which the server blocks during pause.

---

## Milestone 8 — `BiometricBatcher`

Single file `lib/Biometrics/BiometricBatcher.dart`. Buffers between Router and Client. Flushes on size or timeout.

```dart
import 'dart:async';

import 'BioSample.dart';
import 'BioStreamRouter.dart';
import 'BiometricStreamClient.dart';

class BiometricBatcher {
  final BioStreamRouter _router;
  final BiometricStreamClient _client;

  static const int _maxBatchSize = 25;
  static const Duration _flushInterval = Duration(milliseconds: 250);

  final List<BioSample> _buffer = [];
  Timer? _flushTimer;
  StreamSubscription<BioSample>? _sub;

  BiometricBatcher({
    required BioStreamRouter router,
    required BiometricStreamClient client,
  }) : _router = router,
       _client = client {
    _sub = _router.samples.listen(_onSample);
  }

  void _onSample(BioSample sample) {
    _buffer.add(sample);
    if (_buffer.length >= _maxBatchSize) {
      _flushNow();
      return;
    }
    _flushTimer ??= Timer(_flushInterval, _flushNow);
  }

  void _flushNow() {
    if (_buffer.isEmpty) return;
    final batch = List<BioSample>.unmodifiable(_buffer);
    _buffer.clear();
    _flushTimer?.cancel();
    _flushTimer = null;
    _client.sendBatch(batch);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _flushTimer?.cancel();
    _flushTimer = null;
    _flushNow();
  }
}
```

### Why no backpressure logic in the batcher

The client's `sendBatch` is fire-and-forget — it always returns immediately, either accepting samples or silently dropping (during pause / no session) or enqueuing for replay (on stream error). The batcher does not observe drops; it has no policy to apply. Backpressure is the client's concern.

### Flush on dispose

Final flush in `dispose()` ships any buffered samples before the underlying stream closes — best-effort, mirrors what the existing `InstructionBuffer` does.

---

## Milestone 9 — Wire pipeline in `App.dart`

In `App.initialize()`, after the existing BCI block (`bciDeviceManager`, `bciNotifier`) but before `App.shared` is constructed:

```dart
// Biometric streaming pipeline
final bioStreamRouter = BioStreamRouter();
bioStreamRouter.registerHeartRateSource(bciProvider);
bioStreamRouter.registerRrIntervalSource(bciProvider);
bioStreamRouter.registerEegBandsSource(bciProvider);
bioStreamRouter.registerEmotionsSource(bciProvider);
bioStreamRouter.registerMotionSource(bciProvider);

final biometricStreamClient = BiometricStreamClient(
  grpcStub: grpcClient.moduleBiometricStreamService,
  moduleStateEvents: moduleStateChannel.events,
);

final biometricBatcher = BiometricBatcher(
  router: bioStreamRouter,
  client: biometricStreamClient,
);
```

Pass into `App.shared`:

```dart
App.shared = App(
  // ...existing fields...
  bioStreamRouter: bioStreamRouter,
  biometricStreamClient: biometricStreamClient,
  biometricBatcher: biometricBatcher,
);
```

Add the three fields on `App`:

```dart
final BioStreamRouter bioStreamRouter;
final BiometricStreamClient biometricStreamClient;
final BiometricBatcher biometricBatcher;
```

The exact `grpcClient.moduleBiometricStreamService` getter name depends on what the generated stub exposes (milestone 4 output). Adjust to match.

### `App.shared` is not exposed to UI

Nothing in `packages/bci_module` or `packages/breath_module` reads these — the pipeline is a passive background concern wired entirely inside `lib/`. UI code does not import `lib/Biometrics/` at all.

### Disposal

If `App` has a `dispose()` (it does not today), wire `biometricBatcher.dispose()` → `biometricStreamClient.dispose()`. For now: process lifetime = pipeline lifetime, no explicit teardown needed.
