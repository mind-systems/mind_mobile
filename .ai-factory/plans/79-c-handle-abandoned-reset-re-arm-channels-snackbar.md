# Plan: C — Handle `ABANDONED`: reset + re-arm channels + snackbar

## Context
When the server confirms a dead session with one `sessionState{ABANDONED}`, reset the client to idle, re-arm the Breath and Meditation module channels so the next `activity:start` is not suppressed by stale latches, and surface a transient error snackbar. Depends on milestone A (`[[152-present-module-session-id-on-reconnect]]`).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Re-arm module channels on abandonment

- [x] **Task 1: Re-arm `BreathModuleStateChannel` on `ModuleSessionAbandoned`**
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  The channel currently only subscribes to `channel.state` (`:38-42`), which ignores the `null` `moduleSessionId` carried by `ModuleState.initial()` on abandon. Add a second, **additive** subscription in the constructor: `_eventsSub = channel.events.listen(...)` (declare `late final StreamSubscription<ModuleStateEvent> _eventsSub;` next to `_stateSub`/`_channelSub` at `:26-27`). In the handler, on `ModuleSessionAbandoned` call the existing `reset()` (`:137-148`) — this becomes its first caller; ignore all other event types. Import `package:mind/Core/Grpc/ModuleStateEvent.dart`. Keep the existing `channel.state` subscription untouched. Cancel `_eventsSub` in `dispose()` alongside `_stateSub`/`_channelSub` (`:155-156`).

- [x] **Task 2: Re-arm `MeditationModuleStateChannel` on `ModuleSessionAbandoned`**
  Files: `lib/MeditationModule/Core/MeditationModuleStateChannel.dart`
  This channel has no `reset()` and no `_pendingInstruction`. Add the same additive `channel.events` subscription (`late final StreamSubscription<ModuleStateEvent> _eventsSub;` near `:15-16`, subscribed in the constructor at `:24-29`). On `ModuleSessionAbandoned`, re-arm inline mirroring the existing re-arm at `:45-46`: `_started = false; _ended = false; _moduleSessionId = null; _previousStatus = null;`. Import `package:mind/Core/Grpc/ModuleStateEvent.dart`. Keep the existing `channel.state` subscription untouched. Cancel `_eventsSub` in `dispose()`. While here, fix the stale comment at `:44` that cites `reset() (BreathModuleStateChannel.dart:110-113)` → update to `:137-148`.

### Phase 2: Demote the defensive `no_active_session` path

- [x] **Task 3: Demote `sessionError.code == 'no_active_session'` to a silent defensive reset**
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  This `sessionError` is a pause/resume command-rejection (stale client view), **not** the abandonment signal — abandonment is exclusively `sessionState{ABANDONED}` (already handled at `:149-151`). In the `sessionError` branch of the `_sessionSub` listener (today log-only at `:92-93`), when `r.sessionError.code == 'no_active_session'`, call `_state.add(ModuleState.initial())` (a silent stale-state reconciliation — it must emit **no** event and **no** snackbar). Keep the existing `logPrint`, and keep all other error codes log-only. Do not disturb the `RESUMED` path.

### Phase 3: Surface the ABANDONED snackbar

- [x] **Task 4: Add `sessionAbandonedStream` handling to `GlobalListeners`**
  Files: `lib/Core/GlobalUI/GlobalListeners.dart`
  Mirror the existing `sessionExpiredStream` plumbing exactly. Add a `final Stream<void> sessionAbandonedStream` field next to `sessionExpiredStream` (`:18`) and to the constructor (`:21-25`). Add `StreamSubscription<void>? _sessionAbandonedSubscription;` (`:32`), subscribe it in `initState` (`:37-39`) → `_showSnackBar(SnackBarEvent.error(_sessionAbandonedMessage()))`, and cancel it in `dispose` (`:44`). Add `_sessionAbandonedMessage()` mirroring `_sessionExpiredMessage()` (`:64-69`): resolve from `rootScaffoldMessengerKey.currentContext` → `AppLocalizations.of(context)?.sessionAbandoned ?? 'Session ended unexpectedly'`. Reuse the existing `_showSnackBar` (`:71-74`). Update the class doc comment to mention the abandonment stream.

- [x] **Task 5: Wire `sessionAbandonedStream` at the construction site** (depends on Task 4)
  Files: `lib/Core/App.dart`
  In the `GlobalListeners(...)` builder (`:309-312`), alongside `sessionExpiredStream: App.shared.userNotifier.sessionExpiredStream`, pass `sessionAbandonedStream: App.shared.moduleStateChannel.events.where((e) => e is ModuleSessionAbandoned).map((_) {})`. `moduleStateChannel` is already a public `App` field and `.events` is the same stream fed to `BiometricStreamClient` — no new field to expose. Ensure `ModuleStateEvent` (for `ModuleSessionAbandoned`) is imported.

- [x] **Task 6: Regenerate localizations** (depends on Task 4)
  Files: `packages/mind_l10n/lib/l10n/app_en.arb`, `packages/mind_l10n/lib/l10n/app_ru.arb` (generated `AppLocalizations`)
  The `sessionAbandoned` keys already exist in both ARBs (`app_en.arb:11` → `"Session ended unexpectedly"`, `app_ru.arb:11` → `"Сессия неожиданно завершилась"`), but the generated getter is not yet produced. Run the project's localization gen command (`flutter pub run build_runner build` / `flutter gen-l10n` per the package setup) so `AppLocalizations.sessionAbandoned` resolves for Task 4. Use the full Flutter path (`/usr/local/bin/flutter`).

## Commit Plan
- **Commit 1** (after tasks 1-2): "Re-arm breath and meditation channels on session abandonment"
- **Commit 2** (after task 3): "Demote no_active_session to silent defensive reset"
- **Commit 3** (after tasks 4-6): "Show snackbar on session abandonment"
