# Code Review — Plan 44: Delete `LiveSessionGrpcService`

**Files Changed:** 5 (`ModuleInstructionStream.dart`, `BreathTelemetryService.dart`, `App.dart`, `ARCHITECTURE.md`, `ROADMAP.md`) + 1 deleted (`LiveSessionGrpcService.dart`)

## Verification

- `flutter analyze` on all changed files: 0 errors, 0 warnings. 1 pre-existing `unnecessary_import` info on `ModuleInstructionStream.dart:11` — not introduced by this change.
- `grep LiveSessionGrpcService lib/` — no matches. All references in `lib/` are removed.
- `App.dart` wiring: `BreathTelemetryService(instructionStream: instructionStream)` — the `instructionStream` local (line 164) already existed. Field, constructor parameter, construction line, and assignment for `liveGrpcService` all removed cleanly.
- `IBreathTelemetryService` interface requires only `sendSample(String, String, int)` — implementation satisfies it.

## Analysis

**1. Deadlock fix — `isGrpcConnected` getter (ModuleInstructionStream.dart:29)**

Correctly addresses the eager-vs-lazy deadlock. Trace:
- gRPC connects → `_isGrpcConnected = true`
- `sendSample()` → `_canSendNow()` checks `isGrpcConnected` → true
- `_emit()` → `_instructionStream.emit(sample)` → `_telemetrySink == null` + `_isGrpcConnected == true` → `_openStream()` → `_readyController.add(null)` → synchronous broadcast → `flushBuffer()` → buffer drained → original sample sent

The reentrant `emit()` calls from `flushBuffer()` are safe because `_telemetrySink` is set by `_openStream()` before `readyEvents` fires, so reentrant calls skip the `_telemetrySink == null` branch.

**2. Map key consistency (BreathTelemetryService.dart:27-35, 47-53, 70-76)**

`sendSample()` builds the payload with keys `sessionId`, `timestamp`, `module_id`, `instruction_type`, `data`. Both `_emit()` and `flushBuffer()` extract from the map using the same keys with matching types. No key mismatch.

**3. `_onDataAck` (BreathTelemetryService.dart:80-83)**

Old code extracted `maxSamplesPerSecond` from `Map<String, dynamic>` with a runtime type check. New code reads `ack.maxSamplesPerSecond` directly from `InstructionAck` (typed `int`). The `> 0` guard is retained. Correct.

**4. App.dart deletion (lines 47, 74-78, 97-102, 162-168, 184-192)**

Import removed. Field, constructor param, construction line, and assignment all deleted. No other consumer of `liveGrpcService` existed. Clean removal.

**5. ARCHITECTURE.md (line 41)**

Updated from `GrpcClient, GrpcAuthInterceptor, LiveSessionGrpcService` to `GrpcClient, GrpcAuthInterceptor, GrpcConnectionManager, ModuleStateChannel, ModuleInstructionStream`. Matches the actual contents of `lib/Core/Grpc/` (the comment lists the main service classes, not every file). Accurate.

**6. ROADMAP.md (line 141)**

Checkbox toggled `- [ ]` → `- [x]`. Correct milestone.

## Suggestions

**1. Stale doc reference (out of scope)**

`docs/core/testing.md:37` still mentions `LiveSessionGrpcService` in the "what not to test" table. Plan Settings: Docs: no, so this is out of scope — but worth a follow-up cleanup.

**2. Duplicate map-to-sample conversion**

`_emit()` (line 70-76) and `flushBuffer()` (line 47-53) contain identical `InstructionSample(...)` construction from map keys. Could extract a `_toSample(Map<String, dynamic>)` helper. Minor DRY nit — not blocking.

REVIEW_PASS
