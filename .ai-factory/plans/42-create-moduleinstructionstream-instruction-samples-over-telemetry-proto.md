# Plan: Create ModuleInstructionStream — instruction samples over telemetry.proto

## Context

Extract the telemetry bidi stream from `LiveSessionGrpcService` into a dedicated `ModuleInstructionStream` class with typed models (`InstructionSample`, `InstructionAck`) instead of raw `Map<String, dynamic>`. This parallels `ModuleStateChannel` (which owns the `live.proto` stream) — `ModuleInstructionStream` owns the `telemetry.proto` stream. Rename `TelemetryBuffer` → `InstructionBuffer` to align naming.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Domain models

- [x] **Task 1: Create `InstructionSample` and `InstructionAck` models**
  Files: `lib/Core/Grpc/InstructionSample.dart`, `lib/Core/Grpc/InstructionAck.dart`
  Create two plain Dart model classes in `lib/Core/Grpc/` (pure Dart, no Flutter imports — same pattern as `ModuleState.dart` and `ModuleStateEvent.dart`).

  `InstructionSample` — represents one outgoing telemetry sample, maps 1:1 to `TelemetryData` proto fields:
  - `String sessionId`
  - `int timestamp` (Unix millis)
  - `String moduleId`
  - `String instructionType`
  - `Map<String, dynamic> data`
  - Named required-parameter constructor.

  `InstructionAck` — represents one incoming server acknowledgement, maps to `TelemetryAck` proto fields:
  - `String sessionId`
  - `int receivedCount`
  - `int droppedCount`
  - `int maxSamplesPerSecond`
  - `int timestamp` (Unix millis)
  - Named required-parameter constructor.

  **Note on `Int64` conversion:** The proto-generated `TelemetryData.timestamp`, `TelemetryAck.receivedCount`, `TelemetryAck.droppedCount`, and `TelemetryAck.timestamp` are `$fixnum.Int64`, not Dart `int`. Only `TelemetryAck.maxSamplesPerSecond` is `int32` (maps to `int` directly). Both models use plain `int` fields — the `Int64 ↔ int` conversion happens in `ModuleInstructionStream`'s proto conversion helpers (Task 2), not in the models themselves.

### Phase 2: Stream class + buffer rename

- [x] **Task 2: Create `ModuleInstructionStream` class** (depends on Task 1)
  Files: `lib/Core/Grpc/ModuleInstructionStream.dart`
  Create the class in `lib/Core/Grpc/`, following the exact structure of `LiveSessionGrpcService` for the telemetry stream lifecycle. Constructor-inject all dependencies (project rule: all deps via constructor).

  **Constructor parameters:**
  - `GrpcConnectionManager connectionManager`
  - `TelemetryServiceClient telemetryService`

  **Connection lifecycle — lazy connect (no eager stream open):**
  Unlike `ModuleStateChannel` (which opens its bidi stream eagerly on `connected`), `ModuleInstructionStream` uses lazy connect to avoid opening a duplicate telemetry stream alongside the existing `LiveSessionGrpcService` during the transition period (both subscribe to the same `GrpcConnectionManager` and would each open a `TelemetryService.StreamTelemetry` RPC).

  - Subscribe to `connectionManager.connectionState` in the constructor (`late final StreamSubscription`).
  - On `connected` → set `_isGrpcConnected = true`. If the stream was previously requested (i.e. `_streamRequested == true`), call `_openStream()`.
  - On `disconnected` → set `_isGrpcConnected = false`, cancel response subscription, close sink, null both.
  - On `connecting` → no-op.
  - `_openStream()` — create a new `StreamController<TelemetryData>` sink, call `_telemetryService.streamTelemetry(sink.stream)`, listen on the response. On successful open call `_connectionManager.confirmConnected()` and fire `_readyController.add(null)`.
  - In response listener: switch on `TelemetryResponse_Event` — on `ack` convert `TelemetryAck` to `InstructionAck` and add to `_ackController`; on `error` log it; on `notSet` no-op.
  - On stream `onError`/`onDone`: set `_streamRequested = false`, log, call `_connectionManager.disconnect()` then `_connectionManager.scheduleReconnect()`.

  **Public API:**
  - `void emit(InstructionSample sample)` — if sink is null and `_isGrpcConnected`, set `_streamRequested = true` and call `_openStream()`, then add to sink once open. If not gRPC-connected, log and drop. For the normal path (sink already open), convert `InstructionSample` to `TelemetryData` proto and add to sink.
  - `Stream<InstructionAck> get acks` — from `StreamController<InstructionAck>.broadcast()`.
  - `Stream<void> get readyEvents` — from `StreamController<void>.broadcast()`, fires once per stream open (same role as `LiveSessionGrpcService.telemetryStateEvents`).
  - `bool get isConnected` — `_sink != null`.
  - `void dispose()` — cancel connection subscription, cancel response subscription, close sink, close both broadcast controllers.

  **Proto conversion helpers** (copy from `LiveSessionGrpcService`, keep private):
  - `Struct _mapToStruct(Map<String, dynamic>)` — converts `data` field.
  - `Value _valueFrom(dynamic)` — recursive value conversion.
  - `TelemetryData _toProto(InstructionSample)` — builds the proto message from typed model fields. Must import `package:fixnum/fixnum.dart` and wrap `sample.timestamp` in `Int64(sample.timestamp)` (proto `timestamp` is `int64`).

  **Ack mapping** (in response listener): convert `TelemetryAck` → `InstructionAck` using `.toInt()` on `Int64` fields:
  - `receivedCount: ack.receivedCount.toInt()`
  - `droppedCount: ack.droppedCount.toInt()`
  - `timestamp: ack.timestamp.toInt()`
  - `maxSamplesPerSecond: ack.maxSamplesPerSecond` (already `int`, no conversion needed)

- [x] **Task 3: Rename `TelemetryBuffer` → `InstructionBuffer`**
  Files: `lib/Core/Grpc/TelemetryBuffer.dart` → `lib/Core/Grpc/InstructionBuffer.dart`, `lib/BreathModule/Core/BreathTelemetryService.dart`, `test/Core/Grpc/telemetry_buffer_test.dart`
  Rename file from `TelemetryBuffer.dart` to `InstructionBuffer.dart`. Rename class from `TelemetryBuffer` to `InstructionBuffer`. Update all import paths and references:
  - `BreathTelemetryService.dart`: update import path, change `TelemetryBuffer` → `InstructionBuffer` in field type and constructor call.
  - `telemetry_buffer_test.dart`: update import path, change all `TelemetryBuffer` references to `InstructionBuffer`.
  Keep the buffer's generic type (`Map<String, dynamic>`) unchanged — milestone 7.6 will update it to hold `InstructionSample` when `BreathTelemetryService` is renamed.

### Phase 3: Wiring

- [x] **Task 4: Wire `ModuleInstructionStream` in App.dart** (depends on Task 2)
  Files: `lib/Core/App.dart`
  Add `ModuleInstructionStream` as a new field on the `App` class, alongside the existing `LiveSessionGrpcService` (which will be removed in milestone 7.4).
  - Add import for `ModuleInstructionStream.dart`.
  - Add field: `final ModuleInstructionStream instructionStream`.
  - Add named constructor parameter: `required this.instructionStream`.
  - In `initialize()`, create the instance after `connectionManager` (single-line style, no trailing commas):
    `final instructionStream = ModuleInstructionStream(connectionManager: connectionManager, telemetryService: grpcClient.telemetryService);`
  - Pass `instructionStream: instructionStream` to the `App._()` constructor call.
  - Place the initializer line right after `moduleStateChannel` (both are parallel stream owners under the same `GrpcConnectionManager`).
  - The lazy-connect design (Task 2) ensures `ModuleInstructionStream` won't open a telemetry RPC until something calls `emit()` — so it coexists safely with `LiveSessionGrpcService` during the transition. No dual streams will be opened.
