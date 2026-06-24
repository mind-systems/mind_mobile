# KeepAliveCoordinator — Test Plan

**Date:** 2026-06-24  
**Source:** roadmap-test-coverage agent

## Source Overview

**File:** `lib/Core/Background/KeepAliveCoordinator.dart`

The `KeepAliveCoordinator` subscribes to the app-wide `ModuleStateEvent` stream and drives the foreground service lifecycle:

- **Instantiation:** Accepts `ForegroundKeepAlive` and `moduleStateEvents` stream. If `Platform.isAndroid` is true, subscribes to the event stream; otherwise, returns early (no-op on iOS).
- **Event handling:** Routes 7 event types:
  - `ModuleSessionStarted` → calls `_foregroundKeepAlive.start()`
  - `ModuleSessionEnded` → calls `_foregroundKeepAlive.stop()`
  - `ModuleSessionAbandoned` → calls `_foregroundKeepAlive.stop()`
  - `ModuleSessionResumed`, `ModuleSessionPaused`, `ModuleSessionUnpaused` → no-op (switch case breaks)
- **Lifecycle:** Holds subscription via `_subscription` field (GC prevention); no explicit dispose method.

**Dependency:** `ForegroundKeepAlive`

- `start()` is a `Future<void>` — safe to call when already running (idempotent).
- `stop()` is a `Future<void>` — safe to call when not running (idempotent).
- Both are no-ops on iOS (check `Platform.isAndroid` internally).

---

## Instantiation

The constructor has a **Platform guard** (`if (!Platform.isAndroid) return;`). This means:

- On Android: subscription is created, listening to `moduleStateEvents`.
- On iOS: no subscription is created; the object becomes inert.

**Testing challenge:** Unit tests run in Dart VM, so `Platform.isAndroid` is typically false. To test the Android path, mock `Platform.isAndroid` using a technique like `overridePlatformAsync()` from `package:flutter_test`, or use `debugDefaultTargetPlatformOverride` from `dart:io`.

---

## Existing Coverage

None. No test file exists for `KeepAliveCoordinator`.

---

## Test Cases

### Group 1: ModuleSessionStarted → start()

**Setup:**
- Mock `ForegroundKeepAlive` with a fake that tracks calls to `start()` / `stop()`.
- Create a `StreamController<ModuleStateEvent>` as `moduleStateEvents`.
- Mock `Platform.isAndroid` to true.
- Create `KeepAliveCoordinator` with the mock and stream.

**TC 1.1:** "should call foregroundKeepAlive.start() when ModuleSessionStarted is emitted"
- Setup: Create a `ModuleSessionStarted(moduleSessionId: 'test-session-1')` event.
- Action: Emit the event via `moduleStateEvents.add(event)`.
- Assert: `foregroundKeepAlive.start()` was called exactly once.
- Assert: No other methods were called on `foregroundKeepAlive`.

**TC 1.2:** "should propagate Future completion from start() (allow await on side effect)"
- Setup: Mock `ForegroundKeepAlive.start()` to return a Future that completes after a delay.
- Action: Emit `ModuleSessionStarted`.
- Assert: The returned Future completes (or we can log the call without awaiting in the coordinator, but verify the call happens).
  - *Note:* `_onEvent()` is synchronous and doesn't await, so `start()` is fire-and-forget. This test may verify that start() was called, not that the Future was awaited.

**TC 1.3:** "should handle multiple consecutive ModuleSessionStarted events (idempotency at coordinator level)"
- Setup: Mock `ForegroundKeepAlive.start()` to track call count.
- Action: Emit `ModuleSessionStarted`, then emit another `ModuleSessionStarted` without a stop in between.
- Assert: `foregroundKeepAlive.start()` was called twice (coordinator doesn't de-duplicate; the underlying `ForegroundKeepAlive` is responsible for idempotency).

---

### Group 2: ModuleSessionEnded → stop()

**Setup:** Same as Group 1.

**TC 2.1:** "should call foregroundKeepAlive.stop() when ModuleSessionEnded is emitted"
- Setup: Create a `ModuleSessionEnded()` event.
- Action: Emit the event.
- Assert: `foregroundKeepAlive.stop()` was called exactly once.
- Assert: No call to `start()`.

**TC 2.2:** "should handle stop() Future completion"
- Setup: Mock `ForegroundKeepAlive.stop()` to return a Future that completes after a delay.
- Action: Emit `ModuleSessionEnded`.
- Assert: The stop() call happens (note: no await in coordinator, so just verify the call).

---

### Group 3: ModuleSessionAbandoned → stop()

**Setup:** Same as Group 1.

**TC 3.1:** "should call foregroundKeepAlive.stop() when ModuleSessionAbandoned is emitted"
- Setup: Create a `ModuleSessionAbandoned()` event.
- Action: Emit the event.
- Assert: `foregroundKeepAlive.stop()` was called exactly once.
- Assert: No call to `start()`.

**TC 3.2:** "ModuleSessionEnded and ModuleSessionAbandoned should have identical effect"
- Setup: Two coordinators, each with a mock `ForegroundKeepAlive`.
- Action: Emit `ModuleSessionEnded` to one, `ModuleSessionAbandoned` to the other.
- Assert: Both `stop()` calls were made on their respective mocks.

---

### Group 4: No-op Events (ModuleSessionResumed, Paused, Unpaused)

**Setup:** Same as Group 1.

**TC 4.1:** "should not call start() or stop() when ModuleSessionResumed is emitted"
- Setup: Create a `ModuleSessionResumed(moduleSessionId: 'test-session-1')` event.
- Action: Emit the event.
- Assert: Neither `start()` nor `stop()` was called.

**TC 4.2:** "should not call start() or stop() when ModuleSessionPaused is emitted"
- Setup: Create a `ModuleSessionPaused()` event.
- Action: Emit the event.
- Assert: Neither `start()` nor `stop()` was called.

**TC 4.3:** "should not call start() or stop() when ModuleSessionUnpaused is emitted"
- Setup: Create a `ModuleSessionUnpaused()` event.
- Action: Emit the event.
- Assert: Neither `start()` nor `stop()` was called.

---

### Group 5: Event Sequencing

**Setup:** Same as Group 1, with a mock that tracks call order.

**TC 5.1:** "should start → stop → start in sequence (session restart)"
- Setup: Mock tracks call history in order.
- Action:
  1. Emit `ModuleSessionStarted`.
  2. Emit `ModuleSessionEnded`.
  3. Emit `ModuleSessionStarted`.
- Assert: Call sequence is `[start, stop, start]`.

**TC 5.2:** "should handle Paused/Unpaused around Started/Ended without extra side effects"
- Setup: Mock tracks calls.
- Action:
  1. Emit `ModuleSessionStarted`.
  2. Emit `ModuleSessionPaused` (no-op).
  3. Emit `ModuleSessionUnpaused` (no-op).
  4. Emit `ModuleSessionEnded`.
- Assert: Only `start()` then `stop()` were called; no extra calls from pause/unpause.

---

### Group 6: Platform Guard (Android vs. iOS)

**TC 6.1:** "should subscribe to moduleStateEvents when Platform.isAndroid is true"
- Setup: Override `Platform.isAndroid` to true.
- Action: Create `KeepAliveCoordinator` with a mock and stream.
- Assert: `_subscription` is not null after construction.
- Assert: Emitting an event triggers `_onEvent()`.

**TC 6.2:** "should NOT subscribe when Platform.isAndroid is false (iOS)"
- Setup: Override `Platform.isAndroid` to false.
- Action: Create `KeepAliveCoordinator` with a mock and stream.
- Assert: `_subscription` is null after construction.
- Action: Emit an event.
- Assert: `foregroundKeepAlive.start()` and `stop()` are never called (no-op).

**TC 6.3:** "should return early from constructor on non-Android (iOS)"
- Setup: Override `Platform.isAndroid` to false.
- Action: Create `KeepAliveCoordinator`.
- Assert: Constructor completes without error.
- Assert: The coordinator is in an inert state (no subscription).

---

### Group 7: Lifecycle / Disposal

**TC 7.1:** "subscription should be retained after construction (GC prevention)"
- Setup: Create `KeepAliveCoordinator` on Android.
- Action: Store reference to coordinator.
- Assert: `_subscription` is non-null and can be inspected/verified (via reflection or by checking that events are still routed).
- *Note:* No explicit dispose method exists; the subscription lives as long as the coordinator object.

**TC 7.2:** "should handle stream closure gracefully (subscription ends naturally)"
- Setup: Create `KeepAliveCoordinator` with a controller-backed stream.
- Action: Close the controller (`moduleStateEvents.close()`).
- Assert: No exception is thrown; the coordinator remains in a consistent state.

---

## Gotchas

1. **Platform override:** `Platform.isAndroid` is read-only and cannot be directly mocked in unit tests. Use:
   - `debugDefaultTargetPlatformOverride` from `dart:io` (available in `flutter_test`).
   - Or write a wrapper class for platform detection and inject it (not done in current code, so this test will require a workaround).
   - **Practical approach:** Test the Android path with `debugDefaultTargetPlatformOverride = TargetPlatform.android` before coordinator construction, and reset after each test.

2. **Fire-and-forget futures:** The `_onEvent()` method is synchronous and does not await `start()` or `stop()`. Tests must verify that the methods are *called*, not that their Futures are awaited or complete. If the Future fails silently, the coordinator won't propagate the error.

3. **No explicit dispose:** The coordinator holds a subscription forever (via the `_subscription` field). To avoid subscription leaks in tests, ensure mock streams complete or close properly after each test.

4. **Event emission timing:** Use `await Future.delayed(Duration.zero)` or `Future.microtask()` to allow async operations (like permission requests in `ForegroundKeepAlive.start()`) to run before assertions, even though the coordinator itself doesn't await.

5. **ModuleSessionStarted carries optional moduleSessionId:** The event includes a session ID. Tests should verify this is passed through correctly if used, or confirm the coordinator doesn't depend on it (current code doesn't inspect it).

6. **Idempotency delegation:** The coordinator does not deduplicate events (e.g., two `ModuleSessionStarted` events in a row both call `start()`). This is by design; the `ForegroundKeepAlive` is responsible for idempotency. Tests should reflect this behavior.

---

## Test File Template

```dart
import 'dart:async';
import 'dart:io' show Platform, TargetPlatform;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind/Core/Background/KeepAliveCoordinator.dart';
import 'package:mind/Core/Background/ForegroundKeepAlive.dart';
import 'package:mind/Core/Grpc/ModuleStateEvent.dart';

// --- Fake ForegroundKeepAlive ---
class _FakeForegroundKeepAlive implements ForegroundKeepAlive {
  final List<String> callLog = [];

  @override
  Future<void> start() async {
    callLog.add('start');
  }

  @override
  Future<void> stop() async {
    callLog.add('stop');
  }
}

void main() {
  group('KeepAliveCoordinator', () {
    // Group 1: ModuleSessionStarted → start()
    // Group 2: ModuleSessionEnded → stop()
    // Group 3: ModuleSessionAbandoned → stop()
    // Group 4: No-op events
    // Group 5: Event sequencing
    // Group 6: Platform guard
    // Group 7: Lifecycle
  });
}
```


## Refactor Required

**What to refactor:** In `KeepAliveCoordinator`, change the stream-listener body to `await` the `ForegroundKeepAlive.start()` and `.stop()` calls:

```dart
// before
_moduleStateEvents.listen((event) {
  if (event is ModuleSessionStarted) _foregroundKeepAlive.start();
  if (event is ModuleSessionEnded || event is ModuleSessionAbandoned) _foregroundKeepAlive.stop();
});

// after
_moduleStateEvents.listen((event) async {
  if (event is ModuleSessionStarted) await _foregroundKeepAlive.start();
  if (event is ModuleSessionEnded || event is ModuleSessionAbandoned) await _foregroundKeepAlive.stop();
});
```

**Post-refactor API:** Unchanged externally — only the listener body changes. `ForegroundKeepAlive` is already constructor-injected so tests can pass a fake.

**What the test implementer gets:** `await`-able event delivery means tests can `await eventController.add(ModuleSessionStarted())` and then synchronously assert `fakeFgs.started == true` without arbitrary delays.

**Note on Platform.isAndroid:** The static check is in the constructor (`if (!Platform.isAndroid) return;`). Tests can instantiate and call the coordinator on non-Android; the subscription is simply not set up. This is acceptable — test the logic via a conditional-compile override or accept that the tests only exercise the Platform.isAndroid=true path by stubbing the check.
