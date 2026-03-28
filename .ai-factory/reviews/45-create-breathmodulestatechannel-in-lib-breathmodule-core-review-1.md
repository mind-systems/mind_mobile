# Review: Create BreathModuleStateChannel in lib/BreathModule/Core/

**Files Reviewed:** 6 changed files (1 new, 2 modified, 2 deleted, 1 barrel edit), plus source models and infrastructure classes

## Context Gates

- **Plan adherence** — All 4 tasks fully implemented. `BreathModuleStateChannel` created, `BreathModule.buildSession()` rewired, `LiveBreathSessionService` removed from `App.dart`, deleted files removed from barrel exports.
- **`LateInitializationError` fix** — The review feedback from the plan review was addressed correctly: `onRestart: () => stateChannel.reset()` and `onDispose: () => stateChannel.dispose()` use closure wrappers, not method tear-offs.

## Verification

### API compatibility

- `ModuleStateChannel.start(type:, refId:)`, `.pause()`, `.unpause()`, `.end()`, `.stop()` — all match the infrastructure API signatures exactly.
- `ModuleStateChannel.state` returns `Stream<ModuleState>` — `_channelSub` subscription type `StreamSubscription<ModuleState>` is correct.
- `ModuleState.liveSessionId` is `String?` — matches the null check in the channel listener.
- `BreathTelemetryService.sendSample(String, String, int)` — call sites pass `(liveId, state.phase.name, state.currentIntervalMs)`, all types match.
- `BreathSessionState` fields used (`loadState`, `status`, `phase`, `exerciseIndex`, `currentIntervalMs`) — all exist on the model class.
- `BreathSessionScreen({onRestart: VoidCallback?, onDispose: VoidCallback?})` — closures `() => stateChannel.reset()` and `() => stateChannel.dispose()` both return `void`, matching `VoidCallback`.

### Dangling references

Grep for `LiveBreathSessionService`, `ILiveBreathSessionService`, `LiveBreathSessionDto`, `LiveBreathSessionCoordinator` in `lib/` and `packages/` — **zero matches**. Clean.

### Lifecycle correctness

- **Constructor subscribes immediately** — `_stateSub` and `_channelSub` are assigned in the constructor body. Both are `late final`, and since the constructor is the only assignment site, they are guaranteed initialized before any method call.
- **`reset()` preserves subscriptions** — only clears tracking state, keeping `_stateSub` and `_channelSub` alive across session restarts. This is correct: the `BreathViewModel.stream` is reused.
- **`dispose()` calls `_channel.stop()` only if session was started but not ended** — correctly guards against spurious stop commands.
- **`_pendingTelemetry` cleared in `dispose()`** — Wait, it's NOT cleared in `dispose()`. The old `LiveBreathSessionCoordinator.dispose()` cleared `_pendingTelemetry = null`. The new code omits this. However, since `dispose()` cancels both subscriptions immediately after, no callback can ever read `_pendingTelemetry` again — so the omission is functionally harmless (the object will be GC'd). Not a bug.

### Shared `ModuleStateChannel` concern

`App.shared.moduleStateChannel` is a singleton shared across the app. `BreathModuleStateChannel` subscribes to `channel.state` in its constructor. If the user navigates to a breath session, disposes it, and navigates again, each `BreathModuleStateChannel` instance subscribes and the previous one's `_channelSub` is cancelled in `dispose()`. Since `ModuleStateChannel.state` is a `BehaviorSubject` (broadcasts to multiple listeners), this is safe — no subscription leak, no interference.

### `ModuleState` import

`BreathModuleStateChannel.dart` imports `ModuleState.dart` (line 5). This import is used for the `StreamSubscription<ModuleState>` type annotation on `_channelSub` — correct and necessary.

## Critical Issues

None.

## Suggestions

None.

## Positive Notes

- Clean absorption of two classes into one with no behavioral regression.
- Closure wrappers correctly applied per plan review feedback.
- No dangling references to deleted files.
- All API signatures verified against source infrastructure and model classes.

REVIEW_PASS
