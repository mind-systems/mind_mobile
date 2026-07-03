# Plan: Command addressing: `client_activity_id` on start + `session_id` on end/stop/pause/resume

## Context
Thread a stable per-start `client_activity_id` (start idempotency) and the addressed child's `session_id` (child targeting under concurrency) through the `ModuleStateChannel` command builders and both module adapters, so concurrent children can be started idempotently and ended/paused/resumed/stopped without hitting `AMBIGUOUS_SESSION`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Channel command builders

- [x] **Task 1: Add `clientActivityId` + `sessionId` params to `ModuleStateChannel` command builders**
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  Extend the public command methods so callers can address a specific child and carry a start idempotency token. The generated proto already has `ActivityStartCmd.clientActivityId` (field 5) and `sessionId` on `ActivityEndCmd`/`ActivityStopCmd`/`ActivityPauseCmd`/`ActivityResumeCmd` — pass the params straight into the proto constructors (they set the optional field only when non-null, same pattern as the existing `refId: refId`):
  - `start({required ActivityType type, String? refId, int? clientTimestampMs, String? clientActivityId})` (`:236`) → set `clientActivityId: clientActivityId` on `ActivityStartCmd`.
  - `startRoot({String? clientActivityId})` (`:253`) → set `clientActivityId: clientActivityId` on the ROOT `ActivityStartCmd`.
  - `pause({String? sessionId})` (`:259`) → `ActivityPauseCmd(sessionId: sessionId)`.
  - `unpause({String? sessionId})` (`:265`) → `ActivityResumeCmd(sessionId: sessionId)`.
  - `end({int? clientTimestampMs, String? sessionId})` (`:271`) → set `sessionId: sessionId` on `ActivityEndCmd`.
  - `stop({String? sessionId})` (`:280`) → `ActivityStopCmd(sessionId: sessionId)`.
  Keep all existing guards (`_isPendingStart`/`_isPendingPause`/idle checks) and behavior unchanged; only the outgoing command fields change. The channel does NOT resolve the child id itself — callers pass it.

### Phase 2: Adapter threading

- [x] **Task 2: Thread `client_activity_id` + `session_id` through `BreathModuleStateChannel`** (depends on Task 1)
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  Add `import 'package:uuid/uuid.dart';` and a `String? _clientActivityId` field.
  - In `_handleLifecycle` first-start branch (`:85-93`, `wasInactive && isRunning && !_started`) generate the token once for this logical start: `_clientActivityId = const Uuid().v4();` and pass it on `_channel.start(type: ActivityType.breath, refId: _sessionId, clientTimestampMs: ..., clientActivityId: _clientActivityId)`. Never regenerate it on the resume/`unpause` path (`:95-96`) — reuse defeated means a duplicate child.
  - Resolve the addressed child id from the registry at each command site — add a private getter `String? get _childSessionId => _channel.childOfType(ActivityType.breath)?.id;` — and pass it as `sessionId`:
    - resume: `_channel.unpause(sessionId: _childSessionId)` (`:96`)
    - pause: `_channel.pause(sessionId: _childSessionId)` (`:104`)
    - end: `_channel.end(clientTimestampMs: ..., sessionId: _childSessionId)` (`:110`)
    - dispose stop: `_channel.stop(sessionId: _childSessionId)` (`:160`)
  - `childOfType` never returns the root and returns `null` when no live breath child exists, satisfying "omit → sole-child" and "never target the root id"; a `null` id is passed straight through (Task 1 omits the field).
  - Clear `_clientActivityId = null;` in `reset()` (`:144-155`) so the next logical start mints a fresh token.

- [x] **Task 3: Thread `client_activity_id` + `session_id` through `MeditationModuleStateChannel`** (depends on Task 1)
  Files: `lib/MeditationModule/Core/MeditationModuleStateChannel.dart`
  Add `import 'package:uuid/uuid.dart';` and a `String? _clientActivityId` field.
  - In `_onState` start branch (`:48-50`, `status == active && !_started`) mint the token for this logical start: `_clientActivityId = const Uuid().v4();` and pass it on `_channel.start(type: ActivityType.meditation, refId: _refId, clientTimestampMs: ..., clientActivityId: _clientActivityId)`.
  - Add `String? get _childSessionId => _channel.childOfType(ActivityType.meditation)?.id;` and pass it as `sessionId` on end (`:52`, `_channel.end(clientTimestampMs: ..., sessionId: _childSessionId)`) and on the dispose stop (`:62`, `_channel.stop(sessionId: _childSessionId)`).
  - The idle re-arm branch already resets `_started`/`_ended`; clear `_clientActivityId = null;` there too, and in the `ModuleSessionAbandoned` handler (`:33-38`), so each new Start→Stop cycle gets a fresh token.
  - `import 'package:mind/Core/Grpc/ActivityType.dart';` is already present.

- [x] **Task 4: Pass a stable per-user `client_activity_id` on `RootStateChannel.startRoot`** (depends on Task 1)
  Files: `lib/Core/Grpc/RootStateChannel.dart`
  Add `import 'package:uuid/uuid.dart';` and a `final String _clientActivityId = const Uuid().v4();` field generated once at construction. Pass it on every `_channel.startRoot(clientActivityId: _clientActivityId)` call (`:21`). The root is re-sent on every reconnect (`sessionStreamOpened`) — the token stays constant across reconnects so the server dedups to the same `root.id`. The root keeps no end/stop/pause/resume path.
