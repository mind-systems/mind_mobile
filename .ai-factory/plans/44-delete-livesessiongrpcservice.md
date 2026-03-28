# Plan: Delete `LiveSessionGrpcService`

## Context

`LiveSessionGrpcService` is a thin facade that opens an eager `telemetry.proto` bidi stream and exposes an untyped `emitTelemetry(String, dynamic)` API. Its connection lifecycle was already extracted to `GrpcConnectionManager`, its session commands to `ModuleStateChannel`, and a typed replacement (`ModuleInstructionStream`) already exists and is wired in `App.dart` — but unused. The only consumer of `LiveSessionGrpcService` is `BreathTelemetryService`, which must be migrated to `ModuleInstructionStream` before the class can be deleted. `ILiveSessionService` was already deleted in a prior milestone — no action needed for it.

**Eager vs lazy connection model:** `LiveSessionGrpcService` opens the bidi stream eagerly on `GrpcConnectionState.connected`, making `isConnected` true immediately. `ModuleInstructionStream` uses lazy-connect — it only opens the bidi stream on the first `emit()` call. Its `isConnected` getter (returns `_telemetrySink != null`) stays `false` until then. Using `isConnected` in `_canSendNow()` would deadlock: samples buffer → buffer flushes on `readyEvents` → `readyEvents` fires in `_openStream()` → `_openStream()` called from `emit()` → `emit()` never called because `_canSendNow()` returns false. To bridge this, Task 1 exposes a separate `isGrpcConnected` getter that reflects the underlying transport readiness (`_isGrpcConnected` flag) independent of whether the bidi stream has opened.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Prepare `ModuleInstructionStream`

- [x] **Task 1: Add `isGrpcConnected` getter to `ModuleInstructionStream`**
  Files: `lib/Core/Grpc/ModuleInstructionStream.dart`
  Add a public getter `bool get isGrpcConnected => _isGrpcConnected;` alongside the existing `isConnected` getter. This exposes whether the gRPC transport is ready (true as soon as `GrpcConnectionState.connected` fires), independent of whether the lazy bidi stream has been opened. `BreathTelemetryService` needs this to decide "should I emit or buffer?" without triggering the deadlock described in the Context section. The existing `isConnected` getter remains unchanged — it is still useful internally and for callers that need to know if the bidi stream is actually open.

### Phase 2: Migrate the consumer

- [x] **Task 2: Rewrite `BreathTelemetryService` to use `ModuleInstructionStream`** (depends on Task 1)
  Files: `lib/BreathModule/Core/BreathTelemetryService.dart`
  Replace the `LiveSessionGrpcService` dependency with `ModuleInstructionStream`. Change the constructor parameter from `LiveSessionGrpcService liveSessionService` to `ModuleInstructionStream instructionStream`. Rewrite the class internals:

  **`_canSendNow()`:** Replace `_liveSessionService.isConnected` with `_instructionStream.isGrpcConnected` (the new getter from Task 1, NOT `isConnected`). This way, when gRPC is up but the bidi stream hasn't opened yet, `_canSendNow()` returns true → `_emit()` calls `_instructionStream.emit()` → lazy-opens the stream → `readyEvents` fires → buffer flushes. Rate-limiting logic (`_lastSendTime` / `_maxSamplesPerSecond`) stays unchanged.

  **`sendSample()`:** Keep building the `Map<String, dynamic>` payload first (as today). If `_canSendNow()` is true, convert the map to an `InstructionSample` and call `_instructionStream.emit(sample)`. If false, enqueue the raw map into `InstructionBuffer` (which is typed `Map<String, dynamic>` and cannot store `InstructionSample`). The conversion order is: build map → check gate → convert to `InstructionSample` only at emit time.

  **`_emit()`:** Replace `_liveSessionService.emitTelemetry('data:stream', payload)` with: build `InstructionSample` from the payload map (`sessionId`, `timestamp: DateTime.now().millisecondsSinceEpoch`, `moduleId: 'breath'`, `instructionType: 'breath_phase'`, `data: { 'phase': phase, 'durationMs': durationMs }`) and call `_instructionStream.emit(sample)`. Update `_lastSendTime` as before.

  **`flushBuffer()`:** For each buffered `Map<String, dynamic>` from `_buffer.flush()`, build an `InstructionSample` from the map fields and call `_instructionStream.emit(sample)`.

  **Subscriptions:** Replace `_liveSessionService.telemetryStateEvents` with `_instructionStream.readyEvents` (same `Stream<void>` signature — triggers `flushBuffer()`). Replace `_liveSessionService.dataAckEvents` (`Stream<Map<String, dynamic>>`) with `_instructionStream.acks` (`Stream<InstructionAck>`). In `_onDataAck`, read `ack.maxSamplesPerSecond` directly from the typed `InstructionAck` field instead of extracting from a map.

  **Imports:** Remove `LiveSessionGrpcService.dart` import. Add imports for `ModuleInstructionStream.dart`, `InstructionSample.dart`, `InstructionAck.dart`.

  **Note on statefulness:** This class holds `StreamSubscription` fields and has an explicit `dispose()` method — this is a pre-existing violation of the RULES.md stateless-Service rule (Services must have no `StreamSubscription`, no `dispose()`). This violation is deferred to milestone 7.6 (refactor telemetry into the proper Service/Notifier pattern). This task preserves the existing pattern as-is and only swaps the dependency.

- [x] **Task 3: Update `App.dart` wiring — connect `BreathTelemetryService` to `ModuleInstructionStream`** (depends on Task 2)
  Files: `lib/Core/App.dart`
  Change the `BreathTelemetryService` construction line from `BreathTelemetryService(liveSessionService: liveGrpcService)` to `BreathTelemetryService(instructionStream: instructionStream)`. The `instructionStream` local variable already exists (line 167). This makes `liveGrpcService` unreferenced by any consumer.

### Phase 3: Delete the dead class

- [x] **Task 4: Remove `LiveSessionGrpcService` from `App.dart`** (depends on Task 3)
  Files: `lib/Core/App.dart`
  Delete the `final LiveSessionGrpcService liveGrpcService;` field declaration, the corresponding named constructor parameter `required this.liveGrpcService`, the local construction line `final liveGrpcService = LiveSessionGrpcService(...)`, and the `liveGrpcService: liveGrpcService` assignment in the `App._()` call. Remove the import of `LiveSessionGrpcService.dart`.

- [x] **Task 5: Delete `LiveSessionGrpcService.dart`** (depends on Task 4)
  Files: `lib/Core/Grpc/LiveSessionGrpcService.dart`
  Delete the file entirely. No other file in `lib/` imports it after Tasks 2-4.

### Phase 4: Clean up references

- [x] **Task 6: Update `ARCHITECTURE.md` — remove `LiveSessionGrpcService` from folder structure** (depends on Task 5)
  Files: `.ai-factory/ARCHITECTURE.md`
  In the folder structure comment on the `lib/Core/Grpc/` line (line 42), remove `, LiveSessionGrpcService` from the description. The line currently reads `Grpc/  # GrpcClient, GrpcAuthInterceptor, LiveSessionGrpcService` — update to `Grpc/  # GrpcClient, GrpcAuthInterceptor, GrpcConnectionManager, ModuleStateChannel, ModuleInstructionStream`.

- [x] **Task 7: Mark ROADMAP milestone 7.4 as done** (depends on Task 5)
  Files: `.ai-factory/ROADMAP.md`
  Change the checkbox on the "Delete `LiveSessionGrpcService`" item from `- [ ]` to `- [x]`. The `ILiveSessionService` interface was already deleted — no additional action for that part.

## Commit Plan
- **Commit 1** (after tasks 1-5): "Delete LiveSessionGrpcService and migrate BreathTelemetryService to ModuleInstructionStream"
- **Commit 2** (after tasks 6-7): "Update architecture docs and roadmap after LiveSessionGrpcService removal"
