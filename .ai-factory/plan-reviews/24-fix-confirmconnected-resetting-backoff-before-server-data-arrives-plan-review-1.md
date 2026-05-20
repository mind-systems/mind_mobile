# Plan Review: Fix `confirmConnected()` resetting backoff before server data arrives

**Plan file:** `.ai-factory/plans/24-fix-confirmconnected-resetting-backoff-before-server-data-arrives.md`
**Risk Level:** 🟢 Low

## Summary

The plan is small, focused, and architecturally correct. The diagnosis in
`.ai-factory/notes/10-grpc-backoff-fix.md` matches the code I read, and the
proposed code edits land exactly where they need to. Phase 1 will fix the
bug; Phase 2 is defensive verification and will mostly be a no-op (see
notes below). No security, migration, or DTO-boundary concerns.

## Codebase verification

I confirmed the plan against the live code:

- `lib/Core/Grpc/ModuleStateChannel.dart`
  - `_isPendingStart` / `_isPendingPause` exist (lines 29–30) — adding
    `bool _backoffConfirmed = false` next to them is straightforward.
  - `_openSessionStream()` (lines 69–102) has `confirmConnected()` at
    line 101, right after `response.listen(...)`. The plan correctly
    targets it.
  - The `onData` block (lines 73–87) already does a `switch (r.whichEvent())`,
    so the gated `confirmConnected()` insertion point is unambiguous.
- `lib/Core/Grpc/ModuleInstructionStream.dart`
  - `_isGrpcConnected` / `_streamRequested` exist (lines 19–20).
  - `_openStream()` (lines 93–138) has `confirmConnected()` at line 136 and
    `_readyController.add(null);` at line 137. Removing only the former
    and keeping the latter at the bottom of the method preserves the
    "ready fires synchronously after `listen()`" guarantee that `emit()`
    callers depend on.
- `lib/Core/Grpc/GrpcConnectionManager.dart`
  - `confirmConnected()` already calls only `_resetBackoff()` (no log).
  - `_resetBackoff()` is one line: `_reconnectAttempt = 0;` (no log).
  - `connect()` logs only `connect() start` / `connect() succeeded` (no
    "no TCP handshake" suffix, no `state→connected`).
  - `_scheduleReconnectInternal()` already uses the original log format.
  - **All three files already match the post-cleanup baseline** — the
    diagnostic logs the note describes are no longer present.

## Correctness analysis

- **Per-stream flag is the right scope.** Both `_openSessionStream()` and
  `_openStream()` are the unique points where a new stream subscription
  is created (the only callers are the connection-state listener and,
  for instructions, a re-entry via `emit()` after a fresh `connected`).
  Resetting `_backoffConfirmed = false` at the top of each open guarantees
  that one successful byte resets backoff for *this* open, and any
  later re-open that fails before data still grows the counter.
- **Placement before the switch is correct.** Any server-emitted byte
  (including `notSet` or an `error` payload) means the gRPC stream is
  alive end-to-end, so confirming before the switch is semantically right
  — backoff should reset on stream liveness, not on payload kind.
- **No race with `onError` / `onDone`.** If the stream errors before any
  `onData`, the flag stays `false`, the stream is closed, and
  `scheduleReconnect()` is called — exactly the behavior the bug report
  wants.
- **Auth reset path is safe.** In `ModuleStateChannel`, the `GuestState`
  branch calls `_reset()` (resets pending guards + state) but does *not*
  reset `_backoffConfirmed`. That's fine: logout disconnects the
  connection manager, which closes the stream and the next
  `_openSessionStream()` reinitializes the flag.

## Minor notes (non-blocking)

1. **Phase 2 will likely produce no edits.** I inspected all three files
   and they already match the "clean" baseline the plan describes.
   Tasks 3–5 should resolve as verify-only with no file changes. The
   plan's Commit Plan declares "Commit 2 (after tasks 3–5)" — this commit
   should be skipped if no edits result. Consider noting in the plan
   that an empty diff for Phase 2 is an acceptable outcome and Commit 2
   should be omitted in that case.

2. **Symmetry hint for the implementer.** In `ModuleInstructionStream`,
   after removing line 136 (`confirmConnected()`), the surviving
   `_readyController.add(null);` should remain the last statement in
   `_openStream()` so it still fires synchronously after `listen()`. The
   plan already calls this out, but it's worth re-emphasizing because
   `emit()` callers route through this signal.

3. **No tests requested.** Settings say "Testing: no", and the existing
   gRPC layer has no test scaffolding for connection-state mocking, so
   skipping tests is reasonable. The behavior is straightforward to
   verify manually by pointing the dev flavor at an unreachable host and
   watching the backoff log line grow `1s → 2s → 4s → 8s → ...`.

## Positive notes

- Diagnosis note (`.ai-factory/notes/10-grpc-backoff-fix.md`) is precise
  and includes log evidence — easy to verify against the code.
- The plan calls out *exact* field placement, exact removal points, and
  exact insertion points, so the implementer cannot ambiguously
  interpret it.
- The fix preserves the `_readyController` synchronous-ready contract
  that the rest of `ModuleInstructionStream` depends on.

PLAN_REVIEW_PASS
