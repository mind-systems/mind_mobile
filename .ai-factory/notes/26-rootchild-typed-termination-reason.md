# Root/child — typed `SessionTerminated(reason)` event (kill the two-signal snackbar plumbing)

**Date:** 2026-07-03
**Source:** conversation context; milestone-rescue diagnosis of the failed reconnect plan

## Key Findings

- The failed plan modelled four termination cases (per-child abandon / generic abandon / root-death / eviction) as **plumbing**: a UI-silent `AllSessionsReset` event + two mutually-exclusive `Stream<void>` signals (`_sessionReset`, `_sessionMoved`) + an `Rx.merge` in App wiring — and review-1 still caught a double-snackbar because a signal was routed to two places. That is a band-aid around a missing **typed reason**.
- Fix: one event `SessionTerminated(SessionTerminationReason reason)` on `channel.events`. Consumers reset on **any** termination (regardless of reason); the UI **switches on `reason`** to pick the snackbar. One event + one switch replaces the event-plus-two-signals-plus-merge.
- **Dormant.** This task adds the type + event + all consumer handling; no path emits it yet (the re-planned reconnect impl emits it with a reason). Compile-ordering mirrors the concurrency-contract commit: the event and its exhaustive-switch consumers ship together so the tree never carries a non-exhaustive `switch`.

## Details

### Current state (exact)
- `ModuleStateEvent` (`lib/Core/Grpc/ModuleStateEvent.dart`) sealed: `ModuleSessionStarted/Resumed/Paused/Unpaused/Ended/Abandoned`. Exhaustive switches over it live in `BiometricStreamClient._onLifecycleEvent` (`:86-106`) and `KeepAliveCoordinator._onEvent`.
- Per-child abandon already shows a snackbar via `ModuleSessionAbandoned` → `GlobalListeners` (`docs/core/global-listeners.md`).
- The whole-tree reset cases (generic `{abandoned}` UNSPECIFIED frame, root-death, eviction) have **no** event yet — the failed plan was going to add `AllSessionsReset` + two signals.

### Change
- Add `enum SessionTerminationReason { movedToAnotherDevice, abandoned, rootDeath }` (extensible) and `class SessionTerminated extends ModuleStateEvent { final SessionTerminationReason reason; }`.
- Consumers reset on **any** `SessionTerminated`: add the `case SessionTerminated():` to both exhaustive switches (`BiometricStreamClient`, `KeepAliveCoordinator`) with the same reset body they use for `ModuleSessionAbandoned`; adapters (`BreathModuleStateChannel`, `MeditationModuleStateChannel`) reset on it too.
- UI: `GlobalListeners` subscribes once and **switches on `reason`** — `movedToAnotherDevice` → "moved to another device" snackbar (new ARB key, `sessionMovedToAnotherDevice`); `abandoned`/`rootDeath` → the existing "ended unexpectedly" message. One subscription, one switch — no `Rx.merge`, no second signal.
- Keep the existing per-child `ModuleSessionAbandoned` snackbar path unchanged (single-child abandon is not a whole-tree termination).

### Guards
- No emitter in this task — `SessionTerminated` is dormant until the reconnect impl fires it. Consumers ship in the same commit as the type (compile-ordering).
- One typed event, not an event-plus-two-signals; the reason lives on the event, not in separate streams.
- Reset is reason-agnostic; only the snackbar switches on reason.

### Verify
- Tree compiles (both exhaustive switches carry the new case); no emitter yet.
- Red tests: each `reason` → adapters/bio/keep-alive reset; `GlobalListeners` shows the reason-appropriate snackbar (`movedToAnotherDevice` ≠ `abandoned` copy). A single termination raises exactly one snackbar.
