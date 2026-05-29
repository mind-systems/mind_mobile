# Plan: Implement `BiometricBatcher`

## Context
Adds the buffering stage of the biometric stream pipeline between `BioStreamRouter` (sample producer) and `BiometricStreamClient` (gRPC sink). The batcher flushes on size (25 samples) or a 250 ms timeout, whichever fires first. No backpressure logic — the client owns drop/replay decisions.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Implement BiometricBatcher

- [x] **Task 1: Create `BiometricBatcher` class**
  Files: `lib/Biometrics/BiometricBatcher.dart`
  Create a new file with a single `BiometricBatcher` class that buffers `BioSample`s from `BioStreamRouter` and forwards them to `BiometricStreamClient`. Constructor signature: `BiometricBatcher({required BioStreamRouter router, required BiometricStreamClient client})`. Inject dependencies via constructor only — per `.ai-factory/RULES.md` rule #3 the class manages its own subscription. Match the existing file style of `BiometricStreamClient.dart` / `BioStreamRouter.dart`: dartdoc comment block at the top referencing `.ai-factory/notes/28-biometric-stream-pipeline.md` "Milestone 8", `// ── Section ──` separators for grouping members.

  Required members:
  - `static const int _maxBatchSize = 25;`
  - `static const Duration _flushInterval = Duration(milliseconds: 250);`
  - `final BioStreamRouter _router;`
  - `final BiometricStreamClient _client;`
  - `final List<BioSample> _buffer = [];`
  - `Timer? _flushTimer;`
  - `StreamSubscription<BioSample>? _sub;`

  Constructor body: assign router/client via initializer list, then subscribe immediately inside the body — `_sub = _router.samples.listen(_onSample);`. This honors the router's register-before-subscribe invariant documented in `BioStreamRouter.samples` (App.initialize() will register all sources before constructing the batcher in Milestone 9).

  Imports: `dart:async`, then local imports `BioSample.dart`, `BioStreamRouter.dart`, `BiometricStreamClient.dart` (relative — same directory, mirroring how `BioStreamRouter.dart` imports its siblings).

- [x] **Task 2: Implement `_onSample` per-sample handler**
  Files: `lib/Biometrics/BiometricBatcher.dart`
  Add `void _onSample(BioSample sample)`:
  1. Append the sample to `_buffer`.
  2. If `_buffer.length >= _maxBatchSize`, call `_flushNow()` and return early.
  3. Otherwise, start a one-shot timer only if none is pending: `_flushTimer ??= Timer(_flushInterval, _flushNow);`.

  Do not reset the timer on every sample — `??=` ensures the first sample of a batch fixes the deadline so the last sample is not delayed past 250 ms.

- [x] **Task 3: Implement `_flushNow` flush handler**
  Files: `lib/Biometrics/BiometricBatcher.dart`
  Add `void _flushNow()`:
  1. Early-return when `_buffer.isEmpty` (covers both the timer-fires-after-cancel race and the dispose-with-empty-buffer case).
  2. Snapshot the buffer with `List<BioSample>.unmodifiable(_buffer)` (matches the spec verbatim; gives the client an immutable view).
  3. Clear `_buffer`.
  4. Cancel the pending timer and null it out: `_flushTimer?.cancel(); _flushTimer = null;` — must happen even when `_flushNow` is invoked by the timer itself, so the next `_onSample` re-arms a fresh timer.
  5. Call `_client.sendBatch(snapshot)` (fire-and-forget; the client silently drops if there is no active session or it is paused).

- [x] **Task 4: Implement `dispose`**
  Files: `lib/Biometrics/BiometricBatcher.dart`
  Add `Future<void> dispose() async`:
  1. `await _sub?.cancel();` and null out `_sub` to stop receiving new samples first (prevents a race where a late sample re-arms the timer after teardown).
  2. `_flushTimer?.cancel(); _flushTimer = null;`.
  3. Call `_flushNow()` as a best-effort final flush of any buffered samples before the underlying stream closes.

  Return type is `Future<void>` to mirror `BiometricStreamClient.dispose()` and to await the subscription cancellation.

<!-- orchestrator-sessions
planner: 75f5e1ac-908c-4bfe-811f-be3893c12b0f
elapsed: 319
implementer: f5be1679-18c2-46ae-a1e7-f1a494eba73f
-->
