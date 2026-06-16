# Probe/ACK: Instruction Stream Readiness Gate

**Date:** 2026-06-05
**Source:** conversation context — deep investigation of `rest` instruction loss

## Decision (2026-06-16)

The fix is now two-part, and this probe/ACK design is half of it:

- **Cold start** is handled by **opening all data tunnels eagerly at connect** (instruction + biometric), mirroring the control tunnel. By the time the first sample flows, the server has long since subscribed — the same reason the control tunnel never races. This removes the need for the probe to carry the cold-start case alone.
- **Reconnect mid-session** is what the probe/ACK gate below primarily protects: on re-open the buffer would otherwise flush immediately into a not-yet-subscribed tunnel. The readiness ACK holds the flush until the server confirms it is subscribed.
- The same race exists on the **biometric** tunnel (`BiometricStreamClient` opens lazily and replays its ring on open). Apply eager-open there too; the readiness gate is optional for biometrics since losing a first batch is far cheaper than losing the one-shot `rest`.

**Still gated on the log verification** in `mind_api/.ai-factory/notes/44`: if early frames are dropped before `request.subscribe()`, the probe itself can be lost (deadlock) and eager-open can still race on a fast cold start — then the foundation must be server-side. Confirm the log before building.

The probe/ACK mechanism below is unchanged and remains correct for the reconnect path.

## Key Findings

- The gRPC instruction stream is opened lazily on the first `emit()` call. The first message sent is always lost because the NestJS server runs async JWT auth before calling `request.subscribe()` — the first DATA frame arrives before the Subject has a subscriber.
- Fix: send a lightweight `stream_ready` probe as the very first message. Buffer all real instructions until the probe's ACK comes back. ACK proves the server has called `request.subscribe()` and is ready.
- Three previous implementation attempts failed; each failure mode is documented below with the exact guard to avoid repeating it.
- **Deploy order is mandatory: server first, then mobile.** Mobile-first means probe gets rejected as `INVALID_ARGUMENT`, `_streamReady` never becomes true, all instructions stuck in buffer forever.

## Details

### Root Cause

`ModuleInstructionStream._openStream()` currently ends with `_readyController.add(null)`. This synchronously fires `flushBuffer()` in `BreathModuleInstructionStream` — before the server has subscribed. The first real sample added to `_streamSink` is the very first HTTP/2 DATA frame the server sees. NestJS's async JWT interceptor is still running at this point; `request.subscribe()` has not been called; the Subject has no subscriber; the frame is dropped silently.

### Changes — Server Side (deploy first)

**`mind_api/src/realtime/constants/stream-data-types.ts`**
```typescript
export const StreamDataType = {
  SESSION_EVENT: 'session_event',
  BREATH_PHASE: 'breath_phase',
  STREAM_READY: 'stream_ready',   // ← add this
} as const;
```

**`mind_api/src/realtime/module-instruction-stream.grpc.controller.ts`**

Inside the `next` handler, add as the **absolute first check** — before `!msg.sessionId`, before `getActiveSession()`, before everything:

```typescript
if (msg.instructionType === StreamDataType.STREAM_READY) {
  subscriber.next({
    ack: {
      sessionId: msg.sessionId,
      receivedCount: 0,
      droppedCount: 0,
      maxSamplesPerSecond: this.streamEngine.maxSamplesPerSecond,
      timestamp: Date.now(),
    },
  });
  return;
}
```

**Why first:** the probe has no `sessionId` (empty string from proto default). Any guard before this — `!msg.sessionId`, `!session`, `session.sessionId !== msg.sessionId` — will reject the probe and return an error. The mobile receives the error response but does not set `_streamReady = true`. Deadlock.

### Changes — Mobile Side (deploy second)

**`lib/Core/Grpc/ModuleInstructionStream.dart`**

Add field and getter:
```dart
bool _streamReady = false;
bool get isStreamReady => _streamReady;
```

In `GrpcConnectionState.disconnected` handler, add `_streamReady = false;` before the existing cancel/null lines.

Split `emit()` — extract stream-open logic to a new public `openStream()`:
```dart
void emit(InstructionSample sample) {
  if (_streamSink == null) {
    if (!_isGrpcConnected) {
      log('[ModuleInstructionStream] not connected, dropping sample', name: 'ModuleInstructionStream');
      return;
    }
    openStream();
  }
  _streamSink!.add(_toProto(sample));
}

/// Opens the gRPC stream and sends the readiness probe.
/// No-op if stream already open or gRPC disconnected.
void openStream() {
  if (_streamSink != null || !_isGrpcConnected) return;
  _streamRequested = true;
  _openStream();
}
```

In `_openStream()`:
- Add `_streamReady = false;` at the top (before creating `_streamSink`)
- Remove `_readyController.add(null);` from the END of the method
- In the ACK case inside `response.listen(...)`, add before the existing ack forwarding:
  ```dart
  if (!_streamReady) {
    _streamReady = true;
    _readyController.add(null);  // fires flushBuffer() in BreathModuleInstructionStream
  }
  ```
- In `onError`: add `_streamReady = false;` before `_streamRequested = false;`
- In `onDone`: add `_streamReady = false;` before `_streamRequested = false;`
- At the **END** of `_openStream()`, after `response.listen(...)` returns, send the probe:
  ```dart
  _streamSink!.add(StreamSample(instructionType: 'stream_ready'));
  ```

**`lib/BreathModule/Core/BreathModuleInstructionStream.dart`**

In `_canSendNow()`, add after the gRPC connected check:
```dart
if (!_instructionStream.isStreamReady) return false;
```

In `sendSample()`, in the `else` (buffer) branch, add after `_buffer.enqueue(payload)`:
```dart
_instructionStream.openStream();
```

**Why `openStream()` must be called from the buffer path:**
`_canSendNow()` returns false when `!isStreamReady` → item goes to buffer → `emit()` is never called → `_openStream()` is never called → probe is never sent → `isStreamReady` never becomes true → buffer never flushes. Deadlock. The `openStream()` call in the buffer path is what breaks the deadlock.

**Why `_readyController.add(null)` must be in the ACK handler, not end of `_openStream()`:**
If fired at end of `_openStream()`, `flushBuffer()` runs synchronously before the server has subscribed. The first real sample becomes the first DATA frame — same race condition as before, just shifted by one frame. Only an ACK proves the server is ready.

### Full Flow After Fix

```
User presses play
  → rest detected (phaseChanged = true, from null)
  → _canSendNow() → isStreamReady = false → false
  → rest buffered
  → _instructionStream.openStream() called
  → _openStream():
      _streamSink = StreamController()
      response = streamData(_streamSink.stream)
      response.listen(...)
      _streamSink.add(StreamSample(instructionType: 'stream_ready'))  ← probe
  Server receives new streamData call
    → async JWT auth completes → request.subscribe() called
    → receives 'stream_ready' DATA frame
    → STREAM_READY check (first in handler) → subscriber.next({ack: ...})
  Mobile receives ACK
    → _streamReady = true
    → _readyController.add(null) → flushBuffer()
    → rest emitted → _streamSink.add(restProto)
  Server receives rest → NO_SESSION guard checks sessionId → pushed to StreamEngine
T+15s: inhale sent → _canSendNow() = true (isStreamReady = true) → direct emit
T+20s: exhale → direct emit
```

### Deployment Order

1. `mind_api`: deploy server changes, restart
2. `mind_mobile`: deploy mobile changes, rebuild app

Never swap: mobile-first means probe gets `INVALID_ARGUMENT` from the server (no STREAM_READY handler yet), mobile receives error response but does NOT set `_streamReady = true`, all instructions stay buffered, nothing reaches DB.

### Verification

After deploying both sides, run a breath session and check:

**Server logs** (debug level must be on):
```
recv: sessionId=undefined type=stream_ready phase=- moduleId=undefined
recv: sessionId=<id> type=breath_phase phase=rest ...
pushed: sessionId=<id> type=breath_phase phase=rest accepted=true total=2
```

**DB** (`session_stream_samples`):
The row containing `session_started` must also contain `rest` (same 5s flush batch).
`rest.durationMs` should be `15000` (positive) — if still `-15`, see note `100` for the separate `currentIntervalMs=-1` sentinel fix.

**Mobile logs**:
```
[ModuleInstructionStream] stream ready
```
should appear before any `sending <phase>` log.

## Open Questions

- After a mid-session gRPC disconnect and reconnect, `_streamReady` is reset to false (in the `disconnected` handler). The next instruction sent will buffer and re-trigger `openStream()`. This should work correctly, but has not been tested with a real disconnect scenario.
- The `stream_ready` probe is not stored in `session_stream_samples` — it returns an ACK without pushing to `StreamEngine`. Correct by design.
