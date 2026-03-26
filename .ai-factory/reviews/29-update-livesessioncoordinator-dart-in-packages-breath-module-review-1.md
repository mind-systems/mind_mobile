# Review: 29 — Update LiveSessionCoordinator.dart

## Changes reviewed

| File | Change |
|------|--------|
| `packages/breath_module/lib/src/BreathSession/LiveBreathSessionCoordinator.dart` | Add `_liveSessionId = null;` to `reset()` |
| `.ai-factory/ROADMAP.md` | Check box for milestone 3.5 item |
| `.ai-factory/plans/29-...md` | New plan file (documentation only) |

## Analysis

### `_liveSessionId = null` in `reset()` — correctness trace

Restart flow after the fix:

1. `reset()` clears `_liveSessionId` (+ all flags/state)
2. State stream emits active → `_handleLifecycle` calls `startSession()`, sets `_started = true`
3. `_handleTelemetry` runs → `_liveSessionId` is null → telemetry queued in `_pendingTelemetry`
4. Server responds with new session state → `_liveSessionSub` receives DTO → `_liveSessionId` updated → `_flushPending` sends queued telemetry with the correct new ID

Without the fix, step 3 would use the stale `_liveSessionId` from the previous session, tagging telemetry with the wrong server-assigned session ID.

### Race condition check

Could `_liveSessionSub` receive a stale event between `reset()` and the new `startSession()`? The notifier may emit the old session's terminal state (which maps to `liveSessionId: null` via `LiveBreathSessionState.initial()`). Either way, after `reset()` the coordinator correctly waits for a non-null `liveSessionId` before sending telemetry — the explicit null assignment makes this deterministic rather than dependent on stream timing.

### Subscription lifecycle

`_liveSessionSub` and `_subscription` survive `reset()` (comment: "subscription stays alive — stream is reused across restart"). This is correct — both are long-lived streams that span session restarts. They are only cancelled in `dispose()`.

### ROADMAP checkbox

All four items in section 3.5 are now checked. This unblocks 3.6 (Socket.io file removal). Verified the other three items were already checked in the pre-existing file.

## Verdict

Minimal, correct, defensive fix. No type mismatches, no race conditions introduced, no missing migrations.

REVIEW_PASS
