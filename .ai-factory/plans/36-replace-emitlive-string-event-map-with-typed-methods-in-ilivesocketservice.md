# Plan: Replace `emitLive(String, Map?)` with typed methods in `ILiveSocketService`

## Context

The current `ILiveSocketService.emitLive(String event, [Map<String, dynamic>? data])` is a Socket.io leftover that dispatches commands via string matching. Replace it with five explicit typed methods so the interface is self-documenting, the string-switch in `LiveSessionGrpcService` disappears, and callers get compile-time safety instead of runtime string matching.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Create domain ActivityType enum and update the interface

- [x] **Task 1: Add a domain-level `ActivityType` enum**
  Files: `lib/Core/Grpc/ActivityType.dart`
  Create a new file with a plain Dart enum: `enum ActivityType { breath }`. This is the domain-level type used by the interface and callers — it is not the proto-generated `ActivityType`. Keep it minimal (only `breath` for now, matching the single non-unspecified proto variant).

- [x] **Task 2: Replace `emitLive` with five typed methods on `ILiveSocketService`**
  Files: `lib/Core/Grpc/ILiveSocketService.dart`
  Remove `void emitLive(String event, [Map<String, dynamic>? data])` and add:
  ```dart
  void sendActivityStart({required ActivityType type, String? refId});
  void sendActivityEnd();
  void sendActivityStop();
  void sendActivityPause();
  void sendActivityResume();
  ```
  Import the new `ActivityType` enum. Keep `sessionStateEvents` unchanged.

### Phase 2: Update the concrete implementation

- [x] **Task 3: Implement typed methods in `LiveSessionGrpcService`** (depends on Task 2)
  Files: `lib/Core/Grpc/LiveSessionGrpcService.dart`
  - Remove the `emitLive` override and its string-switch block entirely.
  - Remove the old `_mapActivityType(String?)` helper.
  - **Import collision:** The proto-generated code already exports an `ActivityType` enum. To avoid a naming collision with the new domain `ActivityType`, prefix the proto import: `import 'generated/live.pbgrpc.dart' as proto;` (and update all existing references to proto types in this file accordingly, e.g. `proto.LiveRequest`, `proto.ActivityStartCmd`, `proto.ActivityType`).
  - Add five `@override` methods that each build the corresponding `proto.LiveRequest` directly (e.g. `sendActivityStart` creates `proto.LiveRequest(activityStart: proto.ActivityStartCmd(activityType: _mapActivityType(type), refId: refId ?? ''))`) and send it via `_liveSink`.
  - Add a private `proto.ActivityType _mapActivityType(ActivityType type)` that maps the **domain** enum to the **proto** enum (`ActivityType.breath` → `proto.ActivityType.ACTIVITY_TYPE_BREATH`, fallback `proto.ActivityType.ACTIVITY_TYPE_UNSPECIFIED`). Note: the return type is the proto enum, not the domain enum.
  - Extract the shared "guard not connected + add to sink" logic into a small private helper (e.g. `void _sendLiveRequest(proto.LiveRequest request)`) to avoid duplicating the null-check and log in each method.

### Phase 3: Update callers

- [x] **Task 4: Update `LiveBreathSessionNotifier` to call typed methods** (depends on Task 2)
  Files: `lib/BreathModule/Core/LiveBreathSessionNotifier.dart`
  - Import the domain `ActivityType` enum.
  - Change `start(String activityType, String activityRefType, String activityRefId)` signature to `start({required ActivityType type, required String refId})`. The `activityRefType` parameter is unused by the gRPC service (the proto `ActivityStartCmd` only has `activityType` + `refId`), so drop it.
  - Replace `_liveSocketService.emitLive('activity:start', {...})` with `_liveSocketService.sendActivityStart(type: type, refId: refId)`.
  - Replace `_liveSocketService.emitLive('activity:pause')` with `_liveSocketService.sendActivityPause()`.
  - Replace `_liveSocketService.emitLive('activity:resume')` with `_liveSocketService.sendActivityResume()`.
  - Replace `_liveSocketService.emitLive('activity:end')` with `_liveSocketService.sendActivityEnd()`.
  - Replace `_liveSocketService.emitLive('activity:stop')` with `_liveSocketService.sendActivityStop()`.

- [x] **Task 5: Update `LiveBreathSessionService` call site** (depends on Task 4)
  Files: `lib/BreathModule/Core/LiveBreathSessionService.dart`
  Change `_notifier.start('breath_session', 'breath_session', sessionId)` to `_notifier.start(type: ActivityType.breath, refId: sessionId)`. Import the domain `ActivityType` enum.

- [x] **Task 6: Update the test fake and test assertions** (depends on Task 2)
  Files: `test/BreathModule/live_session_notifier_test.dart`
  - Replace `FakeLiveSocketService.emitLive` with the five typed method overrides.
  - **Capture typed arguments** so assertions can verify the correct values were passed. Use per-method lists with argument records, e.g.:
    ```dart
    final List<({ActivityType type, String? refId})> activityStartCalls = [];
    final List<void Function()> activityEndCalls = []; // or just int counters for no-arg methods
    ```
    Each override appends to its list (e.g. `sendActivityStart` adds `(type: type, refId: refId)` to `activityStartCalls`). This preserves the existing argument-level assertion coverage that previously checked payload maps like `socket.emitted.first.$2`.
  - Update all `notifier.start(...)` calls in tests to use the new named-parameter signature: `notifier.start(type: ActivityType.breath, refId: 'session-abc')`.
  - Update all assertions to check the new typed tracking lists instead of the old `socket.emitted` string/map tuples. For example, replace `expect(socket.emitted.first.$1, 'activity:start')` + payload checks with `expect(socket.activityStartCalls.first.type, ActivityType.breath)` and `expect(socket.activityStartCalls.first.refId, 'session-abc')`.

## Commit Plan
- **Commit 1** (after tasks 1-3): "Replace emitLive string dispatch with typed methods on ILiveSocketService and LiveSessionGrpcService"
- **Commit 2** (after tasks 4-6): "Update LiveBreathSessionNotifier, service, and tests to use typed socket methods"
