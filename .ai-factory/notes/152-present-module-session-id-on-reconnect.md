# Present `module-session-id` on reconnect (enable client-confirmed abandonment)

**Date:** 2026-06-23
**Source:** handoff 09 §10.1. Settled contract: `mind_api/.ai-factory/notes/62-reconnect-no-session-terminal-event.md` §"Transport of the client's session id".

## Key Findings

- `ModuleStateChannel._openSessionStream` (`lib/Core/Grpc/ModuleStateChannel.dart:71-105`) opens `trackActivity` with **no call metadata**, so the server cannot distinguish a reconnect-with-a-live-session from a fresh/idle connect.
- Per note 62, abandonment is **client-confirmed**: the client presents the `moduleSessionId` it believes is live as gRPC metadata `module-session-id` on the stream open; the server answers authoritatively — `RESUMED` (store hit, grace), one `sessionState{ABANDONED, moduleSessionId}` (DB row terminal), or silence (idle). The server reads this metadata in `handleReconnect(userId, clientSessionId)`.
- This is the **precondition for C** (`[[154-handle-abandonment-confirmation]]`): without the metadata the server stays silent on a dead session and the client never receives `ABANDONED`.

## Pinned types (from source)

- `ModuleState.moduleSessionId` is **`String?`** (`lib/Core/Grpc/ModuleState.dart:4`) — null when idle. A bare `.isNotEmpty` will not compile; null-check first.
- `ModuleStateStatus` is `{ idle, active }` (`ModuleState.dart:1`) → guard on `ModuleStateStatus.active`.
- `CallOptions` is from `package:grpc/grpc.dart` and is **not** currently imported in `ModuleStateChannel.dart` (`:1-13` import rxdart/fixnum/proto only) — add the import.
- The generated client accepts options: `ResponseStream<StateResponse> trackActivity(Stream<StateRequest> request, {CallOptions? options})` (`lib/Core/Grpc/generated/module_state.pbgrpc.dart:35-40`).

## Change

Add `import 'package:grpc/grpc.dart';` to `ModuleStateChannel.dart`. In `_openSessionStream` (`:71-105`), attach the metadata **only when the client currently believes it holds a live session**:

```dart
final liveId = currentState.moduleSessionId;
final options = (currentState.status == ModuleStateStatus.active &&
        liveId != null && liveId.isNotEmpty)
    ? CallOptions(metadata: {'module-session-id': liveId})
    : null;
final response = _moduleStateService.trackActivity(_sessionSink!.stream, options: options);
```

- `currentState` survives reconnect — `_closeSessionStream` does not reset `_state` — so on a reconnect-with-active-session it still holds the pre-disconnect `moduleSessionId`.
- On a genuinely fresh/idle open, pass `options: null` (no key) — the open behaves exactly as today.

## Guards

- Attach the key **only** when live (non-null, non-empty); never synthesize or send a placeholder id.
- No proto change — metadata is transport-level (note 62 pins metadata over a `ResumeCmd` proto message). If the server instead ships `ResumeCmd`, this becomes a first-message send on the sink — coordinate; pinned to metadata.
- Do not touch the `_backoffConfirmed` first-frame logic or the `onError`/`onDone` reconnect paths.

## Relationship to A/B/C

- B (`[[153-gate-biometrics-on-confirmed-session]]`) is the immediate flood fix and does not depend on this.
- This task is the precondition for C (`[[154-handle-abandonment-confirmation]]`) — ship A before C.
