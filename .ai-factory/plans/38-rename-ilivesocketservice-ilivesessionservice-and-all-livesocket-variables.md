# Plan: Rename `ILiveSocketService` to `ILiveSessionService` and all `liveSocket*` variables

## Context
The `ILiveSocketService` name and all `liveSocket*` identifiers are leftovers from the old Socket.io architecture. Now that the implementation is fully gRPC-based (`LiveSessionGrpcService`), rename the interface and every reference to use the `liveSession` naming convention so the codebase no longer implies a socket transport.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Rename the interface file and class

- [x] **Task 1: Rename file and class `ILiveSocketService` to `ILiveSessionService`**
  Files: `lib/Core/Grpc/ILiveSocketService.dart`
  Rename the file from `ILiveSocketService.dart` to `ILiveSessionService.dart` (git mv). Inside the file, rename the class from `ILiveSocketService` to `ILiveSessionService`. No other changes to the file content.

### Phase 2: Update all consumers

- [x] **Task 2: Update `LiveSessionGrpcService` import and implements clause** (depends on Task 1)
  Files: `lib/Core/Grpc/LiveSessionGrpcService.dart`
  - Change the import from `package:mind/Core/Grpc/ILiveSocketService.dart` to `package:mind/Core/Grpc/ILiveSessionService.dart`.
  - Change `implements ILiveSocketService` to `implements ILiveSessionService`.

- [x] **Task 3: Update `LiveBreathSessionNotifier` — import, type, field, and parameter** (depends on Task 1)
  Files: `lib/BreathModule/Core/LiveBreathSessionNotifier.dart`
  - Change the import from `package:mind/Core/Grpc/ILiveSocketService.dart` to `package:mind/Core/Grpc/ILiveSessionService.dart`.
  - Rename field `final ILiveSocketService _liveSocketService` to `final ILiveSessionService _liveSessionService`.
  - Rename constructor parameter `required ILiveSocketService liveSocketService` to `required ILiveSessionService liveSessionService`.
  - Update the initializer list: `_liveSocketService = liveSocketService` becomes `_liveSessionService = liveSessionService`.
  - Replace all six usages of `_liveSocketService.` with `_liveSessionService.` in the method bodies (`sessionStateEvents`, `sendActivityStart`, `sendActivityPause`, `sendActivityResume`, `sendActivityEnd`, `sendActivityStop`).

- [x] **Task 4: Update `BreathTelemetryService` — field and parameter** (depends on Task 1)
  Files: `lib/BreathModule/Core/BreathTelemetryService.dart`
  This file uses the concrete type `LiveSessionGrpcService`, not the interface, so no import change is needed. Rename:
  - Field `final LiveSessionGrpcService _liveSocketService` to `final LiveSessionGrpcService _liveSessionService`.
  - Constructor parameter `required LiveSessionGrpcService liveSocketService` to `required LiveSessionGrpcService liveSessionService`.
  - Initializer `_liveSocketService = liveSocketService` to `_liveSessionService = liveSessionService`.
  - All five usages of `_liveSocketService.` in method bodies to `_liveSessionService.` (`telemetryStateEvents`, `dataAckEvents`, `emitTelemetry` x2, `isConnected`).

- [x] **Task 5: Update `App.dart` — field, constructor param, local variable, and call sites** (depends on Tasks 3, 4)
  Files: `lib/Core/App.dart`
  - Rename the field `final LiveSessionGrpcService liveSocketService` to `final LiveSessionGrpcService liveSessionService`.
  - Rename the named constructor parameter `required this.liveSocketService` to `required this.liveSessionService`.
  - In `initialize()`, rename the local variable `final liveSocketService = LiveSessionGrpcService(...)` to `final liveSessionService = LiveSessionGrpcService(...)`.
  - Update the `LiveBreathSessionNotifier` constructor call: `liveSocketService: liveSocketService` becomes `liveSessionService: liveSessionService`.
  - Update the `BreathTelemetryService` constructor call: `liveSocketService: liveSocketService` becomes `liveSessionService: liveSessionService`.
  - Update the `App._()` constructor invocation: `liveSocketService: liveSocketService` becomes `liveSessionService: liveSessionService`.

- [x] **Task 6: Update test file — import, fake class name, factory return type, and constructor calls** (depends on Task 1)
  Files: `test/BreathModule/live_session_notifier_test.dart`
  - Change the import from `package:mind/Core/Grpc/ILiveSocketService.dart` to `package:mind/Core/Grpc/ILiveSessionService.dart`.
  - Rename the fake class from `FakeLiveSocketService` to `FakeLiveSessionService` (class declaration and `implements ILiveSocketService` → `implements ILiveSessionService`).
  - In the `_make()` factory function, update the return type record field from `FakeLiveSocketService socket` to `FakeLiveSessionService socket` and the instantiation `final socket = FakeLiveSocketService()` to `final socket = FakeLiveSessionService()`.
  - Update the `LiveBreathSessionNotifier` constructor call: `liveSocketService: socket` becomes `liveSessionService: socket`.
