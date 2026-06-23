# Plan: A — Present `module-session-id` metadata on reconnect

## Context
Make `ModuleStateChannel` attach the live `moduleSessionId` as gRPC `module-session-id` call metadata when opening `trackActivity`, so the server can distinguish a reconnect-with-a-live-session from a fresh/idle connect and confirm abandonment. This is the precondition for milestone C (`154-handle-abandonment-confirmation`).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Attach session metadata on stream open

- [x] **Task 1: Import `CallOptions`**
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  Add `import 'package:grpc/grpc.dart';` to the import block (currently rxdart/fixnum/proto only, `:1-13`). Required for `CallOptions`, which is not yet imported.

- [x] **Task 2: Pass `module-session-id` metadata when a live session is held** (depends on Task 1)
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  In `_openSessionStream` (`:71-105`), build call options only when the client currently believes it holds a live session, then pass them to `trackActivity`. Replace the bare `trackActivity` call (`:74`) with:
  ```dart
  final liveId = currentState.moduleSessionId;
  final options = (currentState.status == ModuleStateStatus.active &&
          liveId != null && liveId.isNotEmpty)
      ? CallOptions(metadata: {'module-session-id': liveId})
      : null;
  final response = _moduleStateService.trackActivity(_sessionSink!.stream, options: options);
  ```
  - `moduleSessionId` is `String?` (`lib/Core/Grpc/ModuleState.dart:4`) — null-check before `isNotEmpty` or it will not compile.
  - Guard on `ModuleStateStatus.active`; `currentState` survives reconnect (`_closeSessionStream` does not reset `_state`), so on reconnect-with-active-session it still holds the pre-disconnect `moduleSessionId`.
  - On a fresh/idle open, `options` is `null` — the open behaves exactly as today.
  - The generated client accepts `{CallOptions? options}` (`lib/Core/Grpc/generated/module_state.pbgrpc.dart:35-40`).

## Guards
- Attach the key **only** when live (non-null, non-empty); never synthesize or send a placeholder id.
- No proto change — metadata is transport-level, not a `ResumeCmd` message.
- Do not touch the `_backoffConfirmed` first-frame logic or the `onError`/`onDone` reconnect paths.
