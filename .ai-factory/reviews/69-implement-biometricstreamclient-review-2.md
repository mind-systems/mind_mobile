# Code Review #2: Implement `BiometricStreamClient`

**Plan:** `.ai-factory/plans/69-implement-biometricstreamclient.md`
**File under review:** `lib/Biometrics/BiometricStreamClient.dart` (208 lines)
**Prior review:** `.ai-factory/reviews/69-implement-biometricstreamclient-review-1.md`
**Cross-referenced:** `lib/Core/Grpc/ModuleInstructionStream.dart`, `lib/Core/Grpc/ModuleStateChannel.dart`, `lib/Core/Grpc/ModuleStateEvent.dart`, `lib/Core/Grpc/generated/module_biometric_stream.pb.dart` + `.pbgrpc.dart`, `lib/Biometrics/BioSample.dart`, `lib/Biometrics/Models/CardioData.dart`, note 28.

## Status of prior findings

- **F1 (drain re-entry leaves `_sink` null before user-batch encoding)** — **RESOLVED.** `_encodeAndAdd` now checks `_sink == null` at line 148 and routes samples through `_enqueueReplay` rather than a null-deref-and-catch. No more noisy double-exception when drain fails mid-`_ensureSinkOpen`.
- **F2 (synchronous throw from `_grpcStub.streamData(...)` unguarded)** — **RESOLVED.** Lines 89–127 wrap both `streamData(...)` and `response.listen(...)` in `try/catch`. On throw, `_teardownSink()` nulls the partially-initialized state and the method returns early; control then falls into `_encodeAndAdd` which sees `_sink == null` and ring-buffers the batch (per the F1 fix).
- **F3 (dead `_currentSessionId` re-check)** — unchanged. Defensive in single-threaded Dart, harmless. Nit.
- **F4 (no reconnect backoff)** — unchanged. Acknowledged as out of scope for this milestone; reconnect throttling would belong in `GrpcConnectionManager` integration in a later milestone. Nit.
- **F5 (`_teardownSink` does not await its futures)** — unchanged. Matches `ModuleStateChannel._closeSessionStream`. Nit.

## Path verification (post-fix)

Traced all four lifecycle/error paths against the current code:

1. **Normal first send** (lines 67–72 + 85–134 + 145–177): session active, ring empty, `streamData` succeeds → drain no-ops → user batch encoded and sent. ✓
2. **`streamData` throws synchronously** (line 90 throws → catch at 120): log; `_teardownSink` nulls `_sink` + `_responseSub` (the latter was never assigned, so the `?.cancel()` no-ops); early `return` at 126 skips the drain. Back in `sendBatch`, `_encodeAndAdd` sees `_sink == null` → enqueues user batch to ring. ✓
3. **Drain `_sink!.add` throws** (recursive `_encodeAndAdd` from line 132): catch at 167 enqueues replay back into ring + `_teardownSink` nulls `_sink`. Control returns to `_ensureSinkOpen` which has finished its work. Control returns to `sendBatch` line 71 → `_encodeAndAdd(userSamples)` sees `_sink == null` → enqueues user batch to ring. Order preserved (replay first, then user samples — both via `_enqueueReplay`'s drop-oldest discipline). ✓
4. **Stream `onError`/`onDone` async fire** (lines 105–118): `_teardownSink` nulls sink. Next `sendBatch` triggers fresh `_ensureSinkOpen`. Replay drain runs only if `_currentSessionId != null` (line 129) — if session ended in between, the lifecycle handler at lines 58–62 cleared the ring already, so the drain finds an empty ring. ✓

## Cross-reference verification

- Generated proto names (`BioSample`, `BioSampleBatch`, `BioStreamResponse`, `BioStreamResponse_Event`, `ModuleBiometricStreamServiceClient`) match `module_biometric_stream.pb.dart` / `.pbgrpc.dart`.
- `streamData(Stream<BioSampleBatch>) → ResponseStream<BioStreamResponse>` signature at `module_biometric_stream.pbgrpc.dart:36–41` matches the call at line 90.
- `Struct`/`Value`/`NullValue`/`ListValue` import path matches `ModuleInstructionStream.dart:5`.
- `BioSample` name collision resolved via `$bio` prefix on the generated import; all 4 `$bio.BioSample` usages (lines 35, 38, 91, 141, 156) are the proto type; all bare `BioSample` references are the domain type.
- `ModuleStateEvent` sealed-switch (lines 50–62) covers all five subtypes (Ended/Abandoned combined). Dart 3 exhaustiveness check enforced at compile time.
- `ModuleStateChannel.events` is `PublishSubject<ModuleStateEvent>.stream` (broadcast) — `BiometricStreamClient`'s subscription does not interfere with other subscribers.
- `BioSample.data` contains only `String`/`num`/`bool`/`Map<String, dynamic>` shapes from every factory in `BioSample.dart`. `_valueFrom`'s `List` and `ArgumentError` branches are unreachable for current call sites but correctly guarded.
- Replay ring constants (`max 75`, drop-oldest, `Queue<BioSample>`) match the spec.
- Lifecycle gating semantics (silent drop on no-session/paused; clear ring on ended/abandoned; do **not** clear ring on `onError`) match note 28 §Milestone 7.
- Single `BioSampleBatch` per `sendBatch` (line 164) — improvement over the note's per-sample example, matches the proto's stated purpose.
- `dispose` order (cancel lifecycle → cancel response sub → close sink → null-out → clear ring) is correct and awaits the futures.

## New findings

None.

## Verdict

Both critical findings from review-1 have been correctly resolved. Remaining items (F3 dead defensive check; F4 no backoff; F5 unawaited cleanup futures) are nits that match patterns elsewhere in the codebase and were explicitly out of scope for this milestone. No new bugs, security issues, or correctness problems identified.

REVIEW_PASS
