# Test Plan: BiometricBatcher and ActiveRrSource tests

## Context
`lib/Biometrics/BiometricBatcher.dart` (buffers `BioSample`s and flushes on size or deadline) and `lib/Biometrics/ActiveRrSource.dart` (preferred-with-fallback RR multiplexer) are silently-failing domain logic with zero test coverage. Both already expose injectable timing seams, so their flush/watchdog behavior can be driven deterministically.

## Settings
- Testing: yes
- Logging: minimal
- Docs: no

## Test Command
`/usr/local/bin/flutter test test/Biometrics/biometric_batcher_test.dart test/Biometrics/active_rr_source_test.dart`

## Target Spec Files
- `test/Biometrics/biometric_batcher_test.dart`
- `test/Biometrics/active_rr_source_test.dart`

## Conventions (from `docs/core/testing.md` and existing tests)
- Use hand-written `Fake*` classes implementing the interface — no mocking libraries.
- A `Fake*` class declared with `implements <ConcreteClass>` must stub **every** public member of that class, not only the ones the test exercises, or the file will not compile. Stub the unused ones minimally (no-op body, or `throw UnimplementedError()`). Specifically: `_FakeBioStreamRouter` must stub all five `register*` methods plus the `samples` getter; `_FakeBiometricStreamClient` must stub `sendBatch` **and** `dispose`.
- Inject streams via `StreamController`; after emitting, `await Future.delayed(Duration.zero)` to let the listener run (broadcast-stream delivery is async).
- `flutter_test` assertions (`expect`, `group`, `test`); name tests `should <behavior> when <condition>`.
- **`fake_async` dependency**: it is currently only a transitive dependency (present in `pubspec.lock` via `flutter_test`). Make it explicit before writing the batcher tests: run `flutter pub add --dev fake_async` (never hand-edit `pubspec.yaml`). Then `import 'package:fake_async/fake_async.dart';`.
- Use `fake_async` **only** for `BiometricBatcher` timer-deadline tests — it has no `timerFactory` seam, so its deadline `Timer` is only controllable through virtual time. `ActiveRrSource` takes `clock` + `timerFactory`, so its watchdog is driven by a captured-callback spy with **no** `fake_async`.

---

## Tasks

### Phase 1: BiometricBatcher — `test/Biometrics/biometric_batcher_test.dart`

**Construction recipe is per-task, not single:**
- **Size & dispose tests (Task 1, Task 4)** run against the real event loop. Use a long, never-firing interval so only the explicit size/dispose path can produce a batch: `BiometricBatcher(router: fakeRouter, client: fakeClient, flushInterval: const Duration(seconds: 10), maxBatchSize: 3)`. A 1 ms interval here is a latent CI flake — `await Future.delayed(Duration.zero)` can let ≥1 ms of wall-clock elapse and fire an unexpected deadline flush.
- **Timer tests (Task 2, Task 3)** run inside `fakeAsync`, which controls virtual time, so the interval value is arbitrary; use `flushInterval: const Duration(milliseconds: 1), maxBatchSize: 3` and construct the SUT **inside** the `fakeAsync` zone. Note: with `fakeAsync`, advance broadcast-stream delivery with `async.flushMicrotasks()` / `async.elapse(...)` instead of `await Future.delayed`.

Fakes:
- `_FakeBioStreamRouter implements BioStreamRouter` — backs `samples` with a `StreamController<BioSample>.broadcast()`; expose an `emit(BioSample)` helper to pump samples. Stub the five `register*` methods (no-op) to satisfy the implicit interface.
- `_FakeBiometricStreamClient implements BiometricStreamClient` — overrides `sendBatch(List<BioSample>)` to append each call's list to a `List<List<BioSample>> batches`; stub `dispose()` (no-op). (Implementing the concrete class via implicit interface mirrors the `switchable_tick_service_test.dart` pattern.)
- Helper to build samples with distinct `timestampMs`, e.g. `BioSample(timestampMs: i, sampleType: 'rr', data: const {})`.

- [x] **Task 1: Size-based flush (`_onSample` reaching `maxBatchSize`)** — construct with `flushInterval: const Duration(seconds: 10)` (never-firing)
  Files: `test/Biometrics/biometric_batcher_test.dart`
  Test cases:
  - `should not flush when buffer has fewer than maxBatchSize samples` (emit 2 of 3 → `client.batches` empty)
  - `should flush immediately when buffer reaches maxBatchSize` (emit 3 → exactly one batch of 3)
  - `should clear buffer after a size flush` (emit 3 → flush; emit 3 more → second batch of 3, not 6)
  - `should preserve FIFO order in the flushed batch` (emit timestamps 1,2,3 → batch order is 1,2,3)
  - `should send an unmodifiable batch to the client` (attempt `batch.add(...)` throws — `_flushNow` uses `List.unmodifiable`)

- [x] **Task 2: Timer-based deadline flush (`_flushTimer` firing)** — wrap in `fakeAsync`, `flushInterval: 1 ms`
  Files: `test/Biometrics/biometric_batcher_test.dart`
  Test cases (build SUT inside the `fakeAsync((async) { ... })` zone; advance with `async.elapse(...)`):
  - `should not flush before the flush interval elapses` (emit 2 samples; `async.flushMicrotasks()` → no batch)
  - `should flush the partial buffer when the flush interval elapses` (emit 2; `async.elapse(flushInterval)` → one batch of 2)
  - `should clear the buffer after a timer flush` (emit 2; elapse; emit 1; elapse → two batches sized 2 then 1)

- [x] **Task 3: Timer lifecycle invariants** — wrap in `fakeAsync`, `flushInterval: 1 ms`
  Files: `test/Biometrics/biometric_batcher_test.dart`
  Test cases (use `fakeAsync`; rely on no extra pending timers / single flush as the observable proxy for `_flushTimer ??=` and post-flush cancel):
  - `should not start a second timer when a sample arrives before the deadline` (emit 1, elapse < interval, emit 1, elapse to first deadline → single batch of 2; no second delayed flush)
  - `should cancel the pending timer when a size flush occurs first` (emit 1 to start timer, emit enough to hit `maxBatchSize` → one size-flush batch; elapsing past the old deadline produces no extra empty/duplicate batch)
  - `should start a fresh timer for samples buffered after a flush` (flush once, emit 1 more, elapse interval → a new batch appears)

- [x] **Task 4: Dispose behavior (`dispose`)** — construct with `flushInterval: const Duration(seconds: 10)` for the real-event-loop cases; use `fakeAsync` + `1 ms` only for the pending-timer-cancel case
  Files: `test/Biometrics/biometric_batcher_test.dart`
  Test cases:
  - `should flush remaining buffered samples on dispose` (never-firing interval; emit 2 of 3, `await dispose()` → one batch of 2)
  - `should not call sendBatch on dispose when the buffer is empty` (construct, `await dispose()` with no samples → `client.batches` empty — `_flushNow` early-returns on empty buffer)
  - `should cancel the router subscription on dispose` (after `await dispose()`, emit a sample → no new batch, since `_sub` was cancelled)
  - `should cancel a pending flush timer on dispose` (`fakeAsync` + `1 ms`: emit 1 to arm the timer, `dispose()`, `async.elapse(flushInterval)` → no duplicate flush beyond the single dispose flush)

---

### Phase 2: ActiveRrSource — `test/Biometrics/active_rr_source_test.dart`

Construct with `ActiveRrSource(sources, clock: () => _now, timerFactory: _spyFactory)`. No `fake_async`.

Fakes / harness:
- `_FakeRrSource implements IRrIntervalSource` — backs `rrStream` with a `StreamController<RrInterval>.broadcast()`; expose `emit(RrInterval)`.
- Mutable test clock: `DateTime _now = DateTime(2026, 1, 1);` with a `clock: () => _now` closure; advance by reassigning `_now` before invoking the captured watchdog callback.
- Timer spy capturing scheduled watchdogs:
  ```dart
  final timers = <({Duration delay, void Function() cb})>[];
  Timer _spyFactory(Duration d, void Function() cb) {
    timers.add((delay: d, cb: cb));
    return _FakeTimer();
  }
  class _FakeTimer implements Timer {
    bool cancelled = false;
    @override void cancel() => cancelled = true;
    @override bool get isActive => !cancelled;
    @override int get tick => 0;
  }
  ```
  Trigger silence by advancing `_now` and firing the most recent watchdog. **Emulate real cancellation**: a real `Timer` never runs its callback after `cancel()`. The spy must do the same — before firing, check the captured `_FakeTimer` is not cancelled (e.g. fire via a helper that skips cancelled timers). This matters for the dispose test: firing a cancelled watchdog would run `_onSilence` against closed controllers, and `_ensureHasActive` calling `.add(false)` on a closed `BehaviorSubject` throws — which a real cancelled timer would never cause.
- Build `RrInterval(intervalMs: ..., timestamp: _now, isArtifact: false, source: SensorSource.neiry)` (from `lib/Biometrics/Models/RrInterval.dart` and `lib/Biometrics/Models/SensorSource.dart`).
- After each `emit`, `await Future.delayed(Duration.zero)` so the broadcast listener runs.
- **`hasActiveSourceStream` is a seeded `BehaviorSubject(false)`**: a subscriber attached at construction immediately receives the seeded `false`. Tests that count emissions must account for this initial value (expect `[false, true]` rather than `[true]`), or subscribe with `.skip(1)`.

- [x] **Task 1: Initial emission (`_onInterval` first arrival)**
  Files: `test/Biometrics/active_rr_source_test.dart`
  Test cases:
  - `should report no active source before any interval arrives` (`hasActiveSource` is `false` right after construction)
  - `should forward the first interval from source[0] to the output stream` (listen to `.stream`, emit from source[0] → that interval received)
  - `should flip hasActiveSource to true after the first interval` (`hasActiveSource` becomes `true`; accounting for the seeded `false`, `hasActiveSourceStream` carries `false` then `true`)
  - `should schedule a watchdog using max(intervalMs * 2, silenceFloor)` — `_silenceFloor` is **2000 ms**, `_silenceMultiplier` is **2.0**:
    - `emit 1500 ms → captured timer delay is 3000 ms` (multiplier branch, `window > floor`)
    - `emit 500 ms → captured timer delay is 2000 ms` (floor branch, `window <= floor`)

- [x] **Task 2: Priority steal (`_onInterval` lower-index preemption)**
  Files: `test/Biometrics/active_rr_source_test.dart`
  Test cases:
  - `should ignore intervals from a lower-priority source while a higher-priority one is active` (source[0] active, source[1] emits → source[1] interval not on output)
  - `should switch the active source when a higher-priority source emits` (source[1] active first, then source[0] emits → source[0] interval forwarded, becomes active)

- [x] **Task 3: Silence detection (`_onSilence` with no fresh alternative)**
  Files: `test/Biometrics/active_rr_source_test.dart`
  Test cases:
  - `should flip hasActiveSource to false when the active source goes silent and no other source is fresh` (single source: emit, advance `_now` past silence window, fire captured watchdog → `hasActiveSource` becomes `false`, one additional `false` emitted)
  - `should stop forwarding intervals after going silent until a source revives` (after silence, output is quiet; emitting again from a source restores forwarding and `hasActiveSource` true)

- [x] **Task 4: Failover (`_onSilence` switching to a recent alternative)**
  Files: `test/Biometrics/active_rr_source_test.dart`
  Note: a successful failover sets `_activeIndex = next` and restarts the watchdog but **does not** touch `_hasActiveController` (it stays `true`). Assert the active-source change (via which source's intervals now reach output) and that a new watchdog was scheduled — do **not** assert a spurious `hasActiveSource` transition on failover.
  Test cases:
  - `should failover to the next-priority source that emitted within the silence floor` (source[0] active and source[1] emitted recently; advance `_now` modestly so source[1] is within the 2 s floor; fire watchdog → active flips to source[1] — source[1] intervals now forward — and a new watchdog is scheduled)
  - `should skip a source that never emitted during failover` (3 sources, only source[0] ever emitted; fire watchdog → no failover target, `hasActiveSource` false)
  - `should skip a stale source older than the silence floor during failover` (source[1] last seen, then `_now` advanced > 2 s past it before firing watchdog → source[1] rejected, `hasActiveSource` false)

- [x] **Task 5: Dispose (`dispose`)**
  Files: `test/Biometrics/active_rr_source_test.dart`
  Test cases:
  - `should cancel all source subscriptions on dispose` (after `await dispose()`, emitting from a source produces no output)
  - `should close the output and hasActiveSource streams on dispose` (listeners on `.stream` and `hasActiveSourceStream` receive done after `await dispose()`)
  - `should cancel the active watchdog on dispose` (emit to arm a watchdog, `await dispose()`; the captured `_FakeTimer` is marked cancelled, so the spy does not fire its callback — no `_onSilence` runs against the closed controllers and no error is thrown)
  - `should complete without error when awaited` (`await source.dispose()` returns normally)
