# Live Session Architecture Refactor — Naming & Structure

**Date:** 2026-03-27 (updated 2026-03-28)
**Source:** conversation context

## Key Findings

- `LiveSessionGrpcService` does three unrelated things — connection management, activity lifecycle stream, instruction stream — and must be split.
- `LiveBreathSessionNotifier` is not a notifier; it's an optimistic guard (two pending booleans) with a Map→typed-state mapper. It should be absorbed into `ModuleStateChannel`.
- New naming convention: general-to-specific with consistent suffixes — `ModuleStateChannel` / `ModuleInstructionStream` at the common layer, `BreathModuleStateChannel` / `BreathModuleInstructionStream` at the breath layer. "Coordinator" is already overloaded in this project (screen coordinators, animation coordinators) and must not be used here.
- "Telemetry" is a misleading term — replaced everywhere by "Instruction".

## Details

### New Common Layer (`lib/Core/Grpc/`)

| New class | Replaces | Responsibility |
|---|---|---|
| `GrpcConnectionManager` | (part of `LiveSessionGrpcService`) | connect / disconnect / backoff / auth+connectivity+resume listeners; exposes `Stream<ConnectionState>` that channels subscribe to |
| `ModuleStateChannel` | `LiveSessionGrpcService` (live.proto part) + `LiveBreathSessionNotifier` | send start/pause/resume/end/stop; hold pending guards; map proto `SessionStateEvent` → typed `ModuleStateEvent`; expose `Stream<ModuleStateEvent>` |
| `ModuleInstructionStream` | `LiveSessionGrpcService` (telemetry.proto part) | emit `InstructionSample`s; receive rate-limit acks; subscribe to `GrpcConnectionManager.connectionState` |
| `InstructionBuffer` | `TelemetryBuffer` | ring buffer (500 samples) for offline queueing |
| `ConnectionState` | `SocketConnectionState` | enum `connecting / connected / disconnected`; owned by `GrpcConnectionManager`, not exported beyond `lib/Core/Grpc/` |

### New Breath Module Layer (`lib/BreathModule/Core/`)

| New class | Replaces | Responsibility |
|---|---|---|
| `BreathModuleStateChannel` | `LiveBreathSessionCoordinator` + `LiveBreathSessionService` | listens to `BreathSessionState`; translates state transitions into `channel.start(ActivityType.breath, refId)` / `channel.resume()` / `channel.pause()` / `channel.end()`; reads `liveSessionId` from channel events and passes to instruction stream |
| `BreathModuleInstructionStream` | `BreathTelemetryService` | on phase change: `instructionStream.emit(phase, durationMs)`; rate limiting via acks |

### Classes That Disappear

- `LiveBreathSessionNotifier` — absorbed into `ModuleStateChannel`
- `LiveBreathSessionService` — absorbed into `BreathModuleStateChannel`
- `LiveSessionGrpcService` — split into `GrpcConnectionManager` + `ModuleStateChannel` + `ModuleInstructionStream`
- `BreathTelemetryService` → renamed `BreathModuleInstructionStream`
- `TelemetryBuffer` → renamed `InstructionBuffer`
- `SocketConnectionState` → renamed `ConnectionState` (file + enum); used only inside `lib/Core/Grpc/`

### Data Flow (After)

```
BreathSessionState stream
        │
        ▼
BreathModuleStateChannel          BreathModuleInstructionStream
  injects: ModuleStateChannel       injects: ModuleInstructionStream
  knows: ActivityType.breath        on phase change: emit(phase, durationMs)
  sends: start/pause/resume/end     buffers via: InstructionBuffer
  reads: liveSessionId from events  rate limit via acks
        │                                          │
        ▼                                          ▼
  ModuleStateChannel              ModuleInstructionStream
  (live.proto bidi stream)        (telemetry.proto bidi stream)
        │                                          │
        └──────────── GrpcConnectionManager ───────┘
                      exposes Stream<ConnectionState>
                      channels subscribe independently
```

### Proto Services (unchanged)

- `mind.LiveService/LiveSession` — activity lifecycle (start/pause/resume/end)
- `mind.TelemetryService/StreamTelemetry` — instruction samples + rate-limit acks
- Biometric stream — future, will be a third consumer of `GrpcConnectionManager`

### Naming Rationale

**Why `Channel` vs `Stream`:**
`ModuleStateChannel` is bidirectional — client sends commands, server sends back `SessionStateEvent` with `liveSessionId` and status. "Channel" reflects the two-way nature. `ModuleInstructionStream` is effectively unidirectional (client → server), with only lightweight acks returning, so "Stream" is correct.

**Why `Breath` prefix on the specializations:**
`BreathModuleStateChannel` and `BreathModuleInstructionStream` follow the same suffix as the common layer — same shape, breath-specific behavior. Any future module (yoga, meditation) gets `YogaModuleStateChannel` etc., making the pattern immediately readable.

**Why `ActivityType` ownership lives in `BreathModuleStateChannel`:**
`ModuleStateChannel` is activity-agnostic — it sends whatever `ActivityType` it receives. `BreathModuleStateChannel` is the only class that knows it is `ActivityType.breath` and passes that into `channel.start()`. This is the correct boundary.

## Decisions (closed)

- **GrpcConnectionManager → channels notification**: `GrpcConnectionManager` exposes `Stream<ConnectionState>`. `ModuleStateChannel` and `ModuleInstructionStream` subscribe to it in their constructors. No callbacks — consistent with the project's stream-based lifecycle pattern.
- **Map<String, dynamic> in proto layer**: Removed. `ModuleStateChannel` receives typed proto objects (`SessionStateEvent`) directly. Eliminates the last Socket.io-era stringly-typed artifact.
- **ActivityType ownership**: `BreathModuleStateChannel` owns `ActivityType.breath` and passes it to `ModuleStateChannel.start()`. `ModuleStateChannel` is activity-agnostic.
