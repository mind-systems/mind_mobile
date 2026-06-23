# Plan Review: B — Gate biometric streaming on a confirmed session

**Plan:** `.ai-factory/plans/77-b-gate-biometric-streaming-on-a-confirmed-session-primary-flood-fix.md`
**Risk Level:** 🟢 Low
**Verdict:** Solid — ready to implement.

## Verification performed

I read every file the plan targets and cross-checked all cited line numbers, the
sealed-event idiom, the server contract assumption, and the exhaustiveness impact.

### Line numbers & file paths — all accurate
- `ModuleStateEvent.dart:3-6` — `ModuleSessionStarted` idiom matches exactly (nullable named `String? moduleSessionId`). ✅
- `ModuleStateChannel._processProtoEvent` at `:116-145`, shared `ACTIVE || RESUMED` branch at `:118`. ✅
- `BiometricStreamClient` `_currentSessionId` at `:30`, `_onLifecycleEvent` switch at `:73-87`, connection listener at `:59-68`, `sendBatch` at `:92`. ✅
- `KeepAliveCoordinator._onEvent` at `:26-39`. ✅
- `HomeService.observeChanges` uses `.where((e) => e is ModuleSessionEnded)` (`:60`) — `is`-filter, not a `switch`, so genuinely unaffected. ✅

### Exhaustiveness coverage — complete (and more thorough than the source note)
I grepped all `switch`/`case ModuleSession`/`is ModuleSession` sites across `lib/`.
Only **two** exhaustive switches over `ModuleStateEvent` exist:
- `BiometricStreamClient._onLifecycleEvent` (`:74`) — handled by Task 3.
- `KeepAliveCoordinator._onEvent` (`:27`) — handled by Task 4.

Note: source note 153 (§"the re-confirmation signal") claims `BiometricStreamClient`
is *"the only exhaustive switch"* and omits `KeepAliveCoordinator`. The plan correctly
catches both — adding `ModuleSessionResumed` without Task 4 would break the analyzer/build.
Good that the plan is more complete than its own note. No other switch was missed.

### Server contract assumption — validated, not guessed
The fix is load-bearing on "RESUMED is exclusively the grace-reconnect signal." This is
confirmed by project docs, not inferred:
- `handoffs/09-reconnect-session-abandonment-confirmation.md` §58: "Reconnect within 30 s → server sends `RESUMED` with the id → resume normally."
- note 153 §24 cites the server source: `unpause` returns `ACTIVE` (`module-state.grpc.controller.ts:383`), not `RESUMED`. So splitting `RESUMED` out of the shared branch is non-breaking.

This matters because `ModuleStateChannel` does **not** reset `_state` on `_closeSessionStream`,
so after reconnect `currentState.status` is still `active` → `isNew` is false → the old
combined branch would emit **no** event, and `_sessionConfirmed` would never flip back to
true. The dedicated `ModuleSessionResumed` event is precisely what closes that gap. The
plan's reasoning here is correct and necessary.

### Logic of the gate — correct
- `_sessionConfirmed` defaults to `false`; cold-start `ModuleSessionStarted` sets it `true`. ✅
- Reset on `disconnected` only (after `_teardownSink()`), never on pause — matches note 153 §40 and preserves stream-through-pause behavior (note 58). ✅
- Dropping unconfirmed samples instead of enqueuing into the replay ring is intentional and documented (handoff §10.2). ✅
- The `RESUMED` branch returning early to avoid double-emit when `currentState` was idle is sound. ✅

## Minor observations (non-blocking)

1. **Redundant null check in the gate.** `if (_currentSessionId == null || !_sessionConfirmed)` —
   every path that sets `_sessionConfirmed = true` also sets `_currentSessionId`, so
   `!_sessionConfirmed` already implies the session is unusable. The `_currentSessionId == null`
   clause is harmless and defensible as belt-and-suspenders; keep it.

2. **idle → RESUMED edge.** With the split, an unexpected `RESUMED` arriving while
   `currentState` is idle now emits `ModuleSessionResumed` (not `ModuleSessionStarted`).
   For `BiometricStreamClient` this is correct (sets id + confirmed). For `KeepAliveCoordinator`
   it is a no-op, so the Android foreground keep-alive would **not** start in that specific edge.
   This is acceptable — `RESUMED` only fires for a session that was already running (and thus
   already had keep-alive started before the reconnect), per handoff §58. Worth a one-line
   awareness note for the implementer, but not a defect.

3. **No tests / no docs** per the plan's Settings block — consistent with the milestone scope
   (minimal logging via `logPrint`, defense-in-depth backstop from note 143 retained). Fine.

## Conclusion
The plan is internally consistent, line-accurate, faithful to note 153, and actually closes a
coverage gap the note left open (`KeepAliveCoordinator`). The one real design dependency — the
server's `RESUMED`-on-grace-reconnect contract — is backed by handoff 09 and the cited server
source. Nothing blocks implementation.

PLAN_REVIEW_PASS
