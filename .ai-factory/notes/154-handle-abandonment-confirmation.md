# Handle the `ABANDONED` confirmation → reset to idle + re-arm channels

**Date:** 2026-06-23
**Source:** handoff 09 §10.3. Settled contract: `mind_api/.ai-factory/notes/62-reconnect-no-session-terminal-event.md`.

**UX decision:** on ABANDONED, surface a transient error snackbar (mirrors the session-expiry snackbar) and reset to idle. Not silent. The snackbar is additive — the load-bearing reset/re-arm (changes 1-3) is unchanged.

## Key Findings

- After presenting `module-session-id` on reconnect (`[[152-present-module-session-id-on-reconnect]]`), the server answers a dead session with exactly one `sessionState{ status: ABANDONED, moduleSessionId }` and keeps the stream open (the client may immediately `activity:start` a fresh session on it).
- `ModuleStateChannel._processProtoEvent` already maps `ABANDONED` → `ModuleSessionAbandoned` and resets `_state` to `ModuleState.initial()` (`lib/Core/Grpc/ModuleStateChannel.dart:136-138`). `BiometricStreamClient` already clears its session + ring on `ModuleSessionAbandoned` (`lib/Biometrics/BiometricStreamClient.dart:82-86`, wired via `moduleStateChannel.events`, `lib/Core/App.dart:220`). What is missing is **re-arming the module channels** so the next `activity:start` is not suppressed by a stale `_started`/`_ended` latch.

## The wiring trap (do not repeat the earlier draft's error)

The module channels do **not** observe `ModuleSessionAbandoned` today. Both subscribe to `channel.state` (`Stream<ModuleState>` — the snapshot), not `channel.events` (`Stream<ModuleStateEvent>` — the typed events):
- `BreathModuleStateChannel._channelSub = channel.state.listen(...)` (`lib/BreathModule/Core/BreathModuleStateChannel.dart:38-42`) — acts only when `moduleSessionId != null` (flushes pending); **ignores the null** that `ModuleState.initial()` carries on abandon.
- `MeditationModuleStateChannel._channelSub = channel.state.listen(...)` (`lib/MeditationModule/Core/MeditationModuleStateChannel.dart:25-29`) — updates `_moduleSessionId` only when non-null; **ignores the null** likewise.

So the abandon reset never reaches the channels through `state`. The fix is an **explicit new subscription to `channel.events`** in each channel that handles `ModuleSessionAbandoned`.

## Changes

1. **Re-arm `BreathModuleStateChannel` on `ModuleSessionAbandoned`.** Add a second subscription `_eventsSub = channel.events.listen(...)` in the constructor (cancel it in `dispose()` alongside `_stateSub`/`_channelSub`, `:155-156`). On `ModuleSessionAbandoned`, call the **existing** `reset()` (`BreathModuleStateChannel.dart:137-148`) — it already clears `_moduleSessionId/_started/_ended/_previousStatus/_previousPhase/_previousExerciseIndex/_pendingInstruction/_stopwatch/_originWallClock` and keeps the subscriptions alive. `reset()` currently has **no caller**; this becomes its first.

2. **Re-arm `MeditationModuleStateChannel` on `ModuleSessionAbandoned`.** It has **no `reset()`** and no `_pendingInstruction`. Add the same `channel.events` subscription; on `ModuleSessionAbandoned` re-arm inline: `_started = false; _ended = false; _moduleSessionId = null; _previousStatus = null;` (mirrors the existing inline re-arm at `MeditationModuleStateChannel.dart:45-46`). While here, fix the stale comment at `:44` that cites `reset() (BreathModuleStateChannel.dart:110-113)` → now `:137-148`.

3. **Demote `sessionError.code == 'no_active_session'` to a defensive no-op reset.** The server emits this `sessionError` only as a **command-rejection** on pause/resume when no session is active (`module-state.grpc.controller.ts:362-371` / `:387-396`, via `activity-engine.service.ts:343,375` throwing `WsErrorCode.NO_ACTIVE_SESSION = 'no_active_session'`, `ws-error-codes.ts:5`) — it is **not** the abandonment signal (that is exclusively the `ABANDONED` sessionState above). It is still a valid "client view is stale" signal: from the `sessionError` branch in `ModuleStateChannel._processProtoEvent`/the listener (today log-only at `ModuleStateChannel.dart:87`), on the literal `'no_active_session'` reset `_state` to `ModuleState.initial()` (which already fans out `ModuleSessionAbandoned`-equivalent idle); keep other codes log-only.

4. **Surface an `ABANDONED` snackbar via `GlobalListeners` (mirror `sessionExpiredStream`).** The session-expiry snackbar is already built exactly the shape we need; clone it.
   - Add a second `final Stream<void> sessionAbandonedStream` field to `GlobalListeners` next to the existing `sessionExpiredStream` (`lib/Core/GlobalUI/GlobalListeners.dart:18`), wired identically: a `StreamSubscription<void>? _sessionAbandonedSubscription` subscribed in `initState` (`:37-39`) → `_showSnackBar(SnackBarEvent.error(_sessionAbandonedMessage()))`, cancelled in `dispose` (`:43-45`). Reuse the existing `_showSnackBar` (`:71-74`).
   - `_sessionAbandonedMessage()` mirrors `_sessionExpiredMessage()` (`:64-69`): resolve at show-time from `rootScaffoldMessengerKey.currentContext` → `AppLocalizations.of(context)?.sessionAbandoned ?? 'Session ended unexpectedly'` (no UI context exists at the event site).
   - `SnackBarEvent.error(String)` is the static factory at `packages/mind_ui/lib/src/SnackBarModule/Models/SnackBarEvent.dart:17`.
   - At the construction site (`lib/Core/App.dart:300-301`, alongside `sessionExpiredStream: App.shared.userNotifier.sessionExpiredStream` — itself a getter over a `PublishSubject<void>`, `lib/User/UserNotifier.dart:18,37,103`) pass `sessionAbandonedStream: App.shared.moduleStateChannel.events.where((e) => e is ModuleSessionAbandoned).map((_) {})`. `moduleStateChannel` is already a public `App` field (`lib/Core/App.dart:93`, assigned `:242`) and its `.events` stream is the same one fed to `BiometricStreamClient` (`:220`) — **no new field to expose.**
   - l10n: the `sessionAbandoned` key is added to both ARBs next to `sessionExpired` (`packages/mind_l10n/lib/l10n/app_en.arb:10` → `"Session ended unexpectedly"`, `app_ru.arb:10` → `"Сессия неожиданно завершилась"`). Regenerate localization with the project's usual gen command before referencing the generated getter.

### Snackbar scope boundary (do not over-attach)

- The snackbar fires **only** on `ModuleSessionAbandoned` — the sole definitive death signal, emitted at `lib/Core/Grpc/ModuleStateChannel.dart:138`.
- The defensive `'no_active_session'` path (change 3) stays **silent**: it only `_state.add(ModuleState.initial())`, emits no event, and is benign stale-state reconciliation (a rejected pause/resume command), not a user-facing failure. Do **not** wire a snackbar there.

## Guards

- The snackbar flows through `GlobalListeners` off the existing App-layer `events` stream, **not** from the domain channels — `BreathModuleStateChannel`/`MeditationModuleStateChannel` stay Flutter-free, and the re-arm (changes 1-2) does not depend on the snackbar.
- Do not disturb the `RESUMED` reconnect path (note 153) — only `ABANDONED` and the defensive `'no_active_session'` trigger a reset.
- Never resurrect or auto-recreate a session — a new session is born only on explicit user `activity:start` (note 62 §Guards).
- The new `channel.events` subscriptions are **additive** — keep the existing `channel.state` subscriptions untouched.

## Relationship to A/B/C

- Depends on A (`[[152-present-module-session-id-on-reconnect]]`) — the server only sends `ABANDONED` once the client presents the id. Ship A before C.
- Independent of B (`[[153-gate-biometrics-on-confirmed-session]]`), which keeps biometrics correct regardless.
