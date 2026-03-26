# Code Review: 30 — Delete Socket.io client files and remove dependency

**Plan:** `30-delete-socket-io-client-files-and-remove-dependency.md`
**Risk Level:** Low

## Verification

### File relocations
- `ILiveSocketService.dart` — moved to `lib/Core/Grpc/`, content unchanged (similarity 100%).
- `SocketConnectionState.dart` — moved to `lib/Core/Grpc/`, content unchanged (similarity 100%).
- `TelemetryBuffer.dart` — moved to `lib/Core/Grpc/`, content unchanged (similarity 100%).
- `telemetry_buffer_test.dart` — moved from `test/Core/Socket/` to `test/Core/Grpc/`, import updated.
- Both `lib/Core/Socket/` and `test/Core/Socket/` directories no longer exist.

### Import updates — all consumers verified
- `LiveSessionGrpcService.dart` — both imports updated to `Core/Grpc/` paths.
- `LiveBreathSessionNotifier.dart` — `ILiveSocketService` import updated.
- `BreathTelemetryService.dart` — `TelemetryBuffer` import updated.
- `test/BreathModule/live_session_notifier_test.dart` — `ILiveSocketService` import updated.
- `test/Core/Grpc/telemetry_buffer_test.dart` — `TelemetryBuffer` import updated.
- No remaining `Core/Socket/` import paths exist anywhere in `lib/` or `test/`.

### Debug overlay removal
- `SocketDebugOverlay.dart` deleted.
- `App.dart` — import removed; `builder:` callback simplified to return `GlobalListeners` directly without the `isProduction` guard and `Stack` wrapper. Clean and correct.

### Dead code cleanup in `LiveSessionGrpcService`
- `lastSentMessage` and `lastReceivedMessage` (`ValueNotifier<String>`) declarations removed.
- All four `SchedulerPhase.idle` guard blocks removed (two in receive handlers, two in emit methods).
- Both `.dispose()` calls for the ValueNotifiers removed.
- `import 'package:flutter/scheduler.dart'` removed.
- `import 'package:flutter/widgets.dart'` removed (was only needed for `ValueNotifier` and `WidgetsBinding`).
- No remaining references to `lastSentMessage`, `lastReceivedMessage`, `SchedulerPhase`, or `flutter/widgets` in the file.

### Deleted files
- `LiveSocketService.dart` — deleted (dead code, only referenced by `SocketConnectionCoordinator`).
- `SocketConnectionCoordinator.dart` — deleted (dead code, only referenced `LiveSocketService`).
- `SocketDebugOverlay.dart` — deleted (sole consumer of debug properties).

### Dependency removal
- `socket_io_client: ^3.1.4` removed from `pubspec.yaml`.
- `socket_io_client` and `socket_io_common` (transitive) removed from `pubspec.lock`.
- No `.dart` files in the project import `socket_io_client`.

## Issues

None found. All changes are mechanical relocations, import path updates, and dead code removal. No logic changes, no new code, no behavioral differences at runtime.

REVIEW_PASS
