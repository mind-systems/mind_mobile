# Plan: Remove the dead `onError` net in SerialCommandQueue

## Context
Remove the unreachable `onError` safety-net branch from `SerialCommandQueue.enqueue` so the "tail never rejects" invariant is self-evident at the call site. Pure dead-code removal, no behavior change.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Remove dead code

- [x] **Task 1: Drop the `onError` argument from the `_tail.then(...)` chain**
  Files: `lib/Bci/SerialCommandQueue.dart`
  In `enqueue<T>` (lines 64-88), the continuation's `try/catch` (`:74-79`) already routes every command error to the per-command `completer`, so `_tail` never rejects and the `onError` branch (`:81-87`) is unreachable. Convert the call to the single-argument form `_tail = _tail.then<void>((_) async { ... });` by removing the trailing `onError:` callback and its comment. Keep the continuation body (close re-check + `try/catch`) exactly as is. Do not touch `close()`, `QueueClosedException`, or the completer-per-command semantics. Keep the file pure Dart (no Flutter/Riverpod imports).

### Phase 2: Verify

- [x] **Task 2: Confirm command-queue tests stay green** (depends on Task 1)
  Files: `test/Bci/neiry_bci_provider_command_queue_test.dart`
  Run the command-queue test suite and confirm it passes — including the "throwing command does not poison the queue" case, which proves `_tail` stays alive without the `onError` net. Command: `/usr/local/bin/flutter test test/Bci/neiry_bci_provider_command_queue_test.dart`. No new tests are required.
