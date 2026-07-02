# Root/child — copy `module_state.proto` + regenerate + `ActivityType.root`

**Date:** 2026-07-02
**Source:** conversation context; handoff `12-mobile-root-child-rollout.md`; `mind_api/proto/module_state.proto`

## Key Findings

- `mind_mobile/proto/module_state.proto` and the generated stubs under `lib/Core/Grpc/generated/module_state.*` are the **old** contract — verified: no `ROOT`, no `client_activity_id`, no `session_id` on end/stop/pause/resume, no `StateEvent.activity_type`.
- `mind_api/proto/module_state.proto` is the single source of truth and is LIVE/frozen (branch `feature/root-session`). Copy it verbatim, regenerate, do not hand-edit stubs.
- Foundation task — nothing else in Phase 61 compiles without the new wire types.

## Details

### Current state (exact)
- Old proto: `proto/module_state.proto` (`ActivityType {UNSPECIFIED, BREATH, MEDITATION}`, `StateEvent {module_session_id, status, is_paused}`, bare `ActivityEnd/Stop/Pause/ResumeCmd`).
- App-level enum `lib/Core/Grpc/ActivityType.dart` — two cases (`breath`, `meditation`); mapped to proto in `ModuleStateChannel.dart:213-219`.
- Generated stubs consumed at `ModuleStateChannel.dart` (client at `App.dart:221`).

### Change
```bash
cp /Users/max/projects/mind/mind_api/proto/module_state.proto \
   /Users/max/projects/mind/mind_mobile/proto/module_state.proto
cd /Users/max/projects/mind/mind_mobile && ./scripts/gen_proto.sh   # NOT build_runner (that is Drift)
```
New wire surface after regen:
- `ActivityType.ROOT = 3`.
- `ActivityStartCmd.client_activity_id = 5` (optional string).
- `ActivityEnd/Stop/Pause/ResumeCmd.session_id` (optional string).
- `StateEvent.activity_type = 4` (per-frame discriminator).

Add `root` to the app-level enum (`lib/Core/Grpc/ActivityType.dart:1` is `enum ActivityType { breath, meditation }` → add `root`). Extend the existing app→proto mapper `_mapActivityType` (`ModuleStateChannel.dart:213-220`, currently a 2-arm switch, no default) to add `case root: return proto.ActivityType.ROOT`. **Add a NEW reverse mapper** proto→app (does not exist today) so the registry (note 14) can tag each frame's `StateEvent.activity_type` — map `BREATH/MEDITATION/ROOT`, and treat `ACTIVITY_TYPE_UNSPECIFIED`/unknown as a logged drop (do not silently coerce to a real type).

### Guards
- Do not run `flutter pub run build_runner build` for proto — that is Drift codegen only (`CLAUDE.md`, handoff §9).
- Never symlink or hand-edit generated `*.pb*.dart` (proto single-source-of-truth rule).
- Wire name is `ref_id`, not `activity_ref_id`; `client_timestamp_ms` is field 4, field 3 is reserved.

### Verify
- `flutter analyze` clean after regen (existing `ModuleStateChannel` still compiles; new fields unused yet is fine).
- Generated `ActivityType` enum contains `ROOT`; `StateEvent` exposes `activityType`; command messages expose `sessionId` / `clientActivityId`.
