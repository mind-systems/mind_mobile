## Code Review — Plan 42: Create ModuleInstructionStream

**Risk Level:** Low

### Files reviewed

| File | Status |
|------|--------|
| `lib/Core/Grpc/InstructionSample.dart` | New — OK |
| `lib/Core/Grpc/InstructionAck.dart` | New — OK |
| `lib/Core/Grpc/InstructionBuffer.dart` | New — OK |
| `lib/Core/Grpc/ModuleInstructionStream.dart` | New — 1 lint warning |
| `lib/BreathModule/Core/BreathTelemetryService.dart` | Modified — OK |
| `lib/Core/App.dart` | Modified — OK |
| `test/Core/Grpc/telemetry_buffer_test.dart` | Modified — OK, all 7 tests pass |

### Issues

**1. `TelemetryBuffer.dart` not deleted (Bug)**

`lib/Core/Grpc/TelemetryBuffer.dart` still exists. Task 3 specifies a rename, but the implementation created a new `InstructionBuffer.dart` and updated all imports without deleting the original file. No code imports it — it is dead code.

Fix: `git rm lib/Core/Grpc/TelemetryBuffer.dart`

**2. Redundant import in `ModuleInstructionStream.dart` (Lint)**

`flutter analyze` flags line 11:

```
info • The import of 'package:mind/Core/Grpc/generated/telemetry.pb.dart' is
       unnecessary because all of the used elements are also provided by the
       import of 'package:mind/Core/Grpc/generated/telemetry.pbgrpc.dart'
     • lib/Core/Grpc/ModuleInstructionStream.dart:11:8 • unnecessary_import
```

`telemetry.pbgrpc.dart` re-exports `telemetry.pb.dart`, so the explicit import of `telemetry.pb.dart` is redundant. Remove line 11.

### Verified correct

- **Lazy-connect pattern.** The `_isGrpcConnected` / `_streamRequested` two-flag design correctly defers `_openStream()` until the first `emit()` call, avoiding a duplicate telemetry RPC alongside `LiveSessionGrpcService` during the transition. Reconnect behavior is sound: connectivity-driven disconnects preserve `_streamRequested` (stream auto-reopens), while server errors reset it (stream only reopens on next `emit()`).
- **`Int64` conversions.** `_toProto` wraps `sample.timestamp` in `Int64(...)`. Ack mapping uses `.toInt()` on `receivedCount`, `droppedCount`, `timestamp`. `maxSamplesPerSecond` passes through as `int` (proto `int32`). All correct per the generated proto stubs.
- **`confirmConnected()` from lazy open.** Harmless — only resets the backoff counter, which is already 0 when the connection is established. Same pattern as `LiveSessionGrpcService` and `ModuleStateChannel`.
- **`emit()` null-safety after lazy open.** `_openStream()` sets `_telemetrySink` synchronously (line 94) before returning to `emit()` (line 80). The force-unwrap `_telemetrySink!` is safe. Dart's single-threaded execution prevents interleaving.
- **`onError`/`onDone` self-cancel safety.** These callbacks call `_connectionManager.disconnect()`, which synchronously delivers `disconnected` to the listener, which cancels `_telemetrySub` from within its own callback. This is safe in Dart — `cancel()` prevents future events without interfering with the executing callback. Same pattern as `LiveSessionGrpcService`.
- **App.dart wiring.** Single-line initializer, no trailing commas, placed after `moduleStateChannel`. Follows the style rule and initialization order.
- **Buffer rename.** All three files updated (`InstructionBuffer.dart`, `BreathTelemetryService.dart`, `telemetry_buffer_test.dart`). Class and import references consistent. Generic type (`Map<String, dynamic>`) intentionally unchanged per plan.
- **Model classes.** Plain Dart, `const` constructors, `required` named parameters, no Flutter imports. Matches `ModuleState.dart` / `ModuleStateEvent.dart` pattern.
- **Proto conversion helpers.** `_mapToStruct` and `_valueFrom` are identical to `LiveSessionGrpcService` — correct and production-proven.

REVIEW_PASS
