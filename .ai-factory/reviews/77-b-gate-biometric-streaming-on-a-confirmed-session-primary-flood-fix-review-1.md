# Code Review: B — Gate biometric streaming on a confirmed session (primary flood fix)

**Plan:** `.ai-factory/plans/77-b-gate-biometric-streaming-on-a-confirmed-session-primary-flood-fix.md`
**Scope reviewed:** `git diff HEAD` — 4 source files changed (plus plan/json/plan-review artifacts).
**Verdict:** No blocking findings. One non-blocking informational note (explicitly out of scope per the plan's guards).

## Changes verified

All four tasks are implemented exactly as specified, and the code compiles cleanly against the sealed-event exhaustiveness check.

1. **`ModuleStateEvent.dart`** — `ModuleSessionResumed({this.moduleSessionId})` added with a nullable named `String? moduleSessionId`, matching the `ModuleSessionStarted` idiom. ✅
2. **`ModuleStateChannel.dart`** — `RESUMED` split into its own branch placed *before* the `ACTIVE` branch (`:118-124`). It updates `_state` identically to the active path (`status: active`, carries `isPaused`/`moduleSessionId`, clears `_isPendingStart`/`_isPendingPause`), emits `ModuleSessionResumed`, and does **not** fall through to `ModuleSessionStarted`. ✅
3. **`BiometricStreamClient.dart`** — `_sessionConfirmed` field added; set `true` on `Started`/`Resumed`, `false` on `Ended`/`Abandoned` and on `disconnected` (after `_teardownSink()`); pause/unpause untouched; `sendBatch` gate is `if (_currentSessionId == null || !_sessionConfirmed) return;`. ✅
4. **`KeepAliveCoordinator.dart`** — `case ModuleSessionResumed(): break;` added as a no-op, so a grace-reconnect does not re-`start()` the Android foreground service. ✅

## Correctness analysis

**Exhaustiveness / build.** The two — and only two — exhaustive `switch`es over `ModuleStateEvent` (`BiometricStreamClient._onLifecycleEvent`, `KeepAliveCoordinator._onEvent`) both handle the new case. `HomeService.observeChanges` uses `.where((e) => e is ModuleSessionEnded)`, not a switch, so it is unaffected. No missed consumer.

**Reconnect ordering (the race that matters) — safe.** On the first `StateResponse` after reconnect, `_openSessionStream`'s listener calls `_connectionManager.confirmConnected()` *before* `_processProtoEvent(event)`. `confirmConnected()` drives the `connected` transition (→ `BiometricStreamClient._ensureSinkOpen`) and `_processProtoEvent` emits `ModuleSessionResumed` (→ `_sessionConfirmed = true`). These are delivered asynchronously over two separate streams, so either interleaving is fine:
- `connected` first → sink opens empty, then `Resumed` flips the flag; subsequent `sendBatch` streams.
- `Resumed` first → flag set, sink opens on the next `sendBatch`/`connected`.
There is no window where `sendBatch` ships into an unconfirmed session: the flag is the gate, and it is only set by `Started`/`Resumed`.

**Flag lifecycle — correct.** Defaults `false`; reset on `disconnected` only (never on pause, preserving stream-through-pause). A truly dead session that never re-emits `RESUMED` keeps the flag `false`, so `sendBatch` stays a no-op until a fresh `ModuleSessionStarted` — exactly the intended flood elimination at the source.

**`RESUMED` branch behavior change — acceptable.** Previously `RESUMED` shared the `ACTIVE` branch and could (in principle) emit `Started`/`Paused`/`Unpaused` via the `isNew`/`wasPaused` transitions. Now it emits only `ModuleSessionResumed`. Per the validated server contract (`unpause` returns `ACTIVE`, not `RESUMED`; `RESUMED` fires only on grace-reconnect of an already-running session), no legitimate pause/unpause transition is lost. The idle→`RESUMED` edge now emits `Resumed` (keep-alive no-op) instead of `Started` (keep-alive start); since `RESUMED` only fires for sessions that were already running — and thus already had keep-alive started before the disconnect — this does not regress keep-alive behavior.

## Non-blocking observation (informational — out of scope per plan guards)

**Replay-ring drain bypasses the new gate.** `sendBatch` is gated on `_sessionConfirmed`, but the replay-ring drain path is not. On reconnect, after the sink opens, the `ready` frame (`:140-146`) or the 5 s readiness timeout (`:166-173`) calls `_encodeAndAdd(replay)`, which checks only `_currentSessionId`/`_sink`/`_isReady` — never `_sessionConfirmed`. So buffered samples can be shipped into the *retained provisional* session id before `ModuleSessionResumed` confirms it. If that session is gone server-side, this produces a `NO_SESSION` response.

This is **not** a defect in this change and does not undermine the milestone:
- The plan's guards explicitly state "Do NOT touch the replay ring, the readiness gate / `_isReady`" — this path is deliberately left alone.
- It is bounded: the ring is capped at 75 samples and drains exactly once into a *single* `BioSampleBatch`, so it yields at most one `NO_SESSION` error response (currently just logged at `:139`), not the sustained 600+/min flood the primary `sendBatch` gate eliminates.
- Note 143's reactive teardown is retained as the documented backstop for exactly this residual edge.

No action required for this milestone. Flagged only so a future task (A/C, or a follow-up that touches the replay ring) is aware the drain path is not yet session-confirmation-gated.

## Conclusion

The implementation is faithful to the plan and to note 153, closes the primary flood vector at the source, keeps the build green by handling both exhaustive switches, and respects every stated guard. The lone observation is bounded, pre-existing in spirit, and explicitly outside this milestone's scope.

REVIEW_PASS
