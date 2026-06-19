# Switch session edit from ReplaceSession (PUT) to UpdateSession (PATCH)

**Date:** 2026-06-19
**Source:** conversation context — `timeOfDay` data-loss on edit

## Key Findings

- `BreathSessionApi.update()` (`lib/BreathModule/Core/BreathSessionApi.dart:30`) edits via `_service.replaceSession(ReplaceSessionRequest(id, description, exercises, shared))` — PUT semantics. It never sends `time_of_day`, and the server's PUT path resets that server-managed field to `null` on every edit. `time_of_day` is never set by this app, yet the edit silently wipes it.
- The fix is to stop using PUT: `UpdateSession` (PATCH) updates only the fields present and preserves the rest, so omitting `time_of_day` leaves it intact. The `breath_sessions.proto` contract no longer contains `ReplaceSession`, so after regenerating the stubs `replaceSession`/`ReplaceSessionRequest` no longer exist and this call site must move to `updateSession`.
- `UpdateSessionRequest.exercises` is the `ExerciseList` wrapper (proto3 presence-tracked), not a bare `repeated` — the edit must wrap the mapped exercises in `ExerciseList(...)`. Sending the full list still replaces the whole exercise array (edit semantics preserved).

## Details

### The change
1. Sync `proto/breath_sessions.proto` to the current contract and regenerate the gRPC stubs per the proto-sync workflow in `CLAUDE.md` (`./scripts/gen_proto.sh`) — `replaceSession`/`ReplaceSessionRequest` disappear, `updateSession`/`UpdateSessionRequest` remain.
2. `lib/BreathModule/Core/BreathSessionApi.dart` `update()` (line ~30) — replace the `replaceSession(ReplaceSessionRequest(...))` call with:
   ```dart
   final response = await _service.updateSession(proto.UpdateSessionRequest(
     id: id,
     description: request.description,
     exercises: proto.ExerciseList(exercises: _mapExercisesToProto(request.exercises)),
     shared: request.shared,
   ));
   ```
   Keep `_mapSession(response)` and `_mapExercisesToProto` unchanged. `time_of_day` is intentionally not set → the server preserves it.

### Guards (do NOT touch)
- `create()` (still `createSession`), `delete()`, `fetchById`, `fetchPage`, `starSession` — unchanged.
- Keep `_mapExercisesToProto`; the edit must send the FULL exercise list (PATCH-with-full-array = replace exercises, the intended edit behavior).
- Do not add any `time_of_day` field to the edit request — omitting it is the whole point.

### Verify
- `flutter analyze` clean; `grep -rn "replaceSession\|ReplaceSessionRequest" lib` (excluding generated) returns nothing.
- Edit a session that already has a `timeOfDay`: after save, re-fetch shows `timeOfDay` unchanged.
- Editing exercises (add/remove a step) still persists the new exercise list.

## Open Questions

- None.
