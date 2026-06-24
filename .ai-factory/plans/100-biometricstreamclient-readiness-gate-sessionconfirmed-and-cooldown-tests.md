# Test Plan: BiometricStreamClient readiness-gate, sessionConfirmed, and cooldown tests

## Context
`lib/Biometrics/BiometricStreamClient.dart` (the gRPC sink for the biometric pipeline) has zero direct test coverage — `biometric_batcher_test.dart` only exercises the upstream batcher. This plan covers the readiness gate (`_isReady`), the replay ring (cap 75, drop-oldest, in-order drain), session-confirmation gating of `sendBatch`, stream-through-pause, the 2 s reopen cooldown, and the 5 s readiness fallback timer.

## Settings
- Testing: yes
- Logging: minimal
- Docs: no

## Test Command
`/usr/local/bin/flutter test test/Biometrics/biometric_stream_client_test.dart`

## Target Spec File
`test/Biometrics/biometric_stream_client_test.dart`

## Prerequisites (already satisfied — do NOT refactor)
The Test-Infra refactor is already merged: `BiometricStreamClient` exposes injectable `clock` (`DateTime Function()`, default `DateTime.now`) and `readyTimeout` (`Duration`, default 5 s) constructor params (`BiometricStreamClient.dart` lines 61–69). Use them; do not add a second clock or change production code.

## Test Infrastructure Notes (read before writing tasks)

**Constructor under test** (lines 61–82):
```dart
BiometricStreamClient(
  grpcStub: <fake>,
  moduleStateEvents: lifecycleController.stream,
  connectionState: connectionController.stream,
  clock: () => fakeNow,            // drive the 2 s cooldown deterministically
  readyTimeout: const Duration(milliseconds: 10), // shorten the fallback timer
)
```

**Fakes the implementer must build:**
- **Fake gRPC stub** (`$bio.ModuleBiometricStreamServiceClient`): `streamData(Stream<BioSampleBatch> input)` returns `$grpc.ResponseStream<BioStreamResponse>` (generated client line 36). Build a `_FakeStub implements ModuleBiometricStreamServiceClient` whose `streamData` returns a `_FakeResponseStream implements $grpc.ResponseStream<BioStreamResponse>` that delegates `listen` to an internal `StreamController<BioStreamResponse>` (use `noSuchMethod` for the unused `ResponseStream` members — headers/trailers/cancel). Expose:
  - a getter to inject server frames (`add(BioStreamResponse)`) — emit `ready`, `ack`, `error`, and trigger `onError`/`onDone`;
  - a counter/list capturing how many times `streamData` was called (to assert reopen/cooldown behavior);
  - a captured reference to the input `Stream<BioSampleBatch>` (the outbound sink stream) so a test can subscribe and assert what was sent.
- **Lifecycle stream**: `StreamController<ModuleStateEvent>.broadcast()` — emit `ModuleSessionStarted(moduleSessionId: ...)`, `ModuleSessionResumed(...)`, `ModuleSessionPaused()`, `ModuleSessionEnded()`, `ModuleSessionAbandoned()` (`ModuleStateEvent.dart`).
- **Connection stream**: `StreamController<GrpcConnectionState>.broadcast()` — emit `connected` / `disconnected` / `connecting`.
- **BioSample helper**: `BioSample(timestampMs: n, sampleType: 'rr', data: const {})` (matches `biometric_batcher_test.dart` `_sample` helper).

**Timing:** Use `fakeAsync` + an injected `clock` closure (over a mutable `fakeNow` variable advanced alongside `async.elapse`) exactly as `biometric_batcher_test.dart` does. After emitting on a `StreamController`, run `async.flushMicrotasks()` (or `await Future<void>.delayed(Duration.zero)` in async tests) before asserting, because lifecycle/connection/response subscriptions are async.

**Asserting "passed through to the sink":** Subscribe to the captured outbound input stream and collect `BioSampleBatch` messages; assert `batch.samples` length / `sessionId` / `timestamp` order. Samples buffered to the replay ring are NOT emitted on the sink until drain — that's the key distinction the tests assert.

**Reading private state:** `_isReady`, `_replayRing`, `_currentSessionId`, `_sessionConfirmed`, `_lastOpenAttempt` are private. Do NOT reach into them — assert behavior through observable effects only (what reaches the sink, whether `streamData` is re-called, whether a warning is logged).

**Cap constant:** `_replayRingMax = 75` (line 34).

## Tasks

### Phase 1: Session-confirmation gate on `sendBatch`

- [x] **Task 1: `sendBatch` session-liveness gate**
  Files: `test/Biometrics/biometric_stream_client_test.dart`
  Source: `sendBatch` lines 110–115 (`if (_currentSessionId == null || !_sessionConfirmed) return;` and empty-list guard); `_onLifecycleEvent` lines 86–106.
  Test cases:
  - `should be a no-op when no session has started` — before any lifecycle event, `sendBatch([sample])` opens no stream (`streamData` never called) and emits nothing on the sink.
  - `should send after ModuleSessionStarted confirms the session` — emit `ModuleSessionStarted(moduleSessionId: 's1')`, drive ready, then `sendBatch([sample])` reaches the sink.
  - `should be a no-op with an empty sample list when a session is confirmed` — after `ModuleSessionStarted`, `sendBatch([])` opens no stream and sends nothing.
  - `should drop sendBatch after disconnect clears session confirmation` — start + confirm session, emit `GrpcConnectionState.disconnected`, then `sendBatch([sample])` is a silent no-op even though a session id was previously set (lines 75–77 set `_sessionConfirmed = false`).
  - `should re-confirm and pass through on ModuleSessionResumed after a disconnect` — start → disconnect (drops sends) → `ModuleSessionResumed(moduleSessionId: 's1')` → `sendBatch([sample])` now reaches the sink (lines 92–95).

### Phase 2: Stream-through-pause

- [x] **Task 2: pause does not gate sends**
  Files: `test/Biometrics/biometric_stream_client_test.dart`
  Source: `_onLifecycleEvent` `ModuleSessionPaused()` / `ModuleSessionUnpaused()` are no-ops (lines 96–99); `sendBatch` gate has no pause check (line 111).
  Test cases:
  - `should keep sending while paused` — start + confirm session, drive ready, emit `ModuleSessionPaused()`, then `sendBatch([sample])` still reaches the sink (pause no longer gates sends — note 123).
  - `should keep sending after unpause` — after a pause/unpause pair, `sendBatch([sample])` reaches the sink.

### Phase 3: Readiness gate (`_isReady`) and replay-ring drain

- [x] **Task 3: pre-ready buffering and in-order drain on `ready`**
  Files: `test/Biometrics/biometric_stream_client_test.dart`
  Source: `_encodeAndAdd` buffers when `_sink == null` or `!_isReady` (lines 199–213); `ready` branch drains the ring then clears it (lines 151–157).
  Test cases:
  - `should buffer samples to the replay ring while the stream is open but not ready` — start + confirm session (sink opens via cooldown path), `sendBatch([s1, s2, s3])` before any `ready` frame → nothing is emitted on the sink yet.
  - `should drain the buffered ring in FIFO order when the server emits ready` — after buffering `s1, s2, s3`, inject a `BioStreamResponse.ready` frame → all three are emitted on the sink, in original order (assert `timestampMs` order across drained batch[es]).
  - `should send directly to the sink once ready` — after `ready`, a subsequent `sendBatch([s4])` reaches the sink immediately without buffering.
  - `should not re-send drained samples` — buffer → `ready` (drain) → `sendBatch([s4])`; only `s4` appears after the drain (ring was cleared at line 156, so no duplicate `s1..s3`).

- [x] **Task 4: `_isReady` re-arms on every `_ensureSinkOpen` (reconnect re-gates)**
  Files: `test/Biometrics/biometric_stream_client_test.dart`
  Source: `_isReady = false` set on every open (line 140); teardown on `disconnected` (lines 75–76, `_teardownSink` lines 188–195); reopen on `connected` (lines 73–74).
  Test cases:
  - `should re-gate after reconnect so post-reconnect samples buffer until a new ready` — start + confirm → `ready` → send flows; then `disconnected` (tears down sink) → `ModuleSessionResumed` (re-confirm + reset cooldown) → advance `clock` past 2 s → `sendBatch([s])` opens a fresh stream but, with no new `ready`, the sample is buffered (not sent) until a second `ready` frame drains it.

### Phase 4: Replay-ring bound (cap 75, drop-oldest)

- [x] **Task 5: bounded drop-oldest replay ring**
  Files: `test/Biometrics/biometric_stream_client_test.dart`
  Source: `_enqueueReplay` drops the oldest when `length >= _replayRingMax` (75) (lines 236–241); drain order observed on `ready`.
  Test cases:
  - `should retain exactly 75 samples and drop the oldest when over capacity` — while open-but-not-ready, buffer 76 samples (`timestampMs` 1..76), then emit `ready` → exactly 75 samples drain and the first one (ts `1`) is absent; oldest-retained is ts `2`, newest is ts `76`.
  - `should preserve FIFO order of the retained window after dropping` — drained samples are ts `2..76` in ascending order.

### Phase 5: Reopen cooldown (2 s, clock-injectable)

- [x] **Task 6: 2-second reopen cooldown**
  Files: `test/Biometrics/biometric_stream_client_test.dart`
  Source: `_ensureSinkOpen` cooldown guard (lines 131–138): returns early if `_sink != null`; otherwise rejects reopen when `clock().difference(_lastOpenAttempt) < 2 s`; records `_lastOpenAttempt = clock()`. Cooldown reset on session start/resume (lines 91, 95).
  Test cases:
  - `should open the stream on the first send without cooldown delay` — confirmed session + first `sendBatch` calls `streamData` exactly once.
  - `should not reopen within 2 s of a teardown` — open the stream, tear it down (emit `disconnected`), advance `clock` by 0.5 s, emit `connected` (or `sendBatch`) → `streamData` is NOT called again (still within cooldown). Assert `streamData` call count unchanged.
  - `should allow reopen after 2 s have elapsed` — same setup, advance `clock` by ≥ 2 s, then trigger open → `streamData` is called again.
  - `should reset the cooldown on ModuleSessionStarted/Resumed` — tear down inside the cooldown window, then emit `ModuleSessionStarted` (clears `_lastOpenAttempt`), then `sendBatch` → stream reopens immediately despite < 2 s elapsed.

### Phase 6: Readiness fallback timer (5 s)

- [x] **Task 7: fallback timer auto-drains the ring and warns**
  Files: `test/Biometrics/biometric_stream_client_test.dart`
  Source: fallback timer armed with `_readyTimeout` (lines 177–185): on fire, if `!_isReady` logs `'[BiometricStreamClient] readiness timeout — draining without server ready'`, forces `_isReady = true`, and drains the ring. Use a short injected `readyTimeout` (e.g. 10 ms) under `fakeAsync`.
  Test cases:
  - `should auto-drain the replay ring when no ready arrives within readyTimeout` — open stream, buffer `s1, s2`, advance `async.elapse(readyTimeout)` with no `ready` frame → both samples drain to the sink.
  - `should send directly after the fallback fires` — after the timeout fires, a subsequent `sendBatch([s3])` reaches the sink immediately (gate forced open).
  - `should log a readiness-timeout warning when the fallback fires` — capture `logPrint` output (via the project's log capture harness used by other tests, or a `runZoned`/`logPrint` spy) and assert the `'readiness timeout — draining without server ready'` message is logged once.
  - `should NOT fire the fallback when ready arrives first` — open stream, inject `ready` before `readyTimeout`, then `async.elapse` past the timeout → no timeout warning is logged and no double-drain occurs (timer cancelled at lines 153–154; the late timer body is also guarded by `if (!_isReady)`).
