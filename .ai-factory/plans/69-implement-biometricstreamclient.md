# Plan: Implement `BiometricStreamClient`

## Context
Introduce `lib/Biometrics/BiometricStreamClient.dart` — the gRPC sink in the biometric pipeline. Owns the bidi `ModuleBiometricStreamService.streamData` stream, gates outbound traffic on the current module session (started / paused / unpaused / ended / abandoned), wire-encodes `BioSample` (domain) into the generated proto `BioSample`/`BioSampleBatch` shape, and buffers transient send failures into a bounded drop-oldest replay ring that drains on stream reconnect. Mirrors the structural patterns already used by `lib/Core/Grpc/ModuleInstructionStream.dart` — lazy stream open, `Struct`/`Value` conversion helpers, reconnect-driven re-open.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Implementation

- [x] **Task 1: Create `BiometricStreamClient` skeleton with imports, fields, and constructor**
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  Create the new file. Imports needed (note the import-prefix on the generated stubs to avoid the `BioSample` name clash with the local domain class):
  - `dart:async`
  - `dart:collection` (for `Queue`)
  - `dart:developer` (for `log`)
  - `package:fixnum/fixnum.dart` (for `Int64`)
  - `package:protobuf/well_known_types/google/protobuf/struct.pb.dart` (for `Struct`, `Value`, `NullValue`, `ListValue`)
  - `package:mind/Core/Grpc/ModuleStateEvent.dart`
  - `package:mind/Core/Grpc/generated/module_biometric_stream.pbgrpc.dart` as `$bio` (use a prefix; this re-exports `module_biometric_stream.pb.dart` so the prefix covers `BioSample`, `BioSampleBatch`, `BioStreamResponse`, `BioStreamAck`, `ModuleBiometricStreamServiceClient`)
  - `BioSample.dart` (the local domain model — imported **without** a prefix so the file's plain `BioSample` references resolve to the domain class)

  Declare `class BiometricStreamClient` with these fields:
  - `final $bio.ModuleBiometricStreamServiceClient _grpcStub;`
  - `late final StreamSubscription<ModuleStateEvent> _lifecycleSub;`
  - `String? _currentSessionId;`
  - `bool _isPaused = false;`
  - `final Queue<BioSample> _replayRing = Queue<BioSample>();`
  - `static const int _replayRingMax = 75;`
  - `StreamController<$bio.BioSampleBatch>? _sink;` — outbound bidi sink, lazy-opened on first send
  - `StreamSubscription<$bio.BioStreamResponse>? _responseSub;` — server-side response stream

  Constructor signature exactly as the milestone spec dictates:
  ```dart
  BiometricStreamClient({
    required $bio.ModuleBiometricStreamServiceClient grpcStub,
    required Stream<ModuleStateEvent> moduleStateEvents,
  }) : _grpcStub = grpcStub {
    _lifecycleSub = moduleStateEvents.listen(_onLifecycleEvent);
  }
  ```
  Do not subscribe to anything else here.

- [x] **Task 2: Add lifecycle event handler `_onLifecycleEvent`** (depends on Task 1)
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  Implement `void _onLifecycleEvent(ModuleStateEvent event)` using a Dart 3 `switch` over the sealed `ModuleStateEvent`:
  - `ModuleSessionStarted(:final moduleSessionId)` → `_currentSessionId = moduleSessionId; _isPaused = false;` (the field is `String?`; assign as-is — `moduleSessionId` is nullable per the existing model, but for our purposes a null id is equivalent to "no active session" and `sendBatch` already short-circuits on null)
  - `ModuleSessionPaused()` → `_isPaused = true;`
  - `ModuleSessionUnpaused()` → `_isPaused = false;`
  - `ModuleSessionEnded()` or `ModuleSessionAbandoned()` → `_currentSessionId = null; _isPaused = false; _replayRing.clear();`

  Use one `switch` with all four cases; do not introduce a default branch — exhaustiveness over the sealed hierarchy is the safety check.

- [x] **Task 3: Add proto conversion helpers `_mapToStruct` and `_valueFrom`** (depends on Task 1)
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  Port the conversion helpers verbatim from `lib/Core/Grpc/ModuleInstructionStream.dart` (lines 157–176):
  - `Struct _mapToStruct(Map<String, dynamic> map)` — builds a `Struct` from map entries via `_valueFrom`.
  - `Value _valueFrom(dynamic v)` — handles `null`, `String`, `int`, `double`, `bool`, nested `Map<String, dynamic>`, and `List` (recursing for list elements). Throws `ArgumentError` for unsupported types — same behavior as `ModuleInstructionStream`. This matters because `BioSample.data` already comes shaped as `Map<String, dynamic>` of these primitive types (see `lib/Biometrics/BioSample.dart` — string `source`, numeric metrics, optional bool `isArtifact`/`hasArtifacts`/`metricsAvailable`, optional nested `hrv` map).

  Keep them as private instance methods. Do not extract to a shared util in this milestone — the line count is small and a shared helper is a separate refactor.

- [x] **Task 4: Add lazy stream opening `_ensureSinkOpen`** (depends on Tasks 1, 3)
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  Add `void _ensureSinkOpen()`. Behavior:
  - If `_sink != null` → return (stream already open).
  - Create a new `StreamController<$bio.BioSampleBatch>()` (single-subscription is fine; the gRPC client subscribes once) and assign to `_sink`.
  - Call `final response = _grpcStub.streamData(_sink!.stream);` — the generated method signature is `ResponseStream<BioStreamResponse> streamData(Stream<BioSampleBatch> request, {CallOptions? options})`.
  - Subscribe `_responseSub = response.listen(...)`. Handlers:
    - `onData` (`$bio.BioStreamResponse r`): inspect `r.whichEvent()`:
      - `$bio.BioStreamResponse_Event.ack` → no-op for this milestone (acks are read but ignored; future analytics can surface them).
      - `$bio.BioStreamResponse_Event.error` → `log('[BiometricStreamClient] error: ${r.error.code} — ${r.error.message}', name: 'BiometricStreamClient');`
      - `$bio.BioStreamResponse_Event.notSet` → break.
    - `onError(Object e)`: log `'[BiometricStreamClient] stream error: $e'` and call `_teardownSink()` (see Task 6) — do **not** clear the replay ring; samples buffered there should survive the reconnect.
    - `onDone`: log `'[BiometricStreamClient] stream done'` and call `_teardownSink()`.
  - **After** the new sink is established, drain the replay ring: snapshot `final replay = _replayRing.toList(); _replayRing.clear();` then re-feed via `_encodeAndAdd(replay)` (see Task 5). Do this drain **only when there is an active session** (`_currentSessionId != null`); if the session has already ended by the time the stream re-opens, the ring was already cleared by the lifecycle handler and there is nothing to drain. The drain happens inside `_ensureSinkOpen` after the new controller is created and subscribed — that way every reconnect-triggered first send goes through the same drain path.

  Note: this milestone deliberately does **not** subscribe to `GrpcConnectionManager.connectionState`. The spec constructor accepts only `grpcStub` and `moduleStateEvents`. Reconnect is detected by stream `onError`/`onDone` nulling out the sink; the next `sendBatch` call (which only happens while a session is active and unpaused) lazily reopens it and triggers the replay drain. If the gRPC channel itself is down, `_grpcStub.streamData` may still return a stream that immediately errors — the error path will null `_sink` back out and any samples sent in the interim will be re-enqueued via the catch in `sendBatch`.

- [x] **Task 5: Implement `sendBatch` and `_enqueueReplay`** (depends on Tasks 2, 3, 4)
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  Add the public method:
  ```dart
  void sendBatch(List<BioSample> samples) {
    if (_currentSessionId == null || _isPaused) return; // silent drop, by design
    if (samples.isEmpty) return;
    _ensureSinkOpen();
    _encodeAndAdd(samples);
  }
  ```
  Add the encoder helper `void _encodeAndAdd(List<BioSample> samples)`:
  - Capture `final sessionId = _currentSessionId;` at the top — if it became null between the public check and here (lifecycle event interleaving), return early.
  - Build a `List<$bio.BioSample>` by mapping each domain `BioSample` to a generated proto using the constructor form:
    ```dart
    $bio.BioSample(
      sessionId: sessionId,
      timestamp: Int64(sample.timestampMs),
      sampleType: sample.sampleType,
      data: _mapToStruct(sample.data),
    )
    ```
  - Wrap into a single `$bio.BioSampleBatch(samples: wireSamples)` and push: `_sink!.add(batch)`. Send the batch as one frame — this matches the proto's `BioSampleBatch` purpose (reduce per-message overhead).
  - Wrap the `_sink!.add(...)` call in `try/catch`. On any `Object` caught: `log('[BiometricStreamClient] stream send failed, enqueuing replay: $e', name: 'BiometricStreamClient');` then iterate the original `samples` and enqueue each via `_enqueueReplay`. Also call `_teardownSink()` so the next send triggers a fresh `_ensureSinkOpen` (and replay drain). Do **not** rethrow.

  Add the ring helper:
  ```dart
  void _enqueueReplay(BioSample sample) {
    if (_replayRing.length >= _replayRingMax) {
      _replayRing.removeFirst(); // drop oldest
    }
    _replayRing.add(sample);
  }
  ```
  Keep `_replayRing` per-sample (not per-batch) — the spec is explicit (`Queue<BioSample>`, max 75, drop-oldest) and per-sample semantics avoid an unbounded outer-list-of-lists.

- [x] **Task 6: Implement `_teardownSink` and `dispose`** (depends on Task 4)
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  Add a private helper used by stream `onError`/`onDone` and by `sendBatch`'s catch path:
  ```dart
  void _teardownSink() {
    _responseSub?.cancel();
    _responseSub = null;
    _sink?.close();
    _sink = null;
  }
  ```
  Add the public lifecycle terminator:
  ```dart
  Future<void> dispose() async {
    await _lifecycleSub.cancel();
    await _responseSub?.cancel();
    await _sink?.close();
    _sink = null;
    _responseSub = null;
    _replayRing.clear();
  }
  ```
  `dispose` is `Future<void>` to mirror `BiometricBatcher.dispose` (next milestone consumer) and the convention used elsewhere in `lib/Core/Grpc/`.

- [x] **Task 7: Add file-level dartdoc summarising lifecycle, gating, replay, and reconnect** (depends on Tasks 1–6)
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  Add class-level dartdoc on `BiometricStreamClient` explaining, briefly:
  - Owns the `ModuleBiometricStreamService.streamData` bidi stream and the current-module-session gating flag.
  - Outbound traffic is gated: `sendBatch` is a silent no-op when there is no active session or the session is paused — by design (architecture note 26 §7).
  - On send failure, samples are enqueued into a bounded drop-oldest replay ring (max 75). On stream reconnect (any reopen of `_sink` via `_ensureSinkOpen`) the ring drains first before new samples are pushed.
  - Session ended / abandoned clears the ring — samples buffered for a session that ended are not worth re-shipping.
  - Reference: `.ai-factory/notes/28-biometric-stream-pipeline.md` "Milestone 7".

  Keep it short — the note is the canonical reference; the class doc is a 4–6 line summary.

<!-- orchestrator-sessions -->

<!-- orchestrator-sessions
planner: 9903e390-5a48-4afa-a508-962e58f5601e
elapsed: 1029
implementer: 9ef8ae7c-fd1d-4584-af39-d71719b8b6b8
-->
