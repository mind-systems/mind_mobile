# Code Review — Extract `GrpcConnectionManager` from `LiveSessionGrpcService`

**Plan:** `39-extract-grpcconnectionmanager-from-livesessiongrpcservice.md`
**Files Reviewed:** 4 (1 new class, 1 new enum, 1 modified, 1 deleted)
**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md** — WARN: `GrpcConnectionManager` sits in `lib/Core/Grpc/`, consistent with the Architecture's Core infrastructure layer for gRPC classes. No boundary violations.
- **RULES.md** — WARN: "All dependencies must be injected via constructor" — `GrpcConnectionManager` receives `authStream`, `connectivityStream`, `resumeStream` via constructor. Compliant. The current version (evolved in commit 40) is a pure state machine with no callbacks; consumers receive the manager via their own constructors.
- **ROADMAP.md** — Phase 7.1 is marked `[x]` complete. Linked correctly.

### Critical Issues

None.

### Suggestions

None.

### Positive Notes

- **Clean separation of concerns.** The manager owns exactly connection lifecycle (connect / disconnect / backoff / auth+connectivity+resume listeners) and nothing else. Consumers subscribe to `connectionState` and manage their own stream handles independently.
- **Correct `late final` initialization timing.** The `GrpcConnectionManager` constructor subscribes to `authStream` (a `BehaviorSubject`), which fires synchronously during `listen()`. In the original commit this triggered `async connect()` which yields at `await`, so the assignment completes before the callback's future resumes. In the current evolved version, `connect()` is synchronous — consumers react to `connected` state synchronously during the same event loop turn, but gRPC stream setup doesn't throw synchronously, so `onError`/`onDone` closures that reference `_connectionManager` only fire later, after the field is assigned.
- **`SocketConnectionState` fully removed.** Zero references remain in `lib/` — confirmed via grep.
- **Correct backoff semantics.** `confirmConnected()` resets the backoff counter; `scheduleReconnect()` is public so transport-level stream errors can trigger reconnection without the consumer needing backoff internals. Double-fire from concurrent stream errors (both ModuleStateChannel and ModuleInstructionStream calling `disconnect()` + `scheduleReconnect()`) is harmless — second `disconnect()` is a no-op for already-closed handles, second `scheduleReconnect()` replaces the timer.
- **No unused imports.** `connectivity_plus` and `AuthState` remain needed in consumer files for constructor parameter types. `rxdart` is correctly scoped to `GrpcConnectionManager.dart` only.
- **Consumer wiring in `App.dart` is clean.** `GrpcConnectionManager` is created first, then passed to `ModuleStateChannel` and `ModuleInstructionStream` — correct initialization order.

REVIEW_PASS
