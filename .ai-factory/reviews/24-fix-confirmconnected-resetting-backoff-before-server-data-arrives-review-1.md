# Code Review: Fix `confirmConnected()` resetting backoff before server data arrives

**Plan:** `.ai-factory/plans/24-fix-confirmconnected-resetting-backoff-before-server-data-arrives.md`
**Scope reviewed:** `lib/Core/Grpc/ModuleStateChannel.dart`, `lib/Core/Grpc/ModuleInstructionStream.dart`, `lib/Core/Grpc/GrpcConnectionManager.dart`.

## What changed

- `ModuleStateChannel.dart`
  - New field `bool _backoffConfirmed = false;` next to the pending guards (line 31).
  - `_openSessionStream()` resets `_backoffConfirmed = false;` at the top (line 71).
  - In the `onData` handler, gated `confirmConnected()` call placed before the `switch` (lines 76–79).
  - The previous `_connectionManager.confirmConnected();` call at the bottom of `_openSessionStream()` is removed.
- `ModuleInstructionStream.dart`
  - New field `bool _backoffConfirmed = false;` next to the lazy-connect flags (line 21).
  - `_openStream()` resets `_backoffConfirmed = false;` at the top (line 95).
  - In the `onData` handler, gated `confirmConnected()` call placed before the `switch` (lines 100–103).
  - The previous `_connectionManager.confirmConnected();` call near the bottom is removed.
  - `_readyController.add(null);` is preserved as the last statement of `_openStream()` (line 142), so `emit()` callers still see the ready signal synchronously after `listen()`.
- `GrpcConnectionManager.dart` — unchanged. Already matches the post-cleanup baseline described in the plan (no `— no TCP handshake` suffix, no `state→connected` log, no log in `confirmConnected()` or `_resetBackoff()`, original `_scheduleReconnectInternal` log format).

## Correctness analysis

- **Per-open flag scope is right.** Both `_openSessionStream()` and `_openStream()` are the unique sites where a fresh `StreamSubscription` is created. Resetting `_backoffConfirmed = false` at the top of each call guarantees: any *new* stream open that fails before delivering a byte will leave the flag `false`, the failing path (`onError`/`onDone`) calls `scheduleReconnect()`, and the next `_nextDelay()` increments `_reconnectAttempt` correctly.
- **Placement before the `switch` is semantically correct.** Any server-emitted message — including `notSet` and an error payload — proves the underlying gRPC stream is alive end-to-end, which is the actual invariant we want backoff to reset on.
- **No race condition.** Dart single-isolate execution means the `if (!_backoffConfirmed) { _backoffConfirmed = true; ... }` block is atomic; `confirmConnected()` fires exactly once per open.
- **`onError`/`onDone` unmodified, as required.** The previous behavior of closing the stream, calling `disconnect()`, and `scheduleReconnect()` is preserved. The reset of `_backoffConfirmed` happens on the *next* `_openStream()` / `_openSessionStream()` call, which is the correct moment.
- **Disconnect path in `ModuleInstructionStream` (lines 55–60).** When the connection state goes `disconnected`, the subscription is cancelled and the sink is closed, but `_backoffConfirmed` is *not* reset there. This is fine because the next `_openStream()` always resets it before installing a new listener. No stale-flag risk.
- **Auth/`_reset()` path in `ModuleStateChannel`.** `_reset()` only clears pending guards and resets `_state`; it does not touch `_backoffConfirmed`. Logout flows through `GrpcConnectionManager.disconnect()` which drives `_closeSessionStream()` via the connection-state listener, so the next `_openSessionStream()` re-initializes the flag anyway.
- **`_readyController.add(null);` ordering preserved.** Critical for `emit()`-driven lazy connect: callers that key off `readyEvents` continue to see the ready signal synchronously after `response.listen()` returns, exactly as before.
- **`GrpcConnectionManager` already clean.** Verified by full read of the file: `connect()` logs `connect() start` / `connect() succeeded`; `confirmConnected()` and `_resetBackoff()` contain no `log(...)` calls; `_scheduleReconnectInternal()` uses the original `reconnecting in Xs (attempt N)` format. No edits needed there, matching the plan's "verify-only" expectation in Phase 2.
- **Diagnostic logs absent from both module-stream files.** No `_openSessionStream() called — attaching listener`, no `onData: event=...`, no `calling confirmConnected() — immediately after listen(), no server data yet` anywhere in `ModuleStateChannel.dart` or `ModuleInstructionStream.dart`. Phase 2 cleanup is a no-op, which matches the plan-review's prediction.

## Runtime behavior verification (mental simulation)

Server unreachable on app start, repeated reconnect attempts (`_reconnectAttempt` starts at 0):
1. `connect()` → `connected` event → `_openSessionStream()` → `_backoffConfirmed = false`, listener attached.
2. gRPC fails fast → `onError` → `_closeSessionStream()` → `disconnect()` → `scheduleReconnect()` → `_nextDelay()` increments `_reconnectAttempt` from 0 → 1, returns ~1 s.
3. Timer fires → `connect()` → `connected` → `_openSessionStream()` → `_backoffConfirmed = false` (no `confirmConnected()` yet because `onData` never fired).
4. Fails again → `_nextDelay()` increments 1 → 2, returns ~2 s.
5. ...continues `~4 s → ~8 s → ~16 s → 30 s (capped)`.

When the server later comes back online and the first `StateResponse` arrives, `_backoffConfirmed` flips to `true`, `confirmConnected()` → `_resetBackoff()` → `_reconnectAttempt = 0`, so the next failure (whenever it happens) starts the backoff fresh from `~1 s`. This matches the "Expected behaviour after fix" in the diagnosis note.

## Out-of-scope changes also present in the staged diff (not blocking this review)

`packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart` switches the phase asset extensions from `.ogg` to `.opus`, and three new `assets/audio/ohm_*.opus` binaries are added. These are unrelated to this milestone (Phase 14 / gRPC connectivity) and appear to belong to a parallel audio-format change. They do not affect correctness of the backoff fix, but the implementer should be aware they will land in the same staging snapshot if a `git add -A` happens — the plan's Commit Plan should not bundle them with "Gate confirmConnected()…".

## Findings

None impacting correctness, safety, or completeness of the milestone.

REVIEW_PASS
