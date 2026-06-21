# Plan: Send `client_timestamp_ms` on `ActivityStartCmd`/`ActivityEndCmd` so the server uses the client clock for `startedAt`/`endedAt`

## Context
Activity lifecycle `start`/`end` commands currently carry no client time, so the server stamps `startedAt`/`endedAt` on receipt (`now()`) — measured ~5 s late on session end, stretching the last breath phase on the web timeline. This milestone forwards the client wall-clock instant on both commands so the whole timeline stays on one clock.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Proto sync

- [x] **Task 1: Copy the updated proto and regenerate Dart stubs**
  Files: `proto/module_state.proto`, `lib/Core/Grpc/generated/module_state.pb.dart` (generated)
  The mind_api proto change has already landed (`mind_api/proto/module_state.proto` defines `optional int64 client_timestamp_ms = 4` on `ActivityStartCmd` and `optional int64 client_timestamp_ms = 1` on `ActivityEndCmd`). Copy `mind_api/proto/module_state.proto` → `mind_mobile/proto/module_state.proto` verbatim (copy only — never author, hand-edit, or symlink proto, per the proto-ownership rule). Then run `./scripts/gen_proto.sh` to regenerate the Dart stubs. After regen, `ActivityStartCmd`/`ActivityEndCmd` expose a `clientTimestampMs` field typed as `$fixnum.Int64`. Do not modify any other proto message.

### Phase 2: Channel API

- [x] **Task 2: Add optional `clientTimestampMs` to `ModuleStateChannel.start`/`end`** (depends on Task 1)
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  Add `import 'package:fixnum/fixnum.dart';`. Change the signatures to `start({required ActivityType type, String? refId, int? clientTimestampMs})` and `end({int? clientTimestampMs})`. The public params are plain Dart `int?` epoch millis; wrap with `Int64(clientTimestampMs)` when building the proto command — exactly as `lib/Core/Grpc/ModuleInstructionStream.dart:186` already does (`timestamp: Int64(sample.timestamp)`). When the param is non-null, set `clientTimestampMs: Int64(clientTimestampMs)` on `proto.ActivityStartCmd` / `proto.ActivityEndCmd`; when null, omit the field entirely (preserves today's behavior). Keep the existing pending-guard logic (`_isPendingStart`, idle checks) unchanged. Do not touch `pause`/`unpause`/`stop`.

### Phase 3: Callers

- [x] **Task 3: Pass client timestamps from `BreathModuleStateChannel`** (depends on Task 2)
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  At session start (the `if (!_started)` branch, ~line 81, immediately after `_originWallClock = DateTime.now()`): call `_channel.start(type: ActivityType.breath, refId: _sessionId, clientTimestampMs: _originWallClock!.millisecondsSinceEpoch)`. At session complete (~line 101): call `_channel.end(clientTimestampMs: _wireTimestamp(_stopwatch.elapsedMilliseconds))` so origin + elapsed yields the true completion instant on the same clock/origin as the phase `offsetMs` markers. Keep `_wireTimestamp` as the single source for the end instant — do not recompute `DateTime.now()` at end. Leave the existing diagnostic logs (`phase=… offset=…`, `session complete at offset=…`) exactly as they are. Do not touch the pause/resume markers (`_emitMarker`) or `stop()`.

- [x] **Task 4: Pass client timestamps from `MeditationModuleStateChannel`** (depends on Task 2)
  Files: `lib/MeditationModule/Core/MeditationModuleStateChannel.dart`
  This channel is lifecycle-only (no offset axis). At start (~line 39): `_channel.start(type: ActivityType.meditation, refId: _refId, clientTimestampMs: DateTime.now().millisecondsSinceEpoch)`. At end (~line 42): `_channel.end(clientTimestampMs: DateTime.now().millisecondsSinceEpoch)`. Using the same client clock for both start and end yields a correct `durationMs`. No origin/stopwatch is needed here. Keep the existing re-arm logic (`_started`/`_ended` reset) unchanged.
