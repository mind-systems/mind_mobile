# Code Review: T4 · scan() leaks QueueClosedException → spurious BciIdle

**Branch:** `phase-55-serialize-bci-lifecycle`
**Files reviewed (code):** `lib/Bci/NeiryBciProvider.dart`, `test/Bci/neiry_bci_provider_locator_port_test.dart`
**Cross-checked:** `lib/Bci/SerialCommandQueue.dart`, `lib/Bci/BciDeviceManager.dart`
**Risk:** 🟢 Low

## Summary

The change wraps the `await _queue.enqueue(...)` inside `scan()` in a `try { ... } on QueueClosedException { return; }`, ending the scan stream cleanly when `dispose()` closes the queue, while keeping `yield* devicesStream` outside the try so genuine in-stream errors still propagate. Two tests were added and the `FakeLocatorPort` gained an `emitError` helper. The implementation matches the plan exactly and all 69 BCI tests pass (including the two new ones).

## Correctness verification

- **Single-type catch is safe.** `QueueClosedException` is thrown **only** by `SerialCommandQueue` on enqueue-after-close (`SerialCommandQueue.dart:56–61`, `:68–72`). `_queue.close()` has exactly one call site — `_doDispose()` (`NeiryBciProvider.dart:566`). So catching this type can never mask a genuine `requestDevices` failure, and only ever fires on the dispose path. ✓
- **Real errors still surface.** A synchronous throw from the command body completes the enqueue future with a non-`QueueClosedException` error (escapes the `on QueueClosedException` clause → propagates to `onError`); an async error emitted by the device stream flows through `yield* devicesStream`, which is outside the try. ✓
- **`final` + definite assignment is valid.** `devicesStream` is assigned only in the try and read only after it; the catch always `return`s, so the analyzer is satisfied and no nullable is needed. Confirmed compiling (tests build & run). ✓
- **Consumer impact is benign.** Old behavior: post-dispose `scan()` → `onError(QueueClosedException)` → `BciDeviceManager` `:206` unconditionally `_setState(BciIdle())` (the spurious transition). New behavior: stream ends via `onDone` → `:209–211` sets `BciIdle()` **only if** `_state is BciScanning`, which is the correct terminal state after a scan ends. The spurious unconditional idle is eliminated; no `BciDeviceManager` change was required. ✓

## Test verification

- **Case 1 (`...ends cleanly when dispose() closes the queue before enqueue resolves`)** genuinely exercises the swallow. `provider.dispose()` is called immediately after `listen()` with no settling `await` before it; `_doDispose()` runs `_disposed = true; _queue.close()` synchronously before its first `await` (`:561–566`), so by the time microtasks drain, the pending enqueue slot rejects with `QueueClosedException`. The single `await Future.delayed(Duration.zero)` after dispose lets it settle. Asserts `done == true`, `errored == false`. The ordering is deterministic regardless of whether the `async*` body starts synchronously at `listen()` or as a scheduled microtask — in both orderings the enqueue resolves/rejects only after `_closed == true`, so the swallow path is always hit. The test cannot pass vacuously. ✓
- **Case 2 (`...propagates non-QueueClosedException errors`)** settles first so `yield*` is subscribed, then `fake.emitError(Exception('scan failed'))` flows through to `onError`. Asserts `errors` is non-empty. This is the regression guard against a blanket catch. ✓
- `emitError` on the fake is additive (`_devicesController.addError`) and does not alter existing tests' behavior. ✓

## Findings

None. The change is minimal, correctly scoped (no `BciDeviceManager`, queue, or proto changes), consistent with the existing silent-swallow precedent at `:473`, and fully covered by tests. No runtime, type, race, or security concerns.

REVIEW_PASS
