# Root/child — reconnect / eviction / start-race concurrency contract

**Date:** 2026-07-02
**Source:** conversation context; `roadmap-decompose-skeleton` (Lens 3) over Phase 64

## Key Findings

- Phase 64's two impls — reconnect+eviction (note 20) and start-race hardening (note 19) — are **heavy** and each touches ≥2 hazard classes: async I/O (stream reopen / command send), stateful buffers (registry rebuild, `_yielded`/`_supersededSeen` flags, per-type pending-start), and lifecycle (reconnect / reconcile / yield / takeover / start-confirm-retry). They share one hazardous surface: the reconnect/reconcile flow.
- Their failures are **silent**: yield on a bare close → client stranded "on another device" through every deploy; miss reconcile → duplicate or lost child; wrong sequencing → new root wiped by a late reset. Per Lens 3 (canon m37), the invariants belong in a **contract-task** — invariant definitions + red scenarios per concurrent caller, **no production code** — before either impl.
- One combined contract (not two) because the reconcile surface is shared; note 20 impl turns the eviction/reconnect invariants green, note 19 impl turns the start-race invariants green.

## Details

### Invariants (write them down; assert them as red scenarios — NO production code)

**Eviction / close classification (note 20):**
- Yield (`_yielded = true`, passive, no reconnect) **iff** `session_error{CONNECTION_SUPERSEDED}` was seen on this stream before close (`_supersededSeen`). Bare graceful `onDone` (no code) → **reconnect** + reconcile. `onError` → reconnect.
- The `_yielded` latch gates `_openSessionStream` — a `GrpcConnectionManager` reopen (connectivity/app-resume/auth) while yielded must **not** re-take the session.
- `takeOverHere()` clears the latch and reopens; the takeover receives a clean **root** frame, **no** child frames.

**Reconnect / reconcile (note 20):**
- `rootId` is sourced from the RootStateChannel ROOT re-open, **never** from the reconnect fan-out (which carries no root frame).
- Registry is rebuilt by reconcile-by-arrival from the per-child RESUMED frames; a cached child with no arriving frame within the settling window is treated as gone.
- Global-reset-then-adopt ordering: an `{abandoned}` reset is applied before a subsequently-minted root repopulates the registry (idempotent).
- Resumed children adopt their real `is_paused` from the RESUMED frame.

**Start-race (note 19):**
- Retry a pending start **only** while unconfirmed (no confirming ACTIVE/RESUMED frame) → no duplicate.
- Retry reuses the **same** `client_activity_id`; never regenerate.
- Before sending a fresh start, **adopt** an already-live child of that type (`childOfType`).
- Within the settling window after reconnect, **defer** the adopt-vs-new decision until reconcile completes.
- Timings: confirm timeout 5s, max 2 retries, settling window 3s (note 19 §Pinned constants).

### Red scenarios per concurrent caller
- Drive breath + meditation adapters concurrently (the real two callers). Scenarios: two concurrent starts; start-then-drop-before-ACTIVE; reconnect-with-both-live (reconcile both); SUPERSEDED mid-session; bare close mid-session; app-resume while yielded; app-restart mid-start (adopt on resume).

### Guards
- No production code in this milestone — invariants + red scenarios only.
- Use stateful doubles / the real registry (m36); latch/flag/pending state must be exercised, not stubbed away.

### Verify
- Scenarios are RED; note 20 greens the eviction/reconnect set, note 19 greens the start-race set.
