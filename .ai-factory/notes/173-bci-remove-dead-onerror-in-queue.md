# Remove the dead `onError` safety net in SerialCommandQueue (T9)

**Date:** 2026-06-24
**Source:** Phase 56, Tier 4 — nit.

## Key Findings

- `SerialCommandQueue.enqueue` chains the command onto `_tail` via `_tail.then(continuation, onError: ...)` (`lib/Bci/SerialCommandQueue.dart:64-88`). The continuation wraps the command body in a `try/catch` (`:74-79`) that routes **every** command error to the per-command `Completer`, and returns normally — so `_tail` **never rejects**.
- The `onError` branch (`:81-87`) is therefore **unreachable** dead code; its comment even admits "this handler is a safety net" for a rejection that the design prevents.

## Details

- Remove the `onError` argument from the `_tail.then(...)` chain (`:81-87`), leaving the single-argument `_tail = _tail.then(continuation)`. This makes the "tail never rejects" invariant self-evident at the call site instead of being hedged by unreachable handling.

## Guards

- Pure dead-code removal — no behavior change (the branch never runs).
- Do not alter the completer-per-command semantics, `close()`, or `QueueClosedException`.
- Keep `SerialCommandQueue` pure Dart (no Flutter/Riverpod).

## Verify

- The command-queue test suite (`test/Bci/neiry_bci_provider_command_queue_test.dart`) stays green — including the "throwing command does not poison the queue" case (which proves `_tail` stays alive without the `onError` net).

**Done-when:** the `onError` branch is gone, command-queue tests green.
