## Code Review Summary

**Files Reviewed:** 7 (`ModuleInstructionStream.dart`, `BreathModuleInstructionStream.dart`, `App.dart`, `BreathModule.dart`, `BreathModuleStateChannel.dart`, `ARCHITECTURE.md`, `ROADMAP.md`)
**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md:** WARN — `BreathModuleInstructionStream` holds `StreamSubscription` fields and has `dispose()`, which is a stateful pattern. However, this class does not implement any `IXxxService` interface, so it is not a "Module Service" in the ARCHITECTURE.md/RULES.md sense. The plan explicitly defers this structural concern to milestone 7.6. No action needed here.
- **RULES.md:** WARN — Same as above. The class is a domain-layer stream bridge, not a module-boundary Service. No violation.
- **ROADMAP.md:** OK — Milestone 7.4 properly marked as done.

### Critical Issues

None.

### Suggestions

1. **Stale reference in `docs/core/testing.md:37`** — The line `| **Infrastructure** (LiveSessionGrpcService, GrpcAuthInterceptor, GrpcClient) | Require mocking gRPC. Fragile, expensive to maintain, simple logic. |` still names the deleted class. Replace `LiveSessionGrpcService` with the current infrastructure classes (e.g. `GrpcConnectionManager`, `ModuleInstructionStream`). The plan settings say "Docs: no", but this is a one-line fix that prevents future confusion.

### Positive Notes

- **Clean deletion**: Zero dangling imports or references to `LiveSessionGrpcService` in any `.dart` source file. Thorough removal.
- **Correct deadlock avoidance**: `BreathModuleInstructionStream._canSendNow()` uses `isGrpcConnected` (transport readiness) rather than `isConnected` (bidi stream opened), exactly as the plan's Context section prescribed. This prevents the buffering deadlock where samples would never be sent because the lazy stream never opens.
- **Proto type safety verified**: All field mappings in `ModuleInstructionStream._toProto()` and the ack handler match the generated proto types. `Struct(fields:)` correctly accepts `Iterable<MapEntry<String, Value>>` (confirmed against `protobuf-6.0.0` source). `TelemetryAck.maxSamplesPerSecond` is `int` (proto `int32`), passed directly without unnecessary `.toInt()`.
- **Wiring chain is sound**: `App.dart` line 161 creates `instructionStream` → line 164 creates `BreathModuleInstructionStream(instructionStream:)` → `BreathModule.dart` line 43 passes `App.shared.breathInstructionStream` to `BreathModuleStateChannel`. No missing links.
- **Buffer flush timing is correct**: `readyEvents` (broadcast, non-sync) fires asynchronously after `_openStream()` completes, preventing re-entrancy during the `emit()` → `_openStream()` call chain while still flushing accumulated samples promptly.
- **ARCHITECTURE.md updated accurately**: Line 41 now lists `GrpcConnectionManager, ModuleStateChannel, ModuleInstructionStream` — matches the actual file contents of `lib/Core/Grpc/`.
