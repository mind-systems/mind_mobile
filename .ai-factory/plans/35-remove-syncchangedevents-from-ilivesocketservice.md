# Plan: Remove `syncChangedEvents` from `ILiveSocketService`

## Context

The `syncChangedEvents` getter on `ILiveSocketService` is a dead stub — `LiveSessionGrpcService` returns `Stream.empty()` and no consumer subscribes to it. Sync is fully handled by `SyncGrpcListener`. This milestone removes the getter from the abstract interface, the stub implementation, and the fake in tests.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Remove `syncChangedEvents`

- [x] **Task 1: Remove `syncChangedEvents` from the abstract interface**
  Files: `lib/Core/Grpc/ILiveSocketService.dart`
  Delete the line `Stream<Map<String, dynamic>> get syncChangedEvents;` from the `ILiveSocketService` abstract interface class. The interface should retain only `sessionStateEvents` and `emitLive`.

- [x] **Task 2: Delete the stub implementation in `LiveSessionGrpcService`**
  Files: `lib/Core/Grpc/LiveSessionGrpcService.dart`
  Remove the `syncChangedEvents` override (lines 39-43): the doc comment, the `@override` annotation, and the getter returning `Stream<Map<String, dynamic>>.empty()`.

- [x] **Task 3: Remove `syncChangedEvents` from `FakeLiveSocketService` in the test file**
  Files: `test/BreathModule/live_session_notifier_test.dart`
  Delete the `@override` and the `syncChangedEvents` getter (lines 23-24) from the `FakeLiveSocketService` fake class.
