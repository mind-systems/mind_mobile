# Plan: Re-point Android FGS keep-alive to the local signal (offline fix)

## Context
Drive the Android foreground service (FGS) from the breath activity's **local** `BreathSessionState.isLive` signal instead of the **server** `ModuleSessionStarted` event, so a locked offline breath exercise keeps running past ~1 min in the background. The server-event path is retained for meditation (parity deferred); biometrics stay server-gated.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Bridge local `isLive` up to the app layer

- [x] **Task 1: Add `onIsLiveChanged` callback + edge detection to `BreathViewModel`**
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`
  Extend the bridge already used for `onDispose`/`onReset` so the breath activity can report local lifecycle edges up to the app layer (the package stays unaware of the FGS — it only fires a `bool` callback).
  - Add a nullable field `void Function(bool isLive)? _onIsLiveChanged;` next to `_onModuleDispose`/`_onModuleReset`.
  - Add an **optional** named param to `attachModuleChannel`: `void Function(bool isLive)? onIsLiveChanged` (keep it optional / default `null` so the existing test harness call at `test/BreathModule/Support/BreathActivityHarness.dart:113` and any other caller still compile without change). Assign it inside the method.
  - Track the last emitted value: `bool _lastIsLive = false;` (matches the initial `BreathLifecycle.notStarted`, whose `isLive` is `false`).
  - Detect edges at the single publication funnel — the `set state` setter (`:107-115`). After the existing body, compute `final next = value.isLive;` and, when `_onIsLiveChanged != null && next != _lastIsLive`, update `_lastIsLive = next;` and invoke `_onIsLiveChanged!(next)`. This makes `notStarted/completed → false` and `running/paused → true`; a manual pause keeps `isLive == true`, so no spurious `false` edge fires (matches the keep-alive-through-pause contract in `BreathSessionState`).
  - Guarantee no orphan FGS on teardown: inside the existing `ref.onDispose(...)` block (`:78-88`), before/alongside `_onModuleDispose?.call()`, add `if (_lastIsLive) { _onIsLiveChanged?.call(false); }`. This covers disposal while still live (e.g. navigating away from a running session), where no `true → false` state edge would otherwise be emitted. (On local `complete()`, `lifecycle → completed` already drives a `true → false` edge through the setter, so dispose then sees `_lastIsLive == false` and does not double-fire.)

- [x] **Task 2: Add a local-signal entry point to `KeepAliveCoordinator`** (depends on Task 1)
  Files: `lib/Core/Background/KeepAliveCoordinator.dart`
  Add a public method `Future<void> onLocalLifecycle(bool isLive)` that starts the FGS on `true` and stops it on `false`:
  ```
  Future<void> onLocalLifecycle(bool isLive) async {
    if (!_isAndroid) return;
    if (isLive) {
      await _foregroundKeepAlive.start();
    } else {
      await _foregroundKeepAlive.stop();
    }
  }
  ```
  Persist the platform check so the method can guard on it: add a `final bool _isAndroid;` field and assign it in the constructor's **initializer list** (a `final` instance field cannot be assigned in the constructor body), then reuse it in the existing guard:
  ```
  KeepAliveCoordinator({
    required ForegroundKeepAlive foregroundKeepAlive,
    required Stream<ModuleStateEvent> moduleStateEvents,
    bool Function() isAndroid = _platformIsAndroid,
  })  : _foregroundKeepAlive = foregroundKeepAlive,
        _isAndroid = isAndroid() {          // initializer list, not body
    if (!_isAndroid) return;
    _subscription = moduleStateEvents.listen(_onEvent);
  }
  ```
  `ForegroundKeepAlive.start()/stop()` are already idempotent and internally no-op off Android, so redundant calls are safe.
  **Keep the existing `moduleStateEvents` subscription and `_onEvent` handler unchanged** — it still drives the FGS for meditation sessions (offline parity for meditation is explicitly out of scope). For breath when online both paths fire; because start/stop are idempotent this is harmless. Offline (the bug case) emits no server events, so the local path is the sole driver — that is the fix.

- [x] **Task 3: Wire the breath local signal to the coordinator in `buildSession`** (depends on Task 2)
  Files: `lib/BreathModule/BreathModule.dart`
  In `BreathModule.buildSession` (`:46-56`), extend the existing `vm.attachModuleChannel(...)` call to also pass the new callback, matching the established method-reference wiring used for `onDispose`/`onReset`:
  ```
  vm.attachModuleChannel(
    onDispose: channel.dispose,
    onReset: channel.reset,
    onIsLiveChanged: App.shared.keepAliveCoordinator.onLocalLifecycle,
  );
  ```
  No `App.dart` change is required — `keepAliveCoordinator` is already a field on `App.shared` (`lib/Core/App.dart:112`, constructed at `:233`).

## Constraints (do not violate)
- Do **NOT** move biometric streaming to the local signal — `BiometricStreamClient` stays server-gated (`moduleStateChannel.events`), untouched.
- Do **NOT** remove or rewire the server-event subscription in `KeepAliveCoordinator` — meditation still depends on it (parity deferred).
- Do **NOT** make `onIsLiveChanged` a required param — adding a required arg breaks `BreathActivityHarness` and existing tests.
- Do **NOT** re-add any running-session auto-`pause()`; a running session must survive lock and keep the FGS up through a manual pause (`isLive` stays `true`).
- Meditation and iOS background behavior remain unchanged (the local method no-ops off Android).
- Single commit: "Re-point Android breath FGS keep-alive to local isLive signal".
