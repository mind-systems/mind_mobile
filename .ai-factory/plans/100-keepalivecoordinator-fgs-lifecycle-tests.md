# Test Plan: KeepAliveCoordinator FGS lifecycle tests

## Context
`lib/Core/Background/KeepAliveCoordinator.dart` subscribes to the app-wide `ModuleStateEvent` stream and drives the Android foreground service (`ForegroundKeepAlive`) across module-session lifecycle transitions. It has zero test coverage. This plan exercises the event-routing contract (start on session start, stop on end/abandon, re-arm, dispose, no-op events) plus the `Platform.isAndroid` guard.

## Settings
- Testing: yes
- Logging: minimal
- Docs: no

## Test Command
`/usr/local/bin/flutter test test/Core/Background/keepalive_coordinator_test.dart`

## Target Spec File
`test/Core/Background/keepalive_coordinator_test.dart`

---

## Preconditions (read before writing tests)

The Test Infra prerequisite "Make `KeepAliveCoordinator` testable: await FGS calls" (ROADMAP.md, Test Infra) is **already done** — `_onEvent` now `await`s `start()`/`stop()` (KeepAliveCoordinator.dart:29/31/33), so a single microtask drain after emitting an event is enough for deterministic assertions.

Two source-grounded gaps block the milestone's detailed cases. Both require a small, conventional SUT change before the corresponding tests can be written. **Flag these to the implementer; do not silently skip the cases.**

### Gap A — the Android branch is unreachable on a non-Android test host
The constructor guard is `if (!Platform.isAndroid) return;` (KeepAliveCoordinator.dart:18), reading `dart:io`'s `Platform`. `flutter test` runs on the host OS (macOS/Linux), so `Platform.isAndroid` is **always false** and the subscription is never created.

**`debugDefaultTargetPlatformOverride` does NOT help here** — it overrides `defaultTargetPlatform` from `flutter/foundation`, which is unrelated to `dart:io Platform.isAndroid`. The suggestion in spec note `180` to use it is incorrect for this code path. `dart:io Platform.operatingSystem` cannot be overridden in unit tests.

To exercise the event-routing branch (Tasks 2–5), add an injectable platform seam that keeps the production call site (App.dart:230) unchanged:

```dart
KeepAliveCoordinator({
  required ForegroundKeepAlive foregroundKeepAlive,
  required Stream<ModuleStateEvent> moduleStateEvents,
  bool Function() isAndroid = _platformIsAndroid,   // <-- new, defaulted
}) : _foregroundKeepAlive = foregroundKeepAlive {
  if (!isAndroid()) return;
  _subscription = moduleStateEvents.listen(_onEvent);
}

static bool _platformIsAndroid() => Platform.isAndroid;
```

> **The helper MUST be `static`.** Default parameter values must be compile-time constants. A static-method tear-off is constant; an *instance*-method tear-off is **not** and fails analysis with `non_constant_default_value` ("The default value of an optional parameter must be constant"), which would block every Android-path task (2–5). Equivalently, move it to a top-level function. Do not copy an instance-method version.

Tests then inject `isAndroid: () => true` (Android path) or `isAndroid: () => false` (guard path). This mirrors the codebase's established test-seam convention (clock/timer/config injection) and the sibling `MeditationKeepAliveCoordinator`, which has no platform guard and is trivially testable.

### Gap B — there is no `dispose()` method
The milestone requires a "dispose cancels subscription" case, but `KeepAliveCoordinator` has no `dispose()` (the `_subscription` field is held only for GC prevention). The sibling `MeditationKeepAliveCoordinator` (MeditationKeepAliveCoordinator.dart:33) already exposes `dispose()` that cancels its subscription. Add the parallel method:

```dart
void dispose() => _subscription?.cancel();
```

Two follow-on details when applying Gap B:
- **Drop the now-stale ignore comment.** `_subscription` currently carries `// ignore: unused_field — held … (GC prevention)` (KeepAliveCoordinator.dart:23). Once `dispose()` reads it via `_subscription?.cancel()`, the field is genuinely used; remove that ignore (it is inaccurate and may trip `unnecessary_ignore` depending on lint config).
- **`dispose()` exists for the test seam only.** `KeepAliveCoordinator` is created in `App.initialize()` and lives for the app's lifetime; nothing calls `dispose()` in production, and this is intentional — do not wire a call into `App.dart`. State this in the implementation so a future verifier does not flag it as a dangling/unused API.

Task 5 depends on this. Without it, only the "stream-close ends subscription naturally" sub-case is achievable.

> If the implementer cannot make SUT changes, the only grounded coverage is Task 1 (the non-Android guard path). Tasks 2–5 must not be faked against private internals — surface the blocker instead.

---

## Test Infrastructure

Hand-written fake (keep it in the test file; do not use a mocking library). `ForegroundKeepAlive` is a concrete class whose real `start()`/`stop()` touch `FlutterForegroundTask` + `permission_handler` plugins (unavailable in unit tests), so the fake **must** override both to record calls only:

```dart
class _FakeForegroundKeepAlive extends ForegroundKeepAlive {
  _FakeForegroundKeepAlive() : super(currentLanguageCode: () => 'en');
  final List<String> calls = []; // 'start' / 'stop' in invocation order

  @override
  Future<void> start() async => calls.add('start');

  @override
  Future<void> stop() async => calls.add('stop');
}
```

- Inject events via a `StreamController<ModuleStateEvent>.broadcast()`; emit with `.add(event)`.
- After each `.add(...)`, `await Future.microtask(() {})` (or `await Future.delayed(Duration.zero)`) so the async `_onEvent` handler completes before asserting on `calls`.
- Close the controller in `tearDown` to avoid leaks.
- `ModuleStateEvent` subtypes: `ModuleSessionStarted({moduleSessionId})`, `ModuleSessionEnded()`, `ModuleSessionAbandoned()`, `ModuleSessionResumed({moduleSessionId})`, `ModuleSessionPaused()`, `ModuleSessionUnpaused()`.

**No Flutter test binding is required.** Because the fake overrides `start()`/`stop()`, no plugin call and no `lookupAppLocalizations` is ever reached — the suite is pure-Dart. Do **not** add `TestWidgetsFlutterBinding.ensureInitialized()`.

---

## Tasks

### Phase 1: Platform guard (grounded in current code; no SUT change required)

- [x] **Task 1: KeepAliveCoordinator — non-Android guard**
  Files: `test/Core/Background/keepalive_coordinator_test.dart`
  Construct with `isAndroid: () => false` (or rely on the host default once the seam exists).
  Test cases:
  - `should construct without error when not on Android`
  - `should never call start() or stop() when events are emitted on a non-Android host` (emit `ModuleSessionStarted`, `ModuleSessionEnded`, `ModuleSessionAbandoned`; assert `calls` is empty — the constructor short-circuited and no subscription was created)

### Phase 2: Session start/stop routing (requires Gap A seam)

- [x] **Task 2: KeepAliveCoordinator — session lifecycle → FGS start/stop**
  Files: `test/Core/Background/keepalive_coordinator_test.dart`
  Construct with `isAndroid: () => true`.
  Test cases:
  - `should call start() exactly once when ModuleSessionStarted is emitted` (assert `calls == ['start']`)
  - `should call stop() exactly once when ModuleSessionEnded is emitted` (assert `calls == ['stop']`, no `start`)
  - `should call stop() exactly once when ModuleSessionAbandoned is emitted` (assert `calls == ['stop']`, no `start`)
  - `should not call stop() when only ModuleSessionStarted is emitted` (no cross-calls)

### Phase 3: Re-arm and sequencing (requires Gap A seam)

- [x] **Task 3: KeepAliveCoordinator — re-arm and ordering**
  Files: `test/Core/Background/keepalive_coordinator_test.dart`
  Construct with `isAndroid: () => true`; assert on ordered `calls`.
  Test cases:
  - `should call start() again on a second ModuleSessionStarted after ModuleSessionEnded` (sequence Started→Ended→Started yields `calls == ['start', 'stop', 'start']` — re-arm)
  - `should call start() twice for two consecutive ModuleSessionStarted without dedup` (coordinator delegates idempotency to ForegroundKeepAlive; `calls == ['start', 'start']`)
  - `should record only start then stop when Paused/Unpaused are interleaved` (Started→Paused→Unpaused→Ended yields `calls == ['start', 'stop']`)

### Phase 4: No-op events (requires Gap A seam)

- [x] **Task 4: KeepAliveCoordinator — non-lifecycle events are no-ops**
  Files: `test/Core/Background/keepalive_coordinator_test.dart`
  Construct with `isAndroid: () => true`.
  Test cases:
  - `should not call start() or stop() when ModuleSessionResumed is emitted`
  - `should not call start() or stop() when ModuleSessionPaused is emitted`
  - `should not call start() or stop() when ModuleSessionUnpaused is emitted`

### Phase 5: Disposal (requires Gap A seam + Gap B dispose())

- [x] **Task 5: KeepAliveCoordinator — dispose stops routing**
  Files: `test/Core/Background/keepalive_coordinator_test.dart`
  Construct with `isAndroid: () => true`.
  Test cases:
  - `should not route events after dispose()` (call `dispose()`, then emit `ModuleSessionStarted`; assert `calls` is empty)
  - `should cancel the subscription on dispose() without throwing`
  - `should not throw when the events stream is closed` (close the controller; assert no exception — subscription ends naturally)
