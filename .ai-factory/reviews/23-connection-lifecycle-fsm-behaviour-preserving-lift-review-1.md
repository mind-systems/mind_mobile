# Code Review: Connection-lifecycle FSM (behaviour-preserving lift)

**Scope reviewed:** `git diff HEAD` — `lib/Core/Grpc/ConnectionLifecycle.dart` (new), `lib/Core/Grpc/ModuleStateChannel.dart`, `test/Core/Grpc/module_state_channel_test.dart`.
**Verdict:** Behaviour-preserving structural lift, correctly executed. Full suite runs green (61/61, including 8 new Group-12 tests).

## What the change does

- Adds `enum ConnectionLifecycle { disconnected, opening, active, reconnecting, yielded }` in its own file, matching the one-type-per-file enum convention (`GrpcConnectionState.dart`).
- Adds a `_lifecycle` field + a single `_transition(to)` chokepoint (log + assign, no side effects) plus a `@visibleForTesting` `lifecycle` getter.
- Routes the existing paths through the FSM: `connected → opening`, first frame `→ active`, `disconnected`/`onError`/`onDone` `→ reconnecting`, `_reset()` `→ disconnected`.
- Removes the `_backoffConfirmed` boolean, replacing the first-frame gate with `_lifecycle == opening`.
- `yielded` is defined but no transition reaches it; a placeholder comment marks where the future reconnect impl will gate reopen.

## Correctness analysis

**First-frame / `confirmConnected` gate — equivalent.** Old gate `if (!_backoffConfirmed)` is replaced by `if (_lifecycle == opening)`. `_openSessionStream` is the sole setter of `_sessionSub` and always transitions to `opening` first (was: `_backoffConfirmed = false`); the first frame transitions to `active` and calls `confirmConnected()` exactly once; later frames see `active` and skip. The two flags moved in lockstep, so `confirmConnected` still fires exactly once per stream open and re-arms on every reconnect. Verified by the green Group at `:891` (`confirmConnectedCount`).

**`isConnected` left untouched** — still `bool get isConnected => _sessionSub != null;` (`:67`). This is the correct choice (the plan-review's item 1): deriving it from `_lifecycle` would have diverged after `dispose()` (which nulls `_sessionSub` but never transitions) and after `_reset()` (which transitions to `disconnected` but does not close the stream, so `_sessionSub` stays non-null). Both the dispose assertion (`:1107`) and the `_sessionSub`-backed invariant are preserved.

**Ordering preserved** in `onError`/`onDone`: `_closeSessionStream()` → `disconnect()` → `scheduleReconnect()` → `_transition(reconnecting)`. The transition is last and side-effect-free, so `disconnectCount`/`scheduleReconnectCount` and the immediate `isConnected == false` read are unchanged.

**`_reset()` lands in `disconnected`, not `reconnecting`** — matches the spec's logout requirement; the transition is additive to the existing state/registry clear and does not close the stream, preserving the pre-existing `isConnected` reading after reset.

**Scope discipline** — `_isPendingStart`/`_isPendingPause` untouched; `yielded` genuinely unreachable (no transition targets it), asserted by the dormancy test. No eviction behaviour added.

## Tests

New Group 12 is purely additive (appended after existing groups, no existing test modified) and reuses existing fixture helpers (`_connect`, `_activateSession`, `_disconnect`, `latestCall.responseCtrl`, `_sessionStateResponse`, `_guestUser`), all of which exist and are used consistently with the rest of the file. Each path is asserted to land in exactly one state, plus a dormancy assertion for `yielded`. All pass.

## Non-blocking observations (no action required)

- `dispose()` does not transition `_lifecycle` (it stays at its last value post-dispose). This is harmless — `isConnected` is `_sessionSub`-backed and the object is dead after dispose — and consistent with the "no side effects beyond what tests observe" scope. Not a defect.
- Re-opening the stream without first closing a still-open one (e.g. a `connected` arriving after `_reset()` left `_sessionSub` non-null) leaks the prior subscription. This is **pre-existing** behaviour, not introduced or worsened here, and out of scope for a behaviour-preserving lift (belongs to the later reconnect impl).

No bugs, security issues, or behaviour regressions found.

REVIEW_PASS
