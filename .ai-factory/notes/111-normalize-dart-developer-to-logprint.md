# Normalize the 16 dart:developer call sites to logPrint

**Date:** 2026-06-18
**Source:** conversation context

## Key Findings

- The note's premise of "a single swap point" is false: alongside `logPrint` (57 sites) there is a **second** logging path — `log(...)` imported directly from `dart:developer` in **16 files**, used for network / gRPC / sync / lifecycle / auth error logging. These bypass `lib/Logger.dart` entirely.
- `dart:developer.log` output **cannot be intercepted externally** — it goes straight to the VM service, not through `print`/`Zone`. The only way to route these logs into the observer is to change the calls themselves. This one-time normalization to a single `logPrint` pattern is exactly the "свести к одному паттерну" the user asked for — not the forbidden structural coupling.
- These are the highest-value logs for cross-service correlation (Phase 36): the gRPC error log is the anchor that will share a `trace_id` with mind_api.

## Details

### Current state — files importing `dart:developer`
**In scope (15 files):** `lib/Biometrics/BiometricStreamClient.dart`, `lib/Core/Grpc/GrpcLoggingInterceptor.dart`, `lib/Core/Grpc/ModuleInstructionStream.dart`, `lib/Core/Grpc/GrpcClient.dart`, `lib/Core/Grpc/GrpcConnectionManager.dart`, `lib/Core/Grpc/ModuleStateChannel.dart`, `lib/Core/AppLifecycleService.dart`, `lib/Core/Sync/SyncEngine.dart`, `lib/Core/Sync/SyncGrpcListener.dart`, `lib/User/UserNotifier.dart`, `lib/User/Infrastructure/GoogleAuthProvider.dart`, `lib/User/UserRepository.dart`, `lib/McpModule/Core/TokenNotifier.dart`, `lib/McpModule/Presentation/McpScreen/McpViewModel.dart`, `lib/BreathModule/Core/BreathModuleStateChannel.dart`.

**Out of scope (leave untouched):** `lib/Core/Api/HttpClient.dart` — dead code (the `HttpClient` class is never instantiated and `package:dio` is used nowhere else). It bothers no one; leave its `dart:developer` import and `log(...)` calls as-is.

Typical call: `log('${method.path} ERROR: $e', name: 'gRPC', error: e);` — carries `name:`, `error:`, sometimes `level:` (e.g. `ModuleStateChannel` uses `level: 900`).

### The change (mechanical, per file)
- Replace `import 'dart:developer';` with `import 'package:mind/Logger.dart';`.
- Rewrite each `log(msg, name: 'X', error: e, level: n)` → `logPrint('[X] $msg: $e')`:
  - `name:` → a `[X]` bracket tag prepended to the message.
  - `error:` / stack → appended to the string (`: $e`). **Never silently drop the error** — fold it into the text.
  - `level:` → dropped (level is not significant; all logs are `info`).
- Where a call already has no `name`/`error`, it becomes a plain `logPrint('...')`.

### Guards
- **Leave `lib/Core/Api/HttpClient.dart` untouched** — dead code, out of scope, bothers no one. Its `dart:developer` import stays.
- One mechanical concern only — do not change log *messages*' meaning, add new logs, or remove existing ones. Same lines, new transport.
- After this, the only live logging primitive in the codebase is `logPrint` (the lone remaining `dart:developer` import sits in dead `HttpClient.dart`).

### Verify
- Grep confirms the only remaining `import 'dart:developer'` in `lib/` is in the dead `HttpClient.dart`.
- With `LOG_DESTINATION=both`, force a gRPC/sync error; the existing error line appears in Loki via `observe-logs window --project mind --service mind_mobile`.

## Open Questions

None.
