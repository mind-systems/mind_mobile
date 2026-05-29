# Code Review: Implement `BiometricStreamClient`

**Plan:** `.ai-factory/plans/69-implement-biometricstreamclient.md`
**File under review:** `lib/Biometrics/BiometricStreamClient.dart` (193 lines, new)
**Cross-referenced:** `lib/Core/Grpc/ModuleInstructionStream.dart`, `lib/Core/Grpc/ModuleStateChannel.dart`, `lib/Core/Grpc/ModuleStateEvent.dart`, `lib/Core/Grpc/generated/module_biometric_stream.pb.dart` + `.pbgrpc.dart`, `lib/Biometrics/BioSample.dart`, `lib/Biometrics/Models/CardioData.dart`, `.ai-factory/notes/28-biometric-stream-pipeline.md`, `.ai-factory/plan-reviews/69-implement-biometricstreamclient-plan-review-1.md`.

The code follows the plan exactly. The plan-review's M1 (drain re-entry leaves `_sink` null before `sendBatch` calls `_encodeAndAdd` on the user batch) was acknowledged but **not** resolved in the implementation; it remains a real (low-impact) issue, repeated below as **F1** alongside one new finding (**F2**).

---

## Findings

### F1 — Drain re-entry leaves `_sink` null before user-batch encoding (carried forward from plan-review M1)

**Location:** `_ensureSinkOpen` lines 120–124 + `_encodeAndAdd` lines 150–161 + `sendBatch` line 70.

**Sequence:**
1. `sendBatch(userSamples)` → both gates pass → `_ensureSinkOpen()`.
2. `_ensureSinkOpen` creates the new `_sink`, subscribes to the response stream, then at line 123 calls `_encodeAndAdd(replay)`.
3. If `_sink!.add(batch)` inside the drain throws (e.g. the fresh controller is already in a bad state for any reason, or the response stream fires a synchronous error during `listen` that triggers `_teardownSink` before `add` runs), `_encodeAndAdd`'s catch (line 152) re-enqueues the replay samples and **calls `_teardownSink()` which nulls `_sink`** (line 160 + 131).
4. Control returns to `_ensureSinkOpen` (already past its work), then back up to `sendBatch` line 71: `_encodeAndAdd(samples)` for the user batch.
5. Inside `_encodeAndAdd`, line 151 dereferences `_sink!` while `_sink` is null → `TypeError: Null check operator used on null value`.

The same `try/catch` at line 150 catches the `TypeError`, the user samples are enqueued into the ring (lines 157–159), and `_teardownSink` is called a second time (line 160; idempotent, no harm). So **no samples are lost**, but the path produces two log lines and an exception object per failed send. It also depends on the catch being a silent safety net rather than explicit handling.

**Suggested fix (one liner):** at the top of `_encodeAndAdd`, after the `sessionId` capture, add
```dart
if (_sink == null) {
  for (final s in samples) _enqueueReplay(s);
  return;
}
```
This converts the implicit null-deref-then-catch into explicit handling, eliminates the noisy log, and avoids relying on `!` for control flow. Alternative: pull the drain out of `_ensureSinkOpen` and have `sendBatch` perform `_ensureSinkOpen(); drainIfAny(); _encodeAndAdd(samples);` guarded on `_sink != null` after each step.

Severity: **low** — no data loss, but should be cleaned up.

### F2 — Synchronous throw from `_grpcStub.streamData(...)` not guarded → caller crash

**Location:** `_ensureSinkOpen` line 89.

The generated stub returns `$createStreamingCall(_$streamData, request, options: options)` — for the gRPC Dart client, this is normally lazy, but it has been observed to throw synchronously when the underlying channel is in a terminal state (post-`shutdown`, or after auth interceptor rejection). The code does not wrap line 89 in `try/catch`. A synchronous throw here propagates:

`streamData` → `_ensureSinkOpen` → `sendBatch` → `BiometricBatcher._flushNow` (next-milestone consumer) → caller of `_flushNow` (the size-threshold path inside `_onSample`, or the `Timer` callback).

If the throw escapes the Timer callback in `BiometricBatcher`, it surfaces as an unhandled async error in the zone. If it escapes the size-threshold path, it crashes the producer that emitted the sample (a Stream subscription `onData`), which under default `Stream` semantics will cancel that subscription — silently killing the biometric pipeline for the rest of the process lifetime.

**Suggested fix:** wrap line 89 in try/catch; on throw, call `_teardownSink()` (sink is already non-null at this point and must be discarded) and enqueue the about-to-be-sent samples into the replay ring. The next `sendBatch` retries. The plan's N1 flagged this same risk; the implementation did not address it.

Severity: **medium** — depends on whether gRPC actually throws here in practice. Low-probability but high-blast-radius (silent kill of biometric stream for the session).

### F3 — `_currentSessionId` re-check in `_encodeAndAdd` is dead in single-threaded Dart (nit, not a bug)

`_encodeAndAdd` is only ever called from synchronous contexts (`sendBatch` line 71 and the drain at line 123), and Dart single-threading guarantees no lifecycle event can interleave between the sendBatch gate (line 68) and the re-check (line 138). The re-check is harmless but currently mis-presents itself as defensive correctness rather than what it is (a guard for the recursive drain caller, where `_currentSessionId` is in fact re-checked at line 120 immediately before — also redundant).

Severity: **nit**. Drop the re-check or add a one-line comment marking it as defensive future-proofing.

### F4 — `_ensureSinkOpen` triggers a fresh stream on every transient send error → no backoff

If the gRPC channel is persistently failing, `BiometricBatcher` (next milestone) will flush every 250ms; each flush calls `sendBatch` → `_ensureSinkOpen` (since `_sink` was nulled by the previous teardown) → a new `streamData` RPC → immediate `onError` → teardown → repeat. Up to ~4 reconnect attempts/sec, with no backoff in this class. `ModuleInstructionStream` defers backoff to `GrpcConnectionManager.scheduleReconnect()` (lines 129–130 of that file). Because the plan explicitly chose not to wire `GrpcConnectionManager` here (see Task 4 note), there is no equivalent backoff.

Severity: **low** — the gRPC client itself may dedupe or rate-limit this internally, and a healthy session will recover quickly. Worth a code comment acknowledging the choice or a follow-up note in `.ai-factory/notes/` for the next-milestone wiring.

### F5 — `_responseSub?.cancel()` and `_sink?.close()` not awaited in `_teardownSink` (intentional, but document)

Lines 128–131. Both calls return `Future<void>`; we ignore the futures. This is fine in cleanup paths (and matches `ModuleStateChannel._closeSessionStream` lines 110–113), but it means immediately after teardown the previous RPC may still be unwinding on the gRPC side while `_ensureSinkOpen` creates a new one on the next sendBatch. Should not cause functional problems given gRPC handles overlapping client RPCs, but worth a one-line acknowledgement in the file dartdoc.

Severity: **nit**.

---

## Cross-reference verification (positive)

- Generated proto class names (`BioSample`, `BioSampleBatch`, `BioStreamResponse`, `BioStreamResponse_Event`, `BioStreamAck`, `ModuleBiometricStreamServiceClient`) all match `lib/Core/Grpc/generated/module_biometric_stream.pb.dart` / `.pbgrpc.dart`. The `streamData(Stream<BioSampleBatch>) → ResponseStream<BioStreamResponse>` signature matches `.pbgrpc.dart:36–41`.
- `Struct`/`Value`/`NullValue`/`ListValue` import path `package:protobuf/well_known_types/google/protobuf/struct.pb.dart` matches the import used by `ModuleInstructionStream.dart:5` and by both generated `.pb.dart` files.
- The `BioSample` name collision between the local domain class (`lib/Biometrics/BioSample.dart`) and the generated proto class is correctly resolved via the `$bio` prefix on the generated import; the unprefixed `BioSample.dart` import gives `BioSample` the domain meaning throughout the file. Verified: every use of `$bio.BioSample` at line 141 is the proto type; every other `BioSample` reference is the domain type.
- The sealed `ModuleStateEvent` hierarchy in `lib/Core/Grpc/ModuleStateEvent.dart` has exactly five subtypes; the switch at lines 50–62 covers all five via the four-arm form (Ended/Abandoned combined). Dart 3 sealed-switch exhaustiveness is enforced at compile time.
- `ModuleSessionStarted.moduleSessionId` is `String?` and the assignment at line 52 preserves nullability; if null, the `sendBatch` gate at line 68 (`_currentSessionId == null`) prevents any sends — semantically correct ("no active session").
- `ModuleStateChannel.events` is a `PublishSubject<ModuleStateEvent>` (line 21 of that file), i.e. broadcast — `BiometricStreamClient`'s subscription does not interfere with other subscribers (e.g. `_state` channel).
- `BioSample.data` is built only from `String`, `num`, `bool`, and `Map<String, dynamic>` (`hrv` sub-map) values in every factory in `BioSample.dart` — `_valueFrom` handles all of these. The `List` branch (lines 186–190) is unreachable today; the `ArgumentError` branch (line 191) is unreachable for current call sites.
- Replay ring constants (`max 75`, drop-oldest, `Queue<BioSample>`) match the spec verbatim.
- Lifecycle gating semantics (silent drop on no-session / paused; clear ring on ended/abandoned; do **not** clear ring on `onError`) match note 28 §Milestone 7.
- Single `BioSampleBatch` per `sendBatch` (line 149) rather than per-sample frames matches the proto's stated purpose and improves on the note's per-sample example.

## Verdict

The implementation is faithful to the plan and the canonical note. **F1** and **F2** are real but low-impact correctness gaps that should be cleaned up before this lands in front of the next-milestone consumer (`BiometricBatcher`), since both will manifest under realistic conditions (channel down at app start, or transient gRPC throw on first send).
