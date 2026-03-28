# Plan: Delete `LiveBreathSessionNotifier`

## Context

`LiveBreathSessionNotifier` is a domain-layer state machine that duplicates `ModuleStateChannel` 1:1 — same state shape, same pending guards, same event types, same auth-reset logic. The only difference is that `LiveBreathSessionNotifier` consumes a `Map<String, dynamic>` backward-compat bridge (`ILiveSessionService.sessionStateEvents`) instead of reading typed proto events directly. Now that `ModuleStateChannel` is fully implemented, the notifier is dead weight. This milestone removes it and rewires the two consumers (`LiveBreathSessionService` and `HomeService`) to use `ModuleStateChannel` directly.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Rewire consumers to `ModuleStateChannel`

- [x] **Task 1: Rewire `LiveBreathSessionService` to depend on `ModuleStateChannel`**
  Files: `lib/BreathModule/Core/LiveBreathSessionService.dart`, `lib/Core/App.dart`
  Replace the `LiveBreathSessionNotifier` dependency with `ModuleStateChannel`. The service must remain stateless (no `StreamSubscription`, no `dispose()`):
  - Constructor takes `ModuleStateChannel channel` instead of `LiveBreathSessionNotifier notifier`.
  - `startSession(sessionId)` calls `_channel.start(type: ActivityType.breath, refId: sessionId)`.
  - `endSession()` calls `_channel.end()`.
  - `stopSession()` calls `_channel.stop()`.
  - `pauseSession()` calls `_channel.pause()`.
  - `resumeSession()` calls `_channel.unpause()`.
  - `sessionStateStream` maps `_channel.state` to `LiveBreathSessionDto` — use `ModuleStateStatus.active` instead of `LiveBreathSessionStatus.active`.
  - Remove the import of `LiveBreathSessionNotifier`, `LiveBreathSessionState`, add import of `ModuleStateChannel`, `ModuleState`, `ModuleStateStatus`, `ActivityType`.
  - In `App.dart`: update `LiveBreathSessionService(notifier: liveSessionNotifier)` to `LiveBreathSessionService(channel: moduleStateChannel)` so the call site matches the new constructor signature. This keeps Commit 1 compilable.

- [x] **Task 2: Rewire `HomeService` to depend on `ModuleStateChannel`**
  Files: `lib/HomeModule/HomeService.dart`, `lib/HomeModule/HomeModule.dart`
  Replace the `LiveBreathSessionNotifier` dependency with `ModuleStateChannel`:
  - In `HomeService`: change constructor parameter from `LiveBreathSessionNotifier liveSessionNotifier` to `ModuleStateChannel moduleStateChannel`. In `observeChanges()`, replace `liveSessionNotifier.events.where((e) => e is LiveBreathSessionEnded)` with `moduleStateChannel.events.where((e) => e is ModuleSessionEnded)`. Import `ModuleStateChannel` and `ModuleStateEvent` (for `ModuleSessionEnded`), remove imports of `LiveBreathSessionEvent` and `LiveBreathSessionNotifier`.
  - In `HomeModule.buildHomeScreen`: pass `App.shared.moduleStateChannel` instead of `App.shared.liveSessionNotifier` as the new parameter name.

### Phase 2: Remove `LiveBreathSessionNotifier` and its scaffolding

- [x] **Task 3: Remove `LiveBreathSessionNotifier` from `App.dart` wiring**
  Files: `lib/Core/App.dart`
  - Delete the `liveSessionNotifier` field from the `App` class and its named constructor parameter.
  - Delete the `final liveSessionNotifier = LiveBreathSessionNotifier(...)` initialization line (~line 170).
  - Delete the `liveSessionNotifier: liveSessionNotifier` argument from the `App._()` constructor call.
  - Remove the import of `LiveBreathSessionNotifier`.

- [x] **Task 4: Delete `LiveBreathSessionNotifier` and its type files**
  Files: `lib/BreathModule/Core/LiveBreathSessionNotifier.dart`, `lib/BreathModule/Core/LiveBreathSessionState.dart`, `lib/BreathModule/Core/LiveBreathSessionEvent.dart`, `test/BreathModule/live_session_notifier_test.dart`
  Delete all four files — the notifier class, its state enum+class, its sealed event hierarchy, and the unit-test file.

- [x] **Task 5: Remove the backward-compat bridge from `LiveSessionGrpcService` and `ModuleStateChannel`**
  Files: `lib/Core/Grpc/LiveSessionGrpcService.dart`, `lib/Core/Grpc/ModuleStateChannel.dart`, `lib/Core/Grpc/ILiveSessionService.dart`
  The `rawSessionEvents` stream and the `ILiveSessionService.sessionStateEvents` getter only existed to feed `LiveBreathSessionNotifier`. Remove them:
  - In `ModuleStateChannel`: delete the `_rawSessionEvents` `StreamController`, the `rawSessionEvents` getter, the `_rawSessionEvents.add(event)` call inside `_openLiveStream`, and the `_rawSessionEvents.close()` call in `dispose()`.
  - In `ILiveSessionService`: delete the `sessionStateEvents` getter from the interface. Also delete the `sendActivityStart/End/Stop/Pause/Resume` methods and the interface itself — `LiveSessionGrpcService` no longer needs to implement an interface now that `ModuleStateChannel` is the direct command surface. Delete the entire file `lib/Core/Grpc/ILiveSessionService.dart`.
  - In `LiveSessionGrpcService`: remove `implements ILiveSessionService`, delete the `sessionStateEvents` getter override and the `sendActivity*` delegation methods (lines 127–158), and delete the `_mapSessionStatus` helper. Remove the import of `ILiveSessionService` and `ActivityType` (no longer used here). Remove the import of `ModuleStateChannel` only if it was solely used for `rawSessionEvents` delegation (check — it's still used for `isConnected`, so keep the import).

- [x] **Task 6: Clean up stale doc references**
  Files: `docs/socket/live-session-tracking.md`, `docs/breath/session/view-model.md`
  Grep these files for any mention of `LiveBreathSessionNotifier`, `LiveBreathSessionService`, `LiveBreathSessionEvent`, `LiveBreathSessionState`, `ILiveSessionService`. Replace or remove references so they point to `ModuleStateChannel` and `ModuleStateEvent` instead. Keep changes minimal — only fix names, do not rewrite prose.

## Commit Plan
- **Commit 1** (after tasks 1-2): "Rewire LiveBreathSessionService and HomeService to use ModuleStateChannel"
- **Commit 2** (after tasks 3-5): "Delete LiveBreathSessionNotifier and its backward-compat bridge"
- **Commit 3** (after task 6): "Update docs to reflect LiveBreathSessionNotifier removal"
