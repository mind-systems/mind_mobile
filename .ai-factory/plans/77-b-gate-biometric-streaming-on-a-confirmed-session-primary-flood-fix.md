# Plan: B — Gate biometric streaming on a confirmed session (primary flood fix)

## Context
On a transport reconnect the biometric client keeps a stale `_currentSessionId` and immediately resumes streaming into a session the server may consider dead, producing the `NO_SESSION` flood. This milestone gates `sendBatch` on an explicit session-confirmed flag and adds a `RESUMED` re-confirmation event so the client only streams into a server-confirmed session.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Add the re-confirmation event

- [x] **Task 1: Add `ModuleSessionResumed` to the sealed event family**
  Files: `lib/Core/Grpc/ModuleStateEvent.dart`
  Add a new sealed-family member matching the existing `ModuleSessionStarted` idiom:
  ```dart
  class ModuleSessionResumed extends ModuleStateEvent {
    final String? moduleSessionId;
    ModuleSessionResumed({this.moduleSessionId});
  }
  ```
  Place it next to `ModuleSessionStarted` (`ModuleStateEvent.dart:3-6`). Because `ModuleStateEvent` is `sealed`, the analyzer will now force every exhaustive `switch` over it to handle the new case (addressed in Tasks 3 and 4).

- [x] **Task 2: Emit `ModuleSessionResumed` from a dedicated `RESUMED` branch** (depends on Task 1)
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  In `_processProtoEvent` (`:116-145`), split `RESUMED` out of the shared `ACTIVE || RESUMED` branch (`:118`). Add a new branch handled **before** the `ACTIVE` branch:
  - On `status == proto.ActivityStatus.RESUMED`: update `_state` exactly as the active branch does today (`_isPendingStart = false; _isPendingPause = false; _state.add(ModuleState(moduleSessionId: ..., status: ModuleStateStatus.active, isPaused: ...))`), then `_events.add(ModuleSessionResumed(moduleSessionId: moduleSessionId))`, and **return** — do not fall through to the `isNew → ModuleSessionStarted` path (avoids a double-emit if `currentState` was idle when `RESUMED` arrived).
  - Leave the existing `ACTIVE`-only branch otherwise unchanged (it keeps emitting `ModuleSessionStarted` / `ModuleSessionPaused` / `ModuleSessionUnpaused`).
  Rationale: `unpause` returns `ACTIVE` (not `RESUMED`), so `RESUMED` is exclusively the grace-reconnect signal — this split is non-breaking.

### Phase 2: Gate the biometric client

- [x] **Task 3: Gate `sendBatch` on a confirmed session** (depends on Task 1, Task 2)
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  - Add field `bool _sessionConfirmed = false;` near `_currentSessionId` (`:30`).
  - In `_onLifecycleEvent` (the exhaustive switch, `:73-87`):
    - `ModuleSessionStarted(:final moduleSessionId)` → `_currentSessionId = moduleSessionId; _sessionConfirmed = true; _lastOpenAttempt = null;` (a fresh start is confirmed by definition).
    - Add new case `ModuleSessionResumed(:final moduleSessionId)` → `_currentSessionId = moduleSessionId; _sessionConfirmed = true; _lastOpenAttempt = null;` (destructure exactly like the `Started` case).
    - `ModuleSessionEnded() || ModuleSessionAbandoned()` → keep existing clears plus `_sessionConfirmed = false;`.
    - `ModuleSessionPaused()` / `ModuleSessionUnpaused()` → unchanged (`break`). Do **not** touch `_sessionConfirmed` on pause/unpause — pause keeps the session alive and confirmed.
  - In the connection-state listener (`:59-68`), on `GrpcConnectionState.disconnected`, after the existing `_teardownSink()` call, set `_sessionConfirmed = false;` — the retained `_currentSessionId` is now provisional.
  - In `sendBatch` (`:92`), change the gate to `if (_currentSessionId == null || !_sessionConfirmed) return;`. Unconfirmed samples are dropped (no-op) — do **not** enqueue them into the replay ring.
  - Guards: do NOT touch the replay ring, the readiness gate / `_isReady`, the 5 s ready timer, or the 2 s reopen cooldown. `logPrint` only for any logging.

- [x] **Task 4: Satisfy the exhaustiveness check in `KeepAliveCoordinator`** (depends on Task 1)
  Files: `lib/Core/Background/KeepAliveCoordinator.dart`
  `_onEvent` (`:26-39`) is a second exhaustive `switch` over `ModuleStateEvent`; the analyzer will now require the new case. Add `case ModuleSessionResumed():` as a no-op (`break`) alongside the existing `ModuleSessionPaused()` / `ModuleSessionUnpaused()` no-op cases — resume must not re-`start()` the foreground keep-alive (the session was already running before the reconnect).

## Notes / Out of scope
- `HomeService.observeChanges` (`HomeService.dart:59-61`) filters events with `.where((e) => e is ModuleSessionEnded)`, so it is unaffected by the new event — no change needed.
- This milestone is the primary flood fix and is independently shippable (no dependency on tasks A/note 152 or C/note 154). Keep note 143's reactive `NO_SESSION` teardown in place as the defense-in-depth backstop — do not remove it.

## Commit
Single commit after all tasks: "Gate biometric streaming on a confirmed session"
