# Plan: Edit via `UpdateSession` (PATCH), preserving `timeOfDay`

## Context
Session editing currently uses `ReplaceSession` (PUT semantics), which wipes the server-managed `time_of_day` field on every edit. Switch the edit path to `UpdateSession` (PATCH), which updates only the fields present and preserves `time_of_day` when omitted.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Proto sync

- [x] **Task 1: Sync `breath_sessions.proto` from the API contract**
  Files: `proto/breath_sessions.proto`
  Copy the current contract from `mind_api/proto/breath_sessions.proto` over `mind_mobile/proto/breath_sessions.proto` (per the proto-sync workflow in root `CLAUDE.md` — copy explicitly, never symlink). The only difference is the removal of `message ReplaceSessionRequest` and the `rpc ReplaceSession(...)` line; `UpdateSessionRequest` (with the presence-tracked `optional ExerciseList exercises`) and `rpc UpdateSession(...)` remain. After this task the mobile proto must contain no `ReplaceSession` references.

- [x] **Task 2: Regenerate gRPC Dart stubs** (depends on Task 1)
  Files: `lib/Core/Grpc/generated/breath_sessions.pb.dart`, `lib/Core/Grpc/generated/breath_sessions.pbgrpc.dart`, `lib/Core/Grpc/generated/breath_sessions.pbjson.dart`
  Run `./scripts/gen_proto.sh` to regenerate all stubs. This removes `ReplaceSessionRequest` / `replaceSession` from the generated files and keeps `UpdateSessionRequest` / `updateSession` and the `ExerciseList` wrapper. Do not hand-edit generated files — they are produced by the script. Prerequisites (`protoc`, `protoc-gen-dart`) are documented in the script header.

### Phase 2: Switch the edit call site

- [x] **Task 3: Move `update()` from `replaceSession` to `updateSession`** (depends on Task 2)
  Files: `lib/BreathModule/Core/BreathSessionApi.dart`
  In `BreathSessionApi.update()` (line ~30) replace the `replaceSession(ReplaceSessionRequest(...))` call with:
  ```dart
  final response = await _service.updateSession(proto.UpdateSessionRequest(
    id: id,
    description: request.description,
    exercises: proto.ExerciseList(exercises: _mapExercisesToProto(request.exercises)),
    shared: request.shared,
  ));
  return _mapSession(response);
  ```
  Notes and guards:
  - `exercises` must be wrapped in the presence-tracked `ExerciseList`; send the FULL mapped exercise list (PATCH-with-full-array = replace the whole exercise array — the intended edit behavior).
  - Do NOT set `time_of_day` on the request — omitting it is the entire point; the server preserves the existing value.
  - Keep `_mapExercisesToProto` and `_mapSession(response)` unchanged.
  - Leave `create()` (`createSession`), `delete()`, `fetchById`, `fetchPage`, and `starSession` untouched.

- [x] **Task 4: Verify the change** (depends on Task 3)
  Files: (verification only)
  - Run `flutter analyze` — must be clean.
  - Confirm no `replaceSession` / `ReplaceSessionRequest` references remain outside `lib/Core/Grpc/generated/` (expectation: none anywhere after regen). Grep `lib/` excluding the generated folder.
  - Functional check: editing a session that already has a `timeOfDay` leaves it unchanged after save/re-fetch; editing exercises (add/remove a step) still persists the new exercise list.
