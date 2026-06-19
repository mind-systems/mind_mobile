# Code Review: Biometric-stream readiness gate (plan 46)

## Scope reviewed
- `proto/module_biometric_stream.proto` (synced)
- `lib/Core/Grpc/generated/module_biometric_stream.pb.dart`, `.pbgrpc.dart`, `.pbjson.dart` (regenerated)
- `lib/Biometrics/BiometricStreamClient.dart` (the gate)

## Verification performed
- **Proto sync is verbatim.** `diff mind_api/proto/module_biometric_stream.proto mind_mobile/proto/module_biometric_stream.proto` → IDENTICAL. The mobile copy was not hand-edited; it matches the single source of truth. `BioStreamReady { max_samples_per_second=1; timestamp=2 }` and the `BioStreamReady ready = 3` oneof arm are present.
- **Generated stubs are consistent.** `BioStreamResponse_Event` enum is now `{ ack, error, ready, notSet }` with tag map `{1:ack, 2:error, 3:ready, 0:notSet}`, and `BioStreamResponse` exposes `ready` getter/`ensureReady()`. The `whichEvent()` switch in the client covers all four arms — exhaustive, no compile break.
- **Sole consumer.** `BiometricStreamClient.dart` is the only non-generated file switching on `BioStreamResponse_Event`, so the added enum value cannot break a non-exhaustive switch elsewhere.

## Correctness analysis (no defects found)
Traced the readiness/teardown state machine across the relevant edge cases:

- **Gate re-arms per sink generation.** `_sink` only becomes non-null in `_ensureSinkOpen`, which sets `_isReady = false` immediately before. `_isReady` only flips true via (a) the `ready` frame on the current sink, or (b) the 5 s fallback timer for the current sink. Therefore any state where `_sink != null && _isReady` reflects *this* sink's genuine readiness — never a stale carry-over. No batch is ever pushed to a sink the server has not subscribed to.
- **Stale `_isReady` after teardown is harmless.** `_teardownSink()` nulls `_sink` but leaves `_isReady` true. This is safe because `_encodeAndAdd` checks `_sink == null` *before* the `!_isReady` branch, so samples buffer to the replay ring whenever the sink is gone — including during the 2 s reopen cooldown, where `_ensureSinkOpen` returns early before resetting `_isReady`.
- **Timer lifecycle is leak-free.** Exactly one `_readyTimer` exists per open. It is cancelled in the `ready` arm, in `_teardownSink()` (reached from `onError`, `onDone`, and the send-failure path), and directly in `dispose()`. The open-failure `catch` calls `_teardownSink` and returns before scheduling a new timer. No timer can fire after its sink is torn down or after dispose.
- **Drain ordering preserved.** Ring is drained as a single ordered list into one batch; `_isReady = true` is set before the drain in both the `ready` arm and the fallback, so the drained samples take the encode-and-send path rather than re-queuing.
- **No duplicate sends across reconnect.** The ring holds backlog while `!_isReady`; ready drains it once and clears it. A late `ready` after a fallback drain re-drains an empty ring (no-op).

## Notes (non-blocking — design decisions, not defects)
1. **Shared 75-cap ring serves double duty.** The replay ring is now both the reconnect/send-failure backlog *and* the pre-ready buffer. On a reconnect where backlog already partially fills the ring, new pre-ready inflow shares the same 75-slot drop-oldest budget, so a reconnect under high sample rate can drop slightly more than either case alone. This is exactly what the plan/spec (note 115 §gate, "reusing the bounded drop-oldest ring, max 75, as the pre-ready buffer ... acceptable given the low cost") prescribes. Flagged only for visibility.
2. **Minor duplication.** The `_sink == null` and `!_isReady` branches in `_encodeAndAdd` are identical (enqueue-all + return) and could collapse to `if (_sink == null || !_isReady)`. Pure style; current form is also clear.

## Conclusion
The change faithfully implements the plan and spec: gate re-armed on every open, drain deferred to the `ready` handler, pre-ready samples routed to the bounded ring, 5 s fallback against un-upgraded servers, cooldown and ring cap unchanged, no eager-open, all logging via `logPrint`. No correctness, security, or runtime-break issues found.

REVIEW_PASS
