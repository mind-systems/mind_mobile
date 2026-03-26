# Plan: Delete BreathSessionApi.dart

## Context

Remove the dead REST-based `BreathSessionApi` class now that `BreathSessionGrpcApi` is fully wired in `App.dart`. The file is already disconnected from DI — nothing imports it at runtime.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Delete dead code

- [x] **Task 1: Delete `lib/Core/Api/BreathSessionApi.dart`**
  Files: `lib/Core/Api/BreathSessionApi.dart`
  Delete the file. It implements `IBreathSessionApi` via `HttpClient` (Dio REST calls) but is no longer instantiated anywhere — `App.dart` line 131 already constructs `BreathSessionGrpcApi(grpcClient.breathSessionService)` instead. No other file imports this class. The shared DTOs (`SaveBreathSessionRequest`, `StarSessionRequest`) remain in use by `BreathSessionGrpcApi`, `BreathSessionRepository`, and `IBreathSessionApi` — do not touch them.

### Phase 2: Verify no dangling references

- [x] **Task 2: Grep for residual references and clean up**
  Files: (any file matching, but expect none)
  Search the entire `mind_mobile/` tree for the string `BreathSessionApi` (excluding `.ai-factory/`, `.dart_tool/`, and generated proto files). If any import or reference to the deleted concrete class remains in production code, remove it. The interface `IBreathSessionApi` and the replacement `BreathSessionGrpcApi` must NOT be touched — only references to the old `BreathSessionApi` class name.

### Phase 3: Compile check

- [x] **Task 3: Run Flutter analyze to confirm clean build**
  Files: (none — command only)
  Run `/usr/local/bin/flutter analyze` from the `mind_mobile/` root. Verify zero errors. This confirms no file depended on the deleted class.
