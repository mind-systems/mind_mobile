# Review: Update BreathTelemetryService.sendSample()

## Files changed

| File | Change |
|------|--------|
| `lib/BreathModule/Core/BreathTelemetryService.dart` | Added `module_id` and `instruction_type` to the payload map |
| `lib/Core/Grpc/LiveSessionGrpcService.dart` | Read `moduleId` / `instructionType` from payload instead of hardcoding |

## Analysis

### Correctness

Both changes are straightforward and correct:

- **BreathTelemetryService**: The two new keys (`module_id`, `instruction_type`) are added to the top-level payload map. They flow through `_emit()` and `flushBuffer()` unchanged — both paths call `_liveSocketService.emitTelemetry('data:stream', payload)` with the same map. Buffered samples carry the discriminator identically to unbuffered ones.

- **LiveSessionGrpcService**: The `emitTelemetry()` method reads the values with `as String? ?? ''`, matching the existing null-safety pattern used for `sessionId`. The fallback to empty string is safe — protobuf string fields default to `""` anyway, so there is no type mismatch or crash risk.

### Transport paths

- **gRPC path** (`LiveSessionGrpcService`): Reads `module_id` / `instruction_type` from the map and sets them on the `TelemetryData` proto. Correct.
- **Socket.IO path** (`LiveSocketService`): Passes the raw map to `_telemetrySocket?.emit(event, data)` as-is. The two new keys are included in the JSON automatically. No change needed — the server-side Socket.IO handler already receives them.

### No other callers

`emitTelemetry` is only called from `BreathTelemetryService` (two call sites: `_emit` and `flushBuffer`). Both receive payloads built by `sendSample()`, which now includes the discriminator. There is no other caller that would silently send empty `moduleId`/`instructionType` after this change.

### Interface unchanged

`IBreathTelemetryService.sendSample(String sessionId, String phase, int durationMs)` is not modified. The discriminator fields are implementation details of the concrete `BreathTelemetryService`, not part of the module contract. This is the correct boundary.

## Verdict

No bugs, no security issues, no runtime risks. The change is minimal and does exactly what the milestone requires.

REVIEW_PASS
