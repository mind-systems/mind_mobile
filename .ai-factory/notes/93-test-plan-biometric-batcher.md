# BiometricBatcher — Test Plan

**Date:** 2026-06-03
**Source:** roadmap-test-coverage agent

## Source Overview

`BiometricBatcher` sits between `BioStreamRouter` (sample producer) and `BiometricStreamClient` (gRPC sink). It buffers incoming `BioSample` objects into batches and flushes on two triggers: size (≥25 samples) or deadline (250 ms), whichever fires first. It owns a subscription to the router's sample stream and cancels it on disposal.

## Instantiation

Construct the batcher with:
```dart
final batcher = BiometricBatcher(
  router: mockRouter,
  client: mockClient,
);
```

**Fakes needed:**

- **BioStreamRouter:** Mock with a `StreamController<BioSample>` as the internal stream for the `samples` getter. Expose a method to pump test samples into it.
- **BiometricStreamClient:** Mock `sendBatch(List<BioSample>)` to record calls and verify batches received.
- **BioSample:** Use factories (`BioSample.fromCardio`, etc.) or construct directly with `const BioSample(timestampMs: 123, sampleType: 'cardio', data: {…})`.

## Existing Coverage

None.

## Test Cases

### Constructor & Lifecycle

- **should subscribe to router.samples on construction**
  - Fixture: construct batcher with mock router
  - Verify: mock router's `samples.listen()` was called once
  - Setup: none

- **should cancel subscription on dispose()**
  - Fixture: construct batcher, call `dispose()`
  - Verify: StreamSubscription cancel was awaited, `_sub` is null
  - Setup: none

- **should cancel flush timer on dispose()**
  - Fixture: construct batcher, pump one sample (timer starts), call `dispose()`
  - Verify: Timer.cancel() was called
  - Setup: use `fake_async` to advance time manually, or spy on Timer creation

- **should flush remaining buffer on dispose()**
  - Fixture: construct batcher, pump 5 samples (not enough for size flush), call `dispose()`
  - Verify: `client.sendBatch()` was called with those 5 samples
  - Setup: none

### Sample Handling

- **should add sample to buffer**
  - Fixture: pump one sample via router
  - Verify: buffer length is 1 (inspect via test harness or spy on client.sendBatch)
  - Setup: none

- **should not flush immediately on single sample**
  - Fixture: pump one sample
  - Verify: `client.sendBatch()` was NOT called
  - Setup: none

### Size-Based Flush (≥25 samples)

- **should flush immediately when buffer reaches 25 samples**
  - Fixture: pump 24 samples, verify no flush; pump 25th, verify flush
  - Verify: `client.sendBatch()` called once with exactly 25 samples
  - Setup: none

- **should flush exactly 25 samples and clear buffer**
  - Fixture: pump 25 samples, verify batch content
  - Verify: batch length is 25, buffer is empty after flush
  - Setup: use distinct timestamps or IDs to verify order

- **should reset timer when size-flushing**
  - Fixture: pump 1 sample (timer T1 starts), wait <250ms, pump 24 more (flush at 25), verify timer was cancelled
  - Verify: flush happens without waiting for T1 deadline
  - Setup: use `fake_async`, advance 50ms after first sample, then pump 24 more

- **should flush in order (FIFO)**
  - Fixture: pump samples with increasing timestamps, verify order in batch
  - Verify: batch samples[i].timestampMs < batch samples[i+1].timestampMs
  - Setup: create samples with explicit timestampMs values

### Timer-Based Flush (250 ms deadline)

- **should start timer on first sample**
  - Fixture: pump one sample, verify Timer(_flushInterval, _flushNow) called
  - Verify: _flushTimer is non-null
  - Setup: spy on Timer constructor or use fake_async

- **should not start timer if already running**
  - Fixture: pump 1 sample (timer starts), pump 2nd sample before deadline
  - Verify: Timer was created only once (no second Timer call)
  - Setup: use fake_async, advance 50ms after first sample, pump second sample

- **should flush partial batch after 250 ms deadline**
  - Fixture: pump 5 samples, wait 250ms, verify flush
  - Verify: `client.sendBatch()` called with 5 samples
  - Setup: use `fake_async`, advance time by Duration(milliseconds: 250)

- **should clear buffer after timer flush**
  - Fixture: pump 5 samples, advance 250ms, pump 1 more sample, advance 250ms again
  - Verify: first flush has 5 samples, second flush has 1 sample
  - Setup: use fake_async

- **should cancel timer after flush**
  - Fixture: pump 1 sample, advance 250ms, pump another after flush
  - Verify: second sample starts a new timer (not reusing old one)
  - Setup: use fake_async, verify Timer.cancel() was called on first timer

### Empty Buffer Edge Cases

- **should not flush if buffer is empty**
  - Fixture: pump 1 sample, manually trigger _flushNow (via dispose or reflection), verify only one batch sent
  - Verify: `client.sendBatch()` called only once with 1 sample (the one flush), no empty batch
  - Setup: double-check by spying on sendBatch calls

- **should handle dispose with empty buffer**
  - Fixture: construct batcher, immediately dispose without pumping samples
  - Verify: `client.sendBatch()` was never called, no error
  - Setup: none

### Batch Immutability

- **should send unmodifiable list to client**
  - Fixture: pump samples, capture batch in mock client, try to modify it
  - Verify: List.unmodifiable throws on modification attempt
  - Setup: use `final snapshot = List<BioSample>.unmodifiable(_buffer)` pattern

- **should not leak internal buffer reference**
  - Fixture: pump batch, modify original samples list (if somehow accessible), verify batch unchanged
  - Verify: batch is a snapshot, not a live reference
  - Setup: use unmodifiable list or verify batch is a copy

### Multiple Flushes in Sequence

- **should correctly batch multiple flush cycles**
  - Fixture: pump 25 samples (flush 1), pump 10 samples, advance 250ms (flush 2), pump 15 samples (flush 3)
  - Verify: three sendBatch calls with 25, 10, 15 samples respectively
  - Setup: use fake_async

- **should maintain order across multiple batches**
  - Fixture: pump 50 samples with ascending timestamps, verify two flushes of 25 each in order
  - Verify: timestamps across batches are monotonically increasing
  - Setup: none

### Concurrent Operations

- **should handle rapid sample pumping**
  - Fixture: pump 100 samples as quickly as possible (synchronously)
  - Verify: four flushes of 25, 25, 25, 25 samples, buffer empty
  - Setup: none

- **should not re-enter _onSample during flush**
  - Fixture: pump 1 sample, manually mock client.sendBatch to pump more samples, verify no stack overflow
  - Verify: no re-entrant calls to _onSample
  - Setup: none (Dart streams already serialize listener callbacks)

## Gotchas

- **Timer-based tests:** Use the `fake_async` package (`fake_async: ^1.x`) to control time. Wrap test in `fakeAsync((_) { … })` block and call `tick(Duration)` to advance the clock. This avoids flaky real-time dependencies.
- **Timer creation:** The timer is created lazily (`_flushTimer ??= Timer(…)`). Spy on `Timer` via a mock if verifying timer lifecycle; otherwise inspect via state after advancing time.
- **Fire-and-forget:** `_flushNow()` callback is fire-and-forget—no Future awaited. Verify via mock calls to `client.sendBatch()`, not via returned Futures.
- **Final flush on dispose:** The `dispose()` method awaits `_sub?.cancel()` but then calls `_flushNow()` synchronously. Verify the flush happens after unsubscribing from the router. This means dispose should not race—samples arriving mid-dispose are ignored (subscription is already null).
- **Unmodifiable list:** The batch sent to the client is `List<BioSample>.unmodifiable(_buffer)`. The test harness must not expect to mutate the batch.
- **No backpressure:** BiometricBatcher has no backpressure logic. If the client is slow or the router is fast, samples are just buffered in memory. Tests do not need to verify any flow-control or drop behavior—that is the client's responsibility.

## Refactor Required

`_flushInterval` (250 ms) and `_maxBatchSize` (25) are hard-coded `static const` values. Tests that exercise the flush-on-size threshold must pump exactly 25 real samples, and tests that exercise the deadline flush must wait a real 250 ms — both making tests slow and brittle.

**What to refactor:** Add two optional named constructor parameters with the current values as defaults:

```dart
BiometricBatcher({
  required BioStreamRouter router,
  required BiometricStreamClient client,
  Duration flushInterval = const Duration(milliseconds: 250),
  int maxBatchSize = 25,
})
```

Replace the `static const` references inside the class body with the instance fields. Tests pass `flushInterval: Duration(milliseconds: 1)` and `maxBatchSize: 3` to make flush behavior observable without real timing or large sample counts. Production call site passes no overrides.
