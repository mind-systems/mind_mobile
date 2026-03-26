# Review: Replace SocketConnectionCoordinator.dart

**Plan:** `.ai-factory/plans/28-replace-socketconnectioncoordinator-dart.md`
**Scope:** 4 files changed (App.dart, LiveSessionGrpcService.dart, BreathTelemetryService.dart, plan file)

---

## Correctness

### LiveSessionGrpcService — connectivity and resume handlers

The connectivity handler mirrors `SocketConnectionCoordinator` exactly:
- `ConnectivityResult.none` → `disconnect()`
- Otherwise, if `_isAuthenticated` → `connect()`

The resume handler also matches:
- `_isAuthenticated && !isConnected` → `connect()`

Both subscriptions are stored as `late final` fields and cancelled in `dispose()`. Logic is correct.

### App.dart wiring

- `LiveSessionGrpcService` replaces both `LiveSocketService` and `SocketConnectionCoordinator` — field type updated, constructor parameter removed, imports swapped. Correct.
- Downstream consumers (`LiveBreathSessionNotifier`, `BreathTelemetryService`) receive `liveSocketService` — `LiveBreathSessionNotifier` accepts `ILiveSocketService` (the interface), and `LiveSessionGrpcService implements ILiveSocketService`. Correct.
- `BreathTelemetryService` now takes `LiveSessionGrpcService` (concrete) because it uses `telemetryStateEvents`, `dataAckEvents`, and `emitTelemetry` which are not on the interface. Correct.

### SocketDebugOverlay

Not changed. It accesses `App.shared.liveSocketService` (now typed as `LiveSessionGrpcService`), which exposes `connectionState`, `lastSentMessage`, and `lastReceivedMessage` with the same signatures. No import change needed since it only imports `App.dart` and `SocketConnectionState.dart`. Compiles without changes.

### GrpcClient

Already exposes `liveService` and `telemetryService` (lines 33, 36). No changes needed.

---

## Issues

### [cleanup] Dead files not removed

`SocketConnectionCoordinator.dart` and `LiveSocketService.dart` are no longer imported by any production code. They remain on disk as dead code. `socket_io_client` package is only used by `LiveSocketService.dart` — it can be removed from `pubspec.yaml` once the file is deleted.

Not a bug — the plan scope was "replace", not "delete". Flag for next milestone.

---

## Summary

All five plan tasks are implemented correctly. The lifecycle logic (auth, connectivity, resume) now lives entirely within `LiveSessionGrpcService`, matching the original `SocketConnectionCoordinator` behavior exactly. Type wiring in `App.dart` is consistent, and all consumers compile against the new concrete or interface types. No runtime breakage, no type mismatches, no race conditions introduced beyond what already existed.

REVIEW_PASS
