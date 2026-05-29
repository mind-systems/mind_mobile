# Plan Review: Implement `BiometricStreamClient`

**Plan:** `.ai-factory/plans/69-implement-biometricstreamclient.md`
**Files Reviewed:** 1 plan file + cross-referenced codebase (`ModuleInstructionStream.dart`, `BioSample.dart`, `BioStreamRouter.dart`, generated `module_biometric_stream.pb.dart` / `.pbgrpc.dart`, `ModuleStateChannel.dart`, `ModuleStateEvent.dart`, `GrpcClient.dart`, RULES.md, note 28)

**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`ARCHITECTURE.md`)** — WARN: Not consulted in this review for the section on `lib/Biometrics/` pipeline placement, but plan defers cross-cutting wiring (App.dart, GrpcClient) to next milestone, which matches the rule "App.dart is infrastructure only" and avoids module-specific state leaking outside the file under construction. No violations identified.
- **Rules (`RULES.md`)** — PASS:
  - "All dependencies must be injected via constructor" — honored (`grpcStub`, `moduleStateEvents` both required).
  - "Module Services must be stateless" — not applicable; `BiometricStreamClient` is a domain-layer sink, not a module-package `IXxxService` implementation.
  - "Never add module-specific state to App.dart" — this milestone touches no App.dart code; wiring is explicitly deferred.
- **Roadmap (`ROADMAP.md`)** — WARN: Plan does not reference a roadmap milestone ID; note 28 §Milestone 7 is the canonical reference and is cited. Acceptable given the project layers tasks via the notes/ directory rather than tracker IDs.

## Cross-Reference Verification

- Constructor signature, fields list, lifecycle event handler, replay ring constants (`_replayRingMax = 75`), and gating semantics match note 28 §Milestone 7 verbatim.
- Generated stub names in plan (`BioSample`, `BioSampleBatch`, `BioStreamResponse`, `BioStreamResponse_Event`, `ModuleBiometricStreamServiceClient`, `streamData(Stream<BioSampleBatch>)`) all match `lib/Core/Grpc/generated/module_biometric_stream.pb.dart` / `.pbgrpc.dart` exactly. (Note 28's `BioStreamRequest` / `BioSampleProto` placeholder names are correctly normalized to the actual generated names.)
- Import path `package:protobuf/well_known_types/google/protobuf/struct.pb.dart` confirmed in use by `ModuleInstructionStream.dart:5` and both generated `*pb.dart` files — correct.
- `ModuleStateEvent` is sealed; the four/five-case switch (with `Started`/`Paused`/`Unpaused`/`Ended`/`Abandoned`) is exhaustive over the actual hierarchy in `lib/Core/Grpc/ModuleStateEvent.dart` — correct, and Dart's sealed-switch exhaustiveness check will enforce it at compile time.
- `ModuleSessionStarted.moduleSessionId` is `String?`, plan correctly notes nullability and routes through the same null-guard as missing-session — correct.
- `BioSample` (domain) is the file's local class; `BioSample` (proto) is imported under `$bio` prefix — the alias strategy correctly resolves the name collision.
- `BioSample.data` is `Map<String, dynamic>` and contains only `String`/`num`/`bool`/`Map`/(`String`-keyed) sub-maps for every factory in `BioSample.dart` — all paths through `_valueFrom` are exercised; no `List` values today but the helper handles them. No type would hit the `ArgumentError` branch given current factories.
- Plan's response-stream `onError` deliberately does NOT clear `_replayRing` — correct: this is the whole point of the ring, samples should survive a stream-level failure within an active session.

## Critical Issues

None — the plan is implementable as written and the public contract matches the note and downstream `BiometricBatcher` consumer.

## Medium Issues

### M1 — Drain re-entry: `_ensureSinkOpen` may leave `_sink` null before `sendBatch` calls `_encodeAndAdd` on the user batch

**Sequence (per Tasks 4 + 5):**
1. `sendBatch` → `_ensureSinkOpen()` opens a new sink, subscribes to the response stream, then drains the replay ring by calling `_encodeAndAdd(replay)`.
2. If `_sink!.add(batch)` during the drain throws (e.g. controller was synchronously closed by an early-fire `onError` on the response stream while we were in this microtask), Task 5's catch path calls `_teardownSink()`, which nulls `_sink`.
3. Control returns to `sendBatch`, which now calls `_encodeAndAdd(samples)` for the user-supplied batch. The `_sink!.add(batch)` inside dereferences a null `_sink` → throws `TypeError: Null check operator used on null value`.

The catch in `_encodeAndAdd` does swallow that null-check error and re-enqueues the user batch, so the user batch is NOT lost. But the path is noisy (two exceptions per send), and it relies on the catch as a silent safety net rather than explicit handling.

**Recommendation:** Pick one of:
- Add a `_sink == null` early-return-and-enqueue guard at the top of `_encodeAndAdd` (after capturing `sessionId`).
- Move the drain out of `_ensureSinkOpen` into `sendBatch`, gated on `_sink != null` after the ensure call.

This is the only finding I'd ask the implementer to resolve before merging.

## Minor / Nits

### N1 — Synchronous failure of `_grpcStub.streamData(...)` not addressed

If the underlying channel is shut down, `streamData()` may throw synchronously inside `_ensureSinkOpen`, which would propagate up through `sendBatch` to `BiometricBatcher._flushNow()` (the next-milestone caller). The plan handles failures *on the response stream*, but not failures from the call site itself. Worth a one-line note in the implementation to wrap `streamData(...)` in try/catch and treat a synchronous throw the same as `onError` (teardown, samples remain in caller, next send retries).

### N2 — No `GrpcConnectionManager.connectionState` subscription — call out the consequence more explicitly

Plan already explains the omission in Task 4. The trade-off is that the only reconnect trigger is the response stream's `onError`/`onDone` combined with the *next* `sendBatch` re-opening lazily. If the channel is down and no new sends happen (pause, ended), the ring just sits at ≤75 samples until the next start/unpause cycle ships them. This is fine semantically (paused/ended sessions don't want shipping) but worth a code comment so a future maintainer doesn't add a redundant connection-state subscription.

### N3 — `_currentSessionId` re-check in `_encodeAndAdd` is defensively dead code in current Dart

The plan instructs: "Capture `final sessionId = _currentSessionId;` at the top — if it became null between the public check and here (lifecycle event interleaving), return early." In single-threaded Dart, no lifecycle event handler can interleave between two synchronous statements in `sendBatch`. The re-check is harmless but worth a comment marking it as defensive (or dropping it). Not a bug.

### N4 — `BioStreamResponse_Event.notSet` switch arm uses `break` per the plan

That mirrors `ModuleInstructionStream.dart:119–120` exactly. Dart 3 sealed-switch arms don't require `break`, but copying the existing house style is the right call.

### N5 — Replay drain semantics with respect to session ID stability

Plan's drain re-tags every replay sample with whatever `_currentSessionId` is at drain time. This is correct ONLY because `ModuleSessionEnded`/`Abandoned` clears the ring — so if the ring has any samples at drain time and `_currentSessionId != null`, it must still be the original session that buffered them. The lifecycle handler in Task 2 enforces this. Worth a one-line comment on `_enqueueReplay` documenting the invariant.

## Positive Notes

- Plan correctly identifies and resolves the `BioSample` name collision between domain and proto via prefixed import — `$bio` alias is a clean idiom.
- Per-sample replay ring (not per-batch) matches the note's explicit `Queue<BioSample>` spec and avoids unbounded outer-list growth.
- Lifecycle gating semantics (silent drop on no-session / paused; clear ring on ended/abandoned) are faithful to architecture note 26 §7 and symmetric with `ModuleInstructionStream`.
- The single batch wrap (`BioSampleBatch(samples: wireSamples)` once per `sendBatch`) is correct per the proto's stated purpose ("reduce per-message overhead") and is an improvement over note 28's per-sample example (`BioStreamRequest(samples: [wire])` inside the loop).
- The proto conversion helpers are scoped as private instance methods rather than extracted to a shared util — correct call; line count is small and the next milestone is not the time for that refactor.
- Drain ordering (replay first, then new samples) preserves chronological order across reconnect boundaries.
- Plan explicitly chooses NOT to clear the ring on `onError` — correct, this is the point of the ring.
- File-level dartdoc task (Task 7) is appropriately scoped: short, references the canonical note.

## Verdict

The plan implements milestone 7 of note 28 faithfully and is internally consistent with the existing `ModuleInstructionStream` patterns. Finding **M1** (drain re-entry leaving `_sink` null) should be resolved in implementation — either by adding a null-guard at the top of `_encodeAndAdd` or by moving the drain out of `_ensureSinkOpen`. The other findings are nits and code-comment requests.

PLAN_REVIEW_PASS
