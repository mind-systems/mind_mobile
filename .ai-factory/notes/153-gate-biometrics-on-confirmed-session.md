# Gate biometric streaming on a confirmed session (kill the NO_SESSION flood at the source)

**Date:** 2026-06-23
**Source:** handoff 09 §10.2 — the load-bearing client invariant. Settled contract: `mind_api/.ai-factory/notes/62-reconnect-no-session-terminal-event.md`.

## Key Findings

- On a transport reconnect (`GrpcConnectionState.disconnected → connected`), `BiometricStreamClient._currentSessionId` is **not** cleared — only `ModuleSessionEnded`/`ModuleSessionAbandoned` clear it (`lib/Biometrics/BiometricStreamClient.dart:82-86`). So after a background→resume reconnect the client retains the old session id and `sendBatch` (`:91-96`) immediately resumes streaming into a session the server may already consider gone → the `NO_SESSION` flood (observed 600+/min).
- The fix is **proactive, not reactive**: never stream into an *unconfirmed* session. On reconnect the retained `_currentSessionId` is provisional — suspend sends until the server re-confirms it via `RESUMED` (grace reconnect) or until a fresh `activity:start` mints a new one. This removes the flood at the source; the reactive `NO_SESSION` teardown (note 143) stays only as a defense-in-depth backstop for `INTERNAL_ERROR` / un-emitted edges.

## The re-confirmation signal (the one real design decision)

`ModuleStateChannel._processProtoEvent` (`lib/Core/Grpc/ModuleStateChannel.dart:116-145`) folds `RESUMED` into the `ACTIVE` branch and only emits `ModuleSessionStarted` when `isNew` (`:122,126`). On reconnect `currentState` is still `active` (the channel does **not** reset `_state` on `_closeSessionStream`), so `isNew` is false and **no event is emitted** — `BiometricStreamClient` (which listens only to `moduleStateEvents`) would never learn the session was re-confirmed.

So this task adds an explicit resume event, **matching the existing sealed-family idiom** (`ModuleSessionStarted` is `ModuleSessionStarted({this.moduleSessionId})` with a nullable named `String? moduleSessionId` — `lib/Core/Grpc/ModuleStateEvent.dart:3-6`):

```dart
class ModuleSessionResumed extends ModuleStateEvent {
  final String? moduleSessionId;
  ModuleSessionResumed({this.moduleSessionId});
}
```

- In `_processProtoEvent` (`lib/Core/Grpc/ModuleStateChannel.dart:116-145`), split `RESUMED` into its **own branch** (today it shares the `ACTIVE` branch at `:118`). On `status == proto.ActivityStatus.RESUMED`: update `_state` as today, then `_events.add(ModuleSessionResumed(moduleSessionId: moduleSessionId))`, and **return** — do not fall through to the `isNew → ModuleSessionStarted` path (which would double-emit if `currentState` happened to be idle when RESUMED arrives). `RESUMED` is exclusively the grace-reconnect signal — `unpause` returns `ACTIVE` (`module-state.grpc.controller.ts:383`), not `RESUMED` — so this split is non-breaking.
- `ModuleStateEvent` is `sealed` (`ModuleStateEvent.dart:1`); the analyzer forces the new case in the only exhaustive switch — `BiometricStreamClient._onLifecycleEvent` (`lib/Biometrics/BiometricStreamClient.dart:73-87`). `HomeService.dart:60` uses `.where`, so it is unaffected.

## BiometricStreamClient changes

- Add `bool _sessionConfirmed = false`.
- `_onLifecycleEvent` (the exhaustive switch, `:73-87`) — destructure with `(:final moduleSessionId)` as the existing `ModuleSessionStarted` case does (`:75`):
  - `ModuleSessionStarted(:final moduleSessionId)` → `_currentSessionId = moduleSessionId; _sessionConfirmed = true; _lastOpenAttempt = null` (a fresh start is confirmed by definition).
  - new `ModuleSessionResumed(:final moduleSessionId)` → `_currentSessionId = moduleSessionId; _sessionConfirmed = true; _lastOpenAttempt = null`.
  - `ModuleSessionEnded() || ModuleSessionAbandoned()` → `_currentSessionId = null; _sessionConfirmed = false; _replayRing.clear()` (existing, plus the flag).
- Connection-state listener (`:59-68`): on `disconnected`, after `_teardownSink()`, set `_sessionConfirmed = false` — the retained `_currentSessionId` becomes provisional.
- `sendBatch` gate (`:92`): `if (_currentSessionId == null || !_sessionConfirmed) return;` — unconfirmed samples are dropped (no-op), **not** buffered into the replay ring (we don't know the session is alive; a lost sub-second-to-grace window is acceptable, per handoff §10.2).

## Guards

- Do NOT touch the replay ring, the readiness gate (note 115), the 2 s reopen cooldown, or the connection-state teardown.
- `_sessionConfirmed` resets on **disconnect** only — never on pause (pause keeps the session alive and confirmed).
- Keep note 143's reactive `NO_SESSION` teardown as the backstop — it is superseded as the *primary* fix, not removed.
- `logPrint` only.

## Relationship to A/C

- This is the **primary, immediate** fix and is independently shippable — it does not depend on tasks A (note 152) or C (note 154).
- A (`module-session-id` metadata, note 152) and C (`ABANDONED` handling, note 154) extend the protocol so the client gets a *definitive* abandonment answer; B keeps the client correct in the meantime by simply not streaming into anything unconfirmed.
- See `[[152-present-module-session-id-on-reconnect]]`, `[[154-handle-abandonment-confirmation]]`. Backstop detail in `[[143-biometric-client-no-session-handling]]`.
