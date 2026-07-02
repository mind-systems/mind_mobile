# Root/child — session registry in `ModuleStateChannel` (root + N children)

**Date:** 2026-07-02
**Source:** conversation context; handoff `12-mobile-root-child-rollout.md`

## Key Findings

- Today the client models **one** active session: `ModuleState { moduleSessionId, status, isPaused }` published via a single `BehaviorSubject<ModuleState>` (`lib/Core/Grpc/ModuleState.dart:22`). Every incoming `StateEvent` overwrites it (`ModuleStateChannel.dart:82-160`).
- The new model is **one root + N flat children**, each a normal module session distinguished only by `activity_type` (`ROOT` ⇒ root; `BREATH`/`MEDITATION` ⇒ child). Two children of the same type at once is a bug — so a frame maps to its adapter unambiguously by `activity_type`.
- Core architectural task: turn `ModuleStateChannel` into transport + a **session registry**. `rootId` is a computed getter (the entry with `activity_type==ROOT`), not a stored field — root is just another session that happens to have no `rootId`.
- Depends on note 13 (needs `StateEvent.activity_type`).
- **This is the IMPL milestone.** The `ModuleSession` type + `SessionRegistry` signatures and the RED routing tests are a **separate contract milestone (note 22)** laid first; this task fills the routing bodies and turns those tests green.

## Details

### Current state (exact)
- `ModuleStateChannel._processProtoEvent` (`ModuleStateChannel.dart:125-161`) parses each `StateEvent`, extracts `moduleSessionId`+`status` (`:129,:132,:136,:141`), routes by `proto.ActivityStatus` (RESUMED `:127`, ACTIVE `:134`, COMPLETED/INTERRUPTED `:149`, ABANDONED `:152`, UNSPECIFIED `:155`), overwrites the single `_state` `BehaviorSubject<ModuleState>` (`:22`) and emits typed events on `_events` `PublishSubject` (`:23`).
- `ModuleState` (`lib/Core/Grpc/ModuleState.dart`): `{ String? moduleSessionId; ModuleStateStatus status; bool isPaused }`; `ModuleStateStatus { idle, active }`; `ModuleState.initial()` = `{null, idle, false}`.
- `ModuleStateEvent` (`lib/Core/Grpc/ModuleStateEvent.dart`) sealed: `ModuleSessionStarted{moduleSessionId?}`, `ModuleSessionResumed{moduleSessionId?}`, `ModuleSessionPaused`, `ModuleSessionUnpaused`, `ModuleSessionEnded`, `ModuleSessionAbandoned` (no fields on the last four).
- **Client-side single-session guard (must change):** `start()` early-returns if a session is already active — `if (currentState.status == ModuleStateStatus.active || _isPendingStart) return;` (`ModuleStateChannel.dart:166`). This blocks a second concurrent child on the client and must be replaced by a per-`activity_type` check against the registry (adopt-existing lives in note 19). `_isPendingStart` is a single bool (`:31`) — becomes per-type (note 19).
- `ModuleState` is the sole shared state; consumers (adapters, bio, instruction) read one `moduleSessionId`.

### Change
- Introduce a `ModuleSession` value type `{ id, activityType, status, isPaused }` and a registry `Map<String, ModuleSession>` keyed by `module_session_id` inside `ModuleStateChannel` (or a small `SessionRegistry` owned by it).
- Rewrite the response handler: **upsert** by `module_session_id` on each `StateEvent` (carry `activity_type`); **remove** the entry on terminal statuses (`COMPLETED`/`ABANDONED`). Continue emitting the existing typed `ModuleStateEvent`s so downstream keeps working during migration.
- Add derived accessors: `String? get rootId` = the sole entry with `activityType == root`; `ModuleSession? childOfType(ActivityType)` = the sole non-root entry of that type; streams so adapters/bio can react.
- Keep the single-stream transport (one bidi `TrackActivity`) — the registry is a routing layer on top, not a new connection.

### Guards
- Do not special-case root with a separate stored field — it is a normal registry entry; `rootId` is derived (user decision: uniform session model).
- Preserve the existing `ModuleStateEvent` surface enough that notes 15/17/18 can migrate onto the registry incrementally; do not break breath/meditation adapters in this task.
- Terminal-status removal must not drop the root implicitly on a child's COMPLETED.

### Verify
- Feeding a `ROOT` frame then a `BREATH` frame yields registry size 2, `rootId` = the root's id, `childOfType(breath)` = the breath child.
- A child COMPLETED frame removes only the child; root stays.
- Single-session flows (breath-only) still produce the same `ModuleStateEvent` sequence as before (characterization).
