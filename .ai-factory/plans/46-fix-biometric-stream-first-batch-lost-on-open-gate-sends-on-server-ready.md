# Plan: Fix biometric-stream first batch lost on open — gate sends on server `ready`

## Context
Stop the first biometric batch being dropped on every fresh/reconnected stream by gating all outbound batches (and the replay-ring drain) on the server `ready` frame instead of local stream open, re-armed on each `_ensureSinkOpen`. Mirrors the instruction-tunnel fix (note 114) but with low data-loss cost.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Proto sync

- [x] **Task 1: Sync biometric proto and regenerate Dart stubs**
  Files: `proto/module_biometric_stream.proto`, `lib/Core/Grpc/generated/module_biometric_stream.pb.dart` (generated), `lib/Core/Grpc/generated/module_biometric_stream.pbgrpc.dart` (generated)
  The mind_mobile copy of `proto/module_biometric_stream.proto` still lacks the readiness frame; the source of truth (`mind_api/proto/module_biometric_stream.proto`) already defines it. Copy the updated `mind_api/proto/module_biometric_stream.proto` into `mind_mobile/proto/` verbatim (do **not** edit the proto by hand — `mind_api/proto/` is the single source of truth). This adds the `BioStreamReady` message (`int32 max_samples_per_second = 1; int64 timestamp = 2;`) and a third oneof arm `BioStreamReady ready = 3;` on `BioStreamResponse`. Then run `./scripts/gen_proto.sh` to regenerate all Dart stubs. Verify the regenerated `module_biometric_stream.pb.dart` now exposes `BioStreamResponse_Event.ready` and a `BioStreamReady` message type with `ready` getter on `BioStreamResponse`. Do not touch any other `.proto` files.

### Phase 2: Readiness gate in BiometricStreamClient

- [x] **Task 2: Add readiness state and defer the replay-ring drain to the `ready` handler** (depends on Task 1)
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  Add `bool _isReady = false;` and a fallback-timer field `Timer? _readyTimer;` alongside the existing `_sink` / `_responseSub` / `_lastOpenAttempt` fields (import `dart:async` already present). In `_ensureSinkOpen()`, immediately after assigning the new `_sink` (before/around the `streamData` call), set `_isReady = false` so the gate re-arms for both cold-start and reconnect. **Remove** the existing post-open replay drain block at the end of `_ensureSinkOpen` (the `if (_currentSessionId != null) { final replay = _replayRing.toList(); ... }`) — the drain now happens only in the `ready` handler (Task 3). Keep the 2-second reopen cooldown (`_lastOpenAttempt`) and the replay-ring cap (`_replayRingMax = 75`) unchanged. Do not implement eager-open.

- [x] **Task 3: Handle the `ready` frame, drain on ready, and add the fallback timeout** (depends on Task 2)
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  In the `_responseSub` switch on `r.whichEvent()`, add a `case $bio.BioStreamResponse_Event.ready:` arm that: sets `_isReady = true`, cancels `_readyTimer`, then drains the replay ring into the now-subscribed sink — `final replay = _replayRing.toList(); _replayRing.clear(); if (replay.isNotEmpty) _encodeAndAdd(replay);`. In `_ensureSinkOpen()`, after the stream is opened successfully, start `_readyTimer = Timer(const Duration(seconds: 5), ...)`: if it fires while `!_isReady`, `logPrint('[BiometricStreamClient] readiness timeout — draining without server ready')`, set `_isReady = true`, and drain the replay ring the same way (degrades to current behavior against an un-upgraded server — no deadlock). Cancel `_readyTimer` in the `ready` arm, in `_teardownSink()`, and in `dispose()`. All logging via `logPrint` only.

- [x] **Task 4: Route pre-ready samples to the replay ring in `_encodeAndAdd`** (depends on Task 3)
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  In `_encodeAndAdd(samples)`, after the existing `_sink == null` guard (which already enqueues to replay), add a condition: when `_sink != null` but `!_isReady`, route every sample to `_enqueueReplay(sample)` and return instead of building/adding the batch to the sink. Only build the `BioSampleBatch` and call `_sink!.add(batch)` once `_isReady` is true. This reuses the existing bounded drop-oldest ring (max 75) as the pre-ready buffer — acceptable given the low loss cost. Leave the existing send-failure replay/`_teardownSink` path intact.

## Notes
- Single logical commit (4 tasks): "Gate biometric stream sends on server ready frame".
- Prereq for runtime correctness: `mind_api` note 48 deployed (server emits `BioStreamReady`). The 5 s fallback keeps the client safe if the server has not been upgraded yet.
- Verify (manual): start a session with a biometric source active, force a reconnect mid-session, and confirm the first post-reconnect batch is persisted — no gap at the reconnect boundary in `bio_session_samples` for the `moduleSessionId`.
