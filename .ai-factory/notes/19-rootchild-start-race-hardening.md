# Root/child — start-race hardening (variant B): pending-start + timeout + retry keyed on `client_activity_id`

**Date:** 2026-07-02
**Source:** conversation context (decision #2, variant B)

## Key Findings

- The "tap into void" race: user taps Play → `activity:start` sent → connection drops before the confirming `session:state ACTIVE` frame arrives (or before the server even created the session). UI shows the practice running; the server has nothing (or has it but the client doesn't know). On reconnect the server resumes what it has; if the session was never created, it is silently lost.
- Blindly re-sending `start` on every reconnect is unsafe: within the ~10s dedup window the token dedups (fine), but after the window there is no "already exists" guard → duplicate child.
- Variant B (chosen): after `start`, the adapter **waits for a confirming ACTIVE frame** of its own `activity_type`; if none arrives (neither from the start nor from a reconnect resume) within a timeout, it **re-sends `start` with the same `client_activity_id`**. Self-limiting: retry happens only when no confirmation exists → there is no session to duplicate.
- Concurrent-practice residue: on reconnect the server today emits **one** collapsed frame (`soleChild ?? root`, `activity-engine.service.ts:639`), so with 2 live children a second child's resume is not individually confirmed → could retry into a duplicate if >10s. This is closed by an **API-side follow-up (per-child RESUMED on reconnect)** owned by the mind_api side; the client is built to consume it via reconcile-by-arrival (note 20). Without it, B is airtight for single practices and leaves the rare concurrent duplicate.
- Depends on notes 14, 16.
- **This is the IMPL milestone.** The start-race invariants + red scenarios (retry-only-unconfirmed, same-token, adopt-existing, settling-window defer, 5s/2-retry/3s timings) are part of the **combined concurrency contract milestone (note 24)** laid first; this task turns the start-race half green.
- **RE-PLAN after the refactor (notes 25/26) and the reconnect impl.** Land the pending-start/retry on the settled `ConnectionLifecycle` FSM (note 25) and the reconcile surface the reconnect impl builds — not on loose flags. Apply the same comprehensive test-migration discipline: audit and migrate every affected `module_state_channel_test.dart` assertion in one pass.

## Details

> **Line numbers below are pre-refactor; re-pin at plan time against the post-refactor tree.** This task lands AFTER the connection-lifecycle FSM (note 25) and the reconnect impl (note 20), both of which move code inside `ModuleStateChannel`. The pending-start logic stays **command-level** (note 25 explicitly keeps `_isPendingStart`/`_isPendingPause` out of the FSM), so it is orthogonal to the FSM — but the exact `:NN` refs will shift.

### Current state (exact)
- Adapters set local started/ended flags on `start`/`end` and never verify the server confirmed (`BreathModuleStateChannel.dart:86-93`, `MeditationModuleStateChannel.dart:48-50`). No pending-start tracking, no timeout, no retry.

### Adopt-existing-child rule (app-restart / takeover)
- After an app kill + restart (within grace) or a takeover reconnect, the server **resumes** the old live child and emits a RESUMED frame → it lands in the registry (note 14/20). The lost in-memory `client_activity_id` is irrelevant: the registry, not the token, is the source of truth for "is a child of this type already live."
- **The start path first checks the registry: if a live child of the requested `activity_type` already exists (`childOfType`), ADOPT it — do not send a new `start`.** Only send a fresh `start` when no live child of that type is present. This prevents a duplicate second child (server has no singleton guard — mind_api note 06 — so a blind start would create one) and means the client is never blocked waiting for the old session to be abandoned.
- **Race (resolved — defer):** if the user taps Play before the resumed old child's frame has landed, the adopt check is empty → a new `start` goes out → the old child then arrives → two same-type children. **Resolution: defer the adopt-vs-new decision during the reconnect settling window** (3s after `GrpcConnectionManager.confirmConnected`, see §Pinned constants) — hold the start until reconcile completes, then adopt if a live child of that type surfaced, else send. The alternative (let the duplicate be created then end it) is rejected — deferral is deterministic and needs no extra server round-trip. Deferral applies **only** while the settling window is active (right after a reconnect); in steady state and offline there is no deferral, so normal Play latency is unaffected.

### Change
- Track a **pending start** per adapter: `{ clientActivityId, activityType, sentAt }` set on `start`, cleared when a registry frame of that `activity_type` with status ACTIVE/RESUMED appears (note 14).
  - Today the only pending-start tracking is a single bool `ModuleStateChannel._isPendingStart` (`ModuleStateChannel.dart:31`, set `:167`, cleared on any ACTIVE/RESUMED/UNSPECIFIED frame `:130,:139,:156`). Replace it with per-`activity_type` pending tracking so concurrent starts don't clear each other.
- Add a client-side confirm timeout; on expiry with the pending unresolved and the transport up, re-send `start` with the **same** `clientActivityId` (note 16). Reset the timeout on each attempt; bound the retries (see §Pinned constants).
- On reconnect, resolve pending starts by **reconcile-by-arrival** (note 20): a matching RESUMED frame clears the pending; absence past the settling window triggers a same-token re-send.

### Pinned constants (from source anchors — a value here is a chosen default, not a fantasy)
- **Confirm timeout = 5s** per start attempt. Anchored to the existing "wait for server readiness" timeout `BiometricStreamClient._readyTimeout` (`BiometricStreamClient.dart:59,66`, `const Duration(seconds: 5)`) — reuse the same magnitude for consistency.
- **Max retries = 2** (3 total attempts). After that, give up and surface a failure (below).
- **Settling window = 3s** measured from `GrpcConnectionManager.confirmConnected()` (`GrpcConnectionManager.dart:104`), i.e. once the reopened stream delivers its first frame (`ModuleStateChannel.dart:83-86`). Chosen > the bio 2s reopen cooldown (`BiometricStreamClient.dart:135`) and << the backoff ceiling (`BackoffConfig.maxDelay = 30s`, `BackoffConfig.dart:13`). The window bounds how long adopt-vs-new is deferred and how long reconcile waits for RESUMED frames.
- **Give-up surface:** after retries exhaust, emit the same user-facing snackbar path already used for `ModuleSessionAbandoned` (routed via `channel.events` → `GlobalListeners`, `docs/core/global-listeners.md`; SnackBar via `packages/mind_ui` `SnackBarModule`). Add a new l10n ARB key for the "couldn't start session" copy — do not fabricate the string here; wire the key at implement time.

### Guards
- Reuse the same `client_activity_id` across retries — never mint a new one (would duplicate).
- Retry only while unconfirmed; a confirmed frame must cancel the pending immediately.
- Do not resend `start` for children the server already resumed (reconcile clears them first).

### Verify
- Drop the connection between `start` and the ACTIVE frame → after timeout the client re-sends the same token → exactly one child on the server.
- Fast reconnect (<window) with the session already created → re-send dedups → no duplicate.
- Single-practice tap-into-void no longer loses the session.
