# Plan: Normalize the `dart:developer` call sites to `logPrint`

## Context
Collapse the second, un-interceptable logging path (`log(...)` from `dart:developer`) into the single `logPrint` primitive across 15 files, so every live log line in `lib/` routes through `lib/Logger.dart` (and thus the observer / Loki).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Conventions (apply to every task)
Each file is a purely mechanical transport swap — **do not add, remove, reword, or change the meaning of any log message**.

1. **Import swap.** Replace `import 'dart:developer';` (or `import 'dart:developer' as dev;`) with `import 'package:mind/Logger.dart';`. If `package:mind/Logger.dart` is already imported in the file, do not add a duplicate — just remove the `dart:developer` import. For the aliased case, also rewrite each `dev.log(...)` call to `logPrint(...)`.
2. **Call rewrite.** `log(msg, name: 'X', error: e, level: n)` → `logPrint('<message>')` where:
   - `name: 'X'` → `[X]` bracket tag prepended to the message — **unless the message already starts with that same `[X]` tag**, in which case do NOT double-bracket; just drop `name:` and keep the message as-is. (Most call sites already carry the `[Tag]` prefix.)
   - `error:` / stack → folded into the string as `: $e`. **Never silently drop the error.** If the message already interpolates `$e`, the error is already present — just drop the redundant `error:` argument (do not append `$e` twice).
   - `level:` → dropped.
   - A call with no `name`/`error` becomes a plain `logPrint('<message>')`.
3. **Multi-line calls.** Collapse the multi-arg multi-line `log(\n  '...',\n  name: '...',\n)` form into a single `logPrint('...')` call.
4. **Out of scope — do NOT touch:** `lib/Core/Api/HttpClient.dart` (dead code; its `dart:developer` import and `log(...)` calls stay).

## Tasks

### Phase 1: gRPC transport

- [x] **Task 1: Normalize gRPC client/connection/error logging**
  Files: `lib/Core/Grpc/GrpcLoggingInterceptor.dart`, `lib/Core/Grpc/GrpcClient.dart`, `lib/Core/Grpc/GrpcConnectionManager.dart`
  Apply the Conventions to all `log(...)` sites. Notes:
  - `GrpcLoggingInterceptor` (lines ~16, ~30): `log('${method.path} ERROR: $e', name: 'gRPC', error: e)` → `logPrint('[gRPC] ${method.path} ERROR: $e')` (message has no existing tag, so prepend `[gRPC]`; `$e` already present, drop `error: e`).
  - `GrpcConnectionManager` (lines ~63–141): messages already carry `[GrpcConnectionManager]` → drop `name:`, collapse the multi-line calls at ~82 and ~138.
  - `GrpcClient` (line ~29): drop `name:`, keep existing `[GrpcClient]` tag.

- [x] **Task 2: Normalize gRPC stream channels**
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`, `lib/Core/Grpc/ModuleInstructionStream.dart`
  Apply the Conventions. Notes:
  - `ModuleStateChannel` line ~145 carries `level: 900` → drop the `level:`. Messages already tagged `[ModuleStateChannel]` → drop `name:`. Collapse multi-line call at ~86.
  - `ModuleInstructionStream` (lines ~72, ~115, ~124, ~133): already tagged → drop `name:`, collapse multi-line calls.

### Phase 2: Biometrics & sync

- [x] **Task 3: Normalize biometric stream client**
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  Apply the Conventions to the five multi-line `log(...)` calls (lines ~108, ~117, ~124, ~132, ~179). Messages already tagged `[BiometricStreamClient]` → drop `name:`, collapse to single-line `logPrint`.

- [x] **Task 4: Normalize sync engine and listener**
  Files: `lib/Core/Sync/SyncEngine.dart`, `lib/Core/Sync/SyncGrpcListener.dart`
  Apply the Conventions. All messages already carry their `[SyncEngine]` / `[SyncGrpcListener]` tag → drop `name:`, keep messages verbatim (including the ⚠️ markers).

### Phase 3: Lifecycle, auth & MCP

- [x] **Task 5: Normalize app lifecycle service**
  Files: `lib/Core/AppLifecycleService.dart`
  Apply the Conventions (lines ~20, ~25, ~30). Already tagged `[AppLifecycleService]` → drop `name:`.

- [x] **Task 6: Normalize user/auth logging**
  Files: `lib/User/UserNotifier.dart`, `lib/User/UserRepository.dart`, `lib/User/Infrastructure/GoogleAuthProvider.dart`
  Apply the Conventions. These calls already carry their `[Tag]` and have no `name:`/`error:` (errors are interpolated inline as `$e`) → the change is just the import swap; calls become plain `logPrint('...')` with identical message text.

- [x] **Task 7: Normalize MCP token logging**
  Files: `lib/McpModule/Core/TokenNotifier.dart`, `lib/McpModule/Presentation/McpScreen/McpViewModel.dart`
  Apply the Conventions. Messages already tagged → drop `name:`.

- [x] **Task 8: Normalize breath module state channel (aliased import)**
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  Replace `import 'dart:developer' as dev;` with `import 'package:mind/Logger.dart';`. Rewrite each `dev.log('BreathModuleStateChannel: ...', name: 'BreathModuleState')` → `logPrint('[BreathModuleState] BreathModuleStateChannel: ...')` (message has no `[BreathModuleState]` tag yet, so prepend it per the Conventions). Lines ~65, ~71, ~76, ~81, ~125.

### Phase 4: Verify

- [x] **Task 9: Confirm no stray `dart:developer` remains in scope** (depends on Tasks 1-8)
  Files: (verification only)
  Grep `lib/` for `import 'dart:developer'`; the only remaining match must be the dead `lib/Core/Api/HttpClient.dart`. Grep for `dev.log(` / bare `log(` in the 15 touched files to confirm none remain. Run `flutter analyze` to confirm no unused-import or missing-symbol errors were introduced.

## Commit Plan
- **Commit 1** (after tasks 1-2): "Route gRPC logging through logPrint"
- **Commit 2** (after tasks 3-4): "Route biometric and sync logging through logPrint"
- **Commit 3** (after tasks 5-8): "Route lifecycle, auth, MCP and breath logging through logPrint"
- **Commit 4** (after task 9): "Verify dart:developer normalization"
