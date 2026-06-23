# Code Review: A — Present `module-session-id` metadata on reconnect

**Scope:** `lib/Core/Grpc/ModuleStateChannel.dart` (only code change in the diff; the other staged files are plan/plan-review artifacts).

## What changed
- Added `import 'package:grpc/grpc.dart';` for `CallOptions`.
- In `_openSessionStream`, builds `CallOptions(metadata: {'module-session-id': liveId})` only when `currentState` holds a live session (`status == active`, `moduleSessionId` non-null and non-empty), otherwise `null`, and passes it to `trackActivity(..., options: options)`.

## Verification performed
- **Import / dependency**: `grpc: ^5.1.0` is a direct dependency in `pubspec.yaml`, so the explicit `package:grpc/grpc.dart` import resolves. The generated stub imports `package:grpc/service_api.dart as $grpc`; `CallOptions` from `grpc.dart` is the same class re-exported from that path, so there is no type mismatch when passing `options` to the generated method.
- **Method signature**: `module_state.pbgrpc.dart` declares `trackActivity(Stream<StateRequest> request, {CallOptions? options})` — the named `options` argument is correct.
- **Null safety**: `ModuleState.moduleSessionId` is `String?`. The guard null-checks before `.isNotEmpty`, so it compiles and cannot NPE. Inside the truthy branch `liveId` is promoted to non-null `String`, making the metadata map `Map<String, String>` as `CallOptions.metadata` requires.
- **Reconnect behavior**: `_closeSessionStream` does not reset `_state`, so on a reconnect-with-active-session `currentState` still carries the pre-disconnect `moduleSessionId` — the metadata is attached as intended. On a fresh/idle open `currentState` is `initial()` (idle, null id) → `options == null` → identical to prior behavior.
- **Guards respected**: `_backoffConfirmed` first-frame logic and the `onError`/`onDone` reconnect paths are untouched. No id is synthesized; the key is attached only when a live id exists.
- **Metadata validity**: key `module-session-id` is lowercase ASCII (valid gRPC header key); value is an existing server-issued session id (ASCII-safe).

## Findings
None. The change is minimal, matches the spec note (`152-present-module-session-id-on-reconnect.md`), compiles cleanly under null safety, and preserves existing idle/fresh-connect behavior.

REVIEW_PASS
