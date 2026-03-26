# Plan: Delete Socket.io client files and remove dependency

## Context
The gRPC migration is complete (`LiveSessionGrpcService` replaced `LiveSocketService`, `SyncGrpcListener` replaced `SyncSocketListener`). This milestone removes the now-obsolete `lib/Core/Socket/` directory and the `socket_io_client` dependency. Three files in Socket/ are still referenced by live code (`ILiveSocketService`, `SocketConnectionState`, `TelemetryBuffer`) and must be relocated before deletion. Removing the debug overlay also leaves dead diagnostic properties in `LiveSessionGrpcService` that must be cleaned up.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Relocate still-used types

- [x] **Task 1: Move `ILiveSocketService.dart` and `SocketConnectionState.dart` to `lib/Core/Grpc/`**
  Files: `lib/Core/Socket/ILiveSocketService.dart`, `lib/Core/Socket/SocketConnectionState.dart`, `lib/Core/Grpc/LiveSessionGrpcService.dart`, `lib/BreathModule/Core/LiveBreathSessionNotifier.dart`, `test/BreathModule/live_session_notifier_test.dart`

  Move both files from `lib/Core/Socket/` to `lib/Core/Grpc/`. Then update import paths in all consumers:
  - `lib/Core/Grpc/LiveSessionGrpcService.dart` — change both imports from `package:mind/Core/Socket/...` to `package:mind/Core/Grpc/...`
  - `lib/BreathModule/Core/LiveBreathSessionNotifier.dart` — change `ILiveSocketService` import to `package:mind/Core/Grpc/ILiveSocketService.dart`
  - `test/BreathModule/live_session_notifier_test.dart` — change `ILiveSocketService` import to `package:mind/Core/Grpc/ILiveSocketService.dart`

- [x] **Task 2: Move `TelemetryBuffer.dart` to `lib/Core/Grpc/` and relocate its test** (depends on Task 1)
  Files: `lib/Core/Socket/TelemetryBuffer.dart`, `lib/BreathModule/Core/BreathTelemetryService.dart`, `test/Core/Socket/telemetry_buffer_test.dart`

  Move `TelemetryBuffer.dart` from `lib/Core/Socket/` to `lib/Core/Grpc/`. Update imports:
  - `lib/BreathModule/Core/BreathTelemetryService.dart` — change import to `package:mind/Core/Grpc/TelemetryBuffer.dart`

  Move the test file from `test/Core/Socket/telemetry_buffer_test.dart` to `test/Core/Grpc/telemetry_buffer_test.dart` (create `test/Core/Grpc/` directory if it doesn't exist). Update the import inside the test to `package:mind/Core/Grpc/TelemetryBuffer.dart`. Remove the now-empty `test/Core/Socket/` directory.

### Phase 2: Remove debug overlay, clean up dead code, and delete Socket directory

- [x] **Task 3: Remove `SocketDebugOverlay` from `App.dart` and delete the file** (depends on Task 1)
  Files: `lib/Core/App.dart`, `lib/Core/Socket/SocketDebugOverlay.dart`

  In `App.dart`:
  1. Remove the import `package:mind/Core/Socket/SocketDebugOverlay.dart` (line 27).
  2. Replace the conditional overlay logic (around line 242-243) — remove the `if (Environment.instance.isProduction) return body;` guard and the `return Stack(children: [body, const SocketDebugOverlay()]);` line. Just return `body` unconditionally.

  Then delete `lib/Core/Socket/SocketDebugOverlay.dart`.

- [x] **Task 4: Remove dead debug properties from `LiveSessionGrpcService`** (depends on Task 3)
  Files: `lib/Core/Grpc/LiveSessionGrpcService.dart`

  With `SocketDebugOverlay` deleted, `lastSentMessage` and `lastReceivedMessage` have no consumers. Remove:
  1. The two `ValueNotifier<String>` declarations (`lastSentMessage`, `lastReceivedMessage`).
  2. All four `SchedulerPhase.idle` guard blocks that write to them:
     - In `_openLiveStream` — the block setting `lastReceivedMessage` on incoming session state.
     - In `_openTelemetryStream` — the block setting `lastReceivedMessage` on incoming ack.
     - In `emitLive` — the block setting `lastSentMessage` after adding to `_liveSink`.
     - In `emitTelemetry` — the block setting `lastSentMessage` after adding to `_telemetrySink`.
  3. The `.dispose()` calls for both `ValueNotifier`s in the `dispose` method.
  4. Remove the `import 'package:flutter/scheduler.dart'` if no other code in the file uses `SchedulerPhase` (check first).

- [x] **Task 5: Delete remaining Socket files and directory** (depends on Tasks 2, 3, 4)
  Files: `lib/Core/Socket/LiveSocketService.dart`, `lib/Core/Socket/SocketConnectionCoordinator.dart`, `lib/Core/Socket/`

  Delete these dead-code files:
  - `lib/Core/Socket/LiveSocketService.dart`
  - `lib/Core/Socket/SocketConnectionCoordinator.dart`

  `SyncSocketListener.dart` was already deleted in a prior milestone — confirm it is absent.

  After deletion, verify `lib/Core/Socket/` is empty and remove the directory.

- [x] **Task 6: Remove `socket_io_client` dependency** (depends on Task 5)
  Files: `pubspec.yaml`, `pubspec.lock`

  Run `/usr/local/bin/flutter pub remove socket_io_client`. This removes the dependency from `pubspec.yaml` and updates `pubspec.lock` (also removes the transitive `socket_io_common` dependency).

  Verify the project still resolves: run `/usr/local/bin/flutter pub get` and confirm no errors.

## Commit Plan
- **Commit 1** (after tasks 1-3): "Move reusable types from Socket to Grpc and remove debug overlay"
- **Commit 2** (after tasks 4-6): "Remove dead debug properties, delete Socket.io files, and remove dependency"
