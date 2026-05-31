# Task Spec — Rate-limit `BiometricStreamClient` stream reopen

**Date:** 2026-05-31
**Roadmap:** ROADMAP.md Phase 26
**Provenance:** note 42 Task 3 (note 40 Area F); relates to note 43 Q4

## Current state
`lib/Biometrics/BiometricStreamClient.dart`: `sendBatch` (every ≤250 ms during a session) calls `_ensureSinkOpen()` at the top; after `onError`/`onDone` tears the sink down, the next batch reopens `streamData` immediately — during a server/transport outage this thrashes reconnect every 250 ms with no cooldown.

## Target
- Add field `DateTime? _lastOpenAttempt;`.
- In `_ensureSinkOpen()`, before creating a new `StreamController`: if `_lastOpenAttempt != null && DateTime.now().difference(_lastOpenAttempt!) < const Duration(seconds: 2)` → `return` without opening (samples then enqueue to the replay ring via the existing `_sink == null` branch in `_encodeAndAdd`).
- Set `_lastOpenAttempt = DateTime.now()` when an open is attempted.
- Keep the existing replay-ring drain on a successful open.
- `DateTime.now()` is correct here — wall-clock retry control, not a sample timestamp.

## Guards / notes
- Conservative version only — the larger "ride on `GrpcConnectionManager` backoff" alternative stays in note 43 (Q4).
- **Tradeoff:** the cooldown does NOT cause sample loss. During any outage the stream can't send regardless, so samples overflow the bounded replay ring (75; ~125 lost over a 2 s outage at 25 samples/250 ms) whether or not a cooldown exists. Loss = `outage_duration × sample_rate` vs ring size, identical under the Q4 alternative. If these samples matter, size `_replayRingMax` to the worst-case outage (e.g. a few seconds of MEMS motion) — separate from this task.

## Files
- `lib/Biometrics/BiometricStreamClient.dart` (one file).
