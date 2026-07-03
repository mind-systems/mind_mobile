# Plan: Typed `SessionTerminated(reason)` event

## Context
Replace the failed plan's UI-silent `AllSessionsReset` + two `Stream<void>` signals + `Rx.merge` with a single typed `SessionTerminated(SessionTerminationReason)` event on `channel.events`: every consumer resets on any termination, and `GlobalListeners` switches on `reason` to pick the snackbar. The event is dormant — no emitter until the reconnect impl — so the type and all its exhaustive-switch consumers ship in the same commit (compile-ordering).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Termination type + reason-agnostic reset consumers

- [x] **Task 1: Add `SessionTerminationReason` enum and `SessionTerminated` event**
  Files: `lib/Core/Grpc/ModuleStateEvent.dart`
  Add `enum SessionTerminationReason { movedToAnotherDevice, abandoned, rootDeath }` (extensible — new whole-tree cases append here). Add `class SessionTerminated extends ModuleStateEvent { final SessionTerminationReason reason; SessionTerminated(this.reason); }` to the existing sealed hierarchy. This new variant makes every exhaustive `switch (ModuleStateEvent)` non-exhaustive until Tasks 2–3 add the case, which is why those ship in the same commit. Keep the existing `ModuleSessionAbandoned` variant unchanged (per-child abandon stays a distinct event).

- [x] **Task 2: Reset the bio stream on `SessionTerminated`** (depends on Task 1)
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  In `_onLifecycleEvent` (`:96-117`), add `case SessionTerminated():` to the exhaustive switch, merged with the existing terminal branch — i.e. `case ModuleSessionEnded() || ModuleSessionAbandoned() || SessionTerminated():` — so it runs the same reset body (`_currentSessionId = null; _sessionConfirmed = false; _lastOpenAttempt = null; _replayRing.clear();`). Reset is reason-agnostic; do not switch on `reason` here. Leave the `if (_rootSourced) return;` guard as-is.
  Note (for the downstream emitter, ROADMAP.md:91): in the shipped config `BiometricStreamClient` is always constructed with `rootIdChanges` (`App.dart:234`), so `_rootSourced == true` and this branch returns early at `:97` before any `case` runs — it exists for exhaustiveness only and never executes at runtime. Bio's actual whole-tree reset flows through `_onRootIdChanged(null)`, so the reconnect impl that emits `SessionTerminated` must **also** clear the registry root so `rootIdChanges` emits `null`; emitting `SessionTerminated` alone will not reset bio.

- [x] **Task 3: Stop the foreground keep-alive on `SessionTerminated`** (depends on Task 1)
  Files: `lib/Core/Background/KeepAliveCoordinator.dart`
  In `_onEvent` (`:46-60`), add `case SessionTerminated():` running the same body as `ModuleSessionAbandoned()` — `await _foregroundKeepAlive.stop();`. Restores exhaustiveness; reason-agnostic.

- [x] **Task 4: Reset both module adapters on `SessionTerminated`** (depends on Task 1)
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`, `lib/MeditationModule/Core/MeditationModuleStateChannel.dart`
  Breath (`:52-53`): change the listener guard to `if (event is ModuleSessionAbandoned || event is SessionTerminated) reset();`. Meditation (`:34-42`): extend the `if (event is ModuleSessionAbandoned)` condition to also match `SessionTerminated`, running the same inline re-arm reset (`_started/_ended/_moduleSessionId/_previousStatus/_clientActivityId`). Both remain reason-agnostic.

### Phase 2: Reason-switched termination snackbar

- [x] **Task 5: Add `sessionMovedToAnotherDevice` ARB key** (depends on Task 1)
  Files: `packages/mind_l10n/lib/l10n/app_en.arb`, `packages/mind_l10n/lib/l10n/app_ru.arb`
  Add `"sessionMovedToAnotherDevice"` next to the existing `sessionAbandoned` key. EN: `"Session moved to another device"`. RU: `"Сессия перенесена на другое устройство"`. After editing, regenerate `AppLocalizations` (`flutter gen-l10n` / `flutter pub run build_runner build` per project setup) so the getter exists before Task 6 references it.

- [x] **Task 6: Switch `GlobalListeners` on `reason` and wire it in `App.dart`** (depends on Tasks 1, 5)
  Files: `lib/Core/GlobalUI/GlobalListeners.dart`, `lib/Core/App.dart`
  In `GlobalListeners`, add `import 'package:mind/Core/Grpc/ModuleStateEvent.dart';` (the file currently imports only material/riverpod/GlobalKeys/mind_l10n/mind_ui and has no access to `SessionTerminationReason`). Add a `final Stream<SessionTerminationReason> sessionTerminatedStream;` constructor field with a matching `StreamSubscription`. Subscribe once in `initState` and **switch on the reason** exhaustively: `movedToAnotherDevice` → error snackbar using the new `sessionMovedToAnotherDevice` copy (resolve via `AppLocalizations.of(context)?.sessionMovedToAnotherDevice`, fallback `'Session moved to another device'`, mirroring `_sessionAbandonedMessage()`); `abandoned` and `rootDeath` → the existing `_sessionAbandonedMessage()` ("ended unexpectedly"). Cancel the subscription in `dispose`. Leave the existing `sessionAbandonedStream` (per-child `ModuleSessionAbandoned`) path untouched — single-child abandon is not a whole-tree termination. In `App.dart` (`:319-323`), pass `sessionTerminatedStream: App.shared.moduleStateChannel.events.where((e) => e is SessionTerminated).map((e) => (e as SessionTerminated).reason)` — use core-`Stream` `.where(...).map(...)` (matching the adjacent `sessionAbandonedStream` line at `:321`), **not** rxdart's `.whereType<T>()`, which `App.dart` does not import. One subscription, one switch — no `Rx.merge`, no second signal.

## Commit Plan
- **Commit 1** (after tasks 1-4): "Add typed SessionTerminated event and reason-agnostic reset consumers"
- **Commit 2** (after tasks 5-6): "Switch termination snackbar on reason with moved-to-another-device copy"
