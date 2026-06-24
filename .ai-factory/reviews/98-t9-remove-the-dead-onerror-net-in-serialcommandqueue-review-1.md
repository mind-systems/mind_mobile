# Code Review: Remove the dead `onError` net in SerialCommandQueue (T9)

## Scope
Reviewed `git diff HEAD` and `git status`. The only code change is `lib/Bci/SerialCommandQueue.dart` (the other staged files are plan/plan-review artifacts, not code). Read the changed file in full.

## Change summary
The `onError` callback on the `_tail.then<void>(...)` chain in `enqueue<T>` was removed, collapsing the two-argument form into the single-argument `_tail = _tail.then<void>((_) async { ... })`. The continuation body (close re-check + `try/catch`) is byte-for-byte unchanged.

## Correctness analysis

The central question: with the `onError` net gone, can the continuation ever throw and thereby reject `_tail` — which (without a net) would poison every subsequent command in the chain?

It cannot:

- **Closed path** (`:67-71`): `completer.completeError(...)` on a fresh, never-completed completer cannot throw, followed by `return`. Safe.
- **Run path** (`:73-78`): `command()` runs inside `try`; any error it raises is caught and routed to `completer.completeError(e, st)`. `completer.complete` / `completeError` can only throw on double-completion, but the two branches are mutually exclusive and each completer is created fresh per `enqueue` and completed exactly once. Safe.

Therefore the continuation never throws (sync or async), `_tail` always resolves successfully, and the next chained `.then` continuation always runs. The "tail never rejects" invariant holds, and the removed branch was genuinely unreachable. No behavior change.

- `close()`, `QueueClosedException`, `idle`, and the completer-per-command semantics are untouched.
- File remains pure Dart (only `dart:async` imported) — no Flutter/Riverpod leak.

## Verification
`flutter test test/Bci/neiry_bci_provider_command_queue_test.dart` → all 6 tests pass, including the poison-pill tail-drop cases that prove the queue stays alive after a dropped/closed command.

## Findings
None.

REVIEW_PASS
