# Plan: T4 · scan() leaks QueueClosedException → spurious BciIdle

## Context
After `dispose()` closes the serial command queue, a pending `scan()` propagates `QueueClosedException` to its consumer (`BciDeviceManager`), forcing a spurious `BciIdle`. Swallow only `QueueClosedException` at the provider seam so the post-dispose scan stream ends cleanly while genuine scan errors still surface.

## Settings
- Testing: yes (milestone explicitly requires a test)
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Fix the provider seam

- [x] **Task 1: Swallow only QueueClosedException in scan()**
  Files: `lib/Bci/NeiryBciProvider.dart`
  In `scan()` (`:118`), wrap the `await _queue.enqueue(...)` call (`:156`) in a `try`/`catch`. Catch `QueueClosedException` only — on catch, `return` from the `async*` generator so the stream ends cleanly (no error to the consumer). Do NOT blanket-catch: any other error (e.g. a genuine `requestDevices` failure) must propagate to the listener's `onError`. Keep `yield* devicesStream` (`:159`) outside the try so real scan errors emitted during the stream still surface.

  `QueueClosedException` is already in scope via the `import 'SerialCommandQueue.dart';` at `:18` (it is also used at the catch site `:473` — that is a usage, not the import). **No new import needed.**

  Declare `devicesStream` before the try with definite assignment so the catch's `return` skips the `yield*` (do not reach for a nullable — `final` + definite assignment works because the catch always `return`s). Target shape:
  ```dart
  final Stream<List<BciDeviceInfo>> devicesStream;
  try {
    devicesStream = await _queue.enqueue(
      () async => _locator.requestDevices(type: BciScanDeviceType.headband, searchTime: 5),
    );
  } on QueueClosedException {
    return;
  }
  yield* devicesStream;
  ```

  Match the swallow rationale described in the spec note `.ai-factory/notes/168-bci-scan-swallow-queueclosed.md`. Do not modify `BciDeviceManager` or the queue/`SerialCommandQueue`.

### Phase 2: Test coverage

- [x] **Task 2: Add post-dispose scan test** (depends on Task 1)
  Files: `test/Bci/neiry_bci_provider_locator_port_test.dart`
  Add tests to the existing `NeiryBciProvider — LocatorPort injectable seam` group using the established `FakeLocatorPort` pattern (test-controlled `requestDevices` stream; `dispose()` closes the queue). Cover two cases.

  **Case 1 and Case 2 require OPPOSITE sequencing — the `await Future.delayed(Duration.zero)` settling note applies to Case 2 ONLY. Do not apply it uniformly.**

  1. **Post-dispose scan ends silently (exercises the swallow).** Call `dispose()` **immediately after `listen()` with NO settling `await` in between**; the single `await Future<void>.delayed(Duration.zero)` goes *after* dispose:
     ```dart
     var errored = false;
     var done = false;
     final sub = provider.scan().listen(
       (_) {},
       onError: (_) => errored = true,
       onDone: () => done = true,
     );
     provider.dispose();                        // _doDispose() runs _queue.close() synchronously before its first await
     await Future<void>.delayed(Duration.zero); // settle AFTER dispose
     expect(done, isTrue);
     expect(errored, isFalse,
         reason: 'QueueClosedException must be swallowed, not delivered to onError');
     await sub.cancel();
     ```
     Why deterministic (per review): `scan()` registers the enqueue synchronously during `.listen()` and suspends at the `await`. `dispose()` → `_doDispose()` sets `_disposed = true` and calls `_queue.close()` synchronously before its first `await`, so the pending slot's continuation sees `_closed == true` and rejects with `QueueClosedException`. No real race. **Do NOT insert a settling `await` before `dispose()`** — that lets the enqueue resolve first, `dispose()` then merely closes `_devicesController`, and the test passes via `onDone` without ever exercising the swallow (false green).

  2. **Real scan errors still surface (guards against a blanket catch).** Here the subscription **must settle first** (`await Future<void>.delayed(Duration.zero)`) so the generator reaches `yield*` and is subscribed before the error is emitted. Extend `FakeLocatorPort` minimally with an `emitError(Object)` helper (`_devicesController.addError(...)`) — without changing existing tests' behavior — and emit a non-`QueueClosedException` error:
     ```dart
     final errors = <Object>[];
     final sub = provider.scan().listen((_) {}, onError: errors.add);
     await Future<void>.delayed(Duration.zero); // settle FIRST so yield* is subscribed
     fake.emitError(Exception('scan failed'));
     await Future<void>.delayed(Duration.zero);
     expect(errors, isNotEmpty);
     await sub.cancel();
     ```

  Do **not** copy the stale comment at the existing test's lines 96–98 (it references `await _teardownComplete`, removed by the Phase-55 refactor).

- [x] **Task 3: Run the BCI test suite** (depends on Task 2)
  Files: (no file changes)
  Run `/usr/local/bin/flutter test test/Bci/` and confirm all suites are green, including the two new tests.
