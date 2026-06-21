# Send client start/end timestamps on activity lifecycle commands

**Date:** 2026-06-21
**Source:** conversation context (cross-project breath-timeline diagnosis)

## Key Findings

- **Measured bug.** Breath session `b3d36c59-…`: the client finished and called `end` at 11:02:13Z, but the server stamped `endedAt` at 11:02:18Z (`durationMs=138504`) — ~5 s late. The web bounds the last phase bar by `endedAt`, so the final exhale rendered as ~7 s vs the nominal 3 s; client-stamped biometrics stopped at the true end and looked cut off. Tick source here was the **clock**, so this is not a client stall — the lifecycle `end` is server-clocked.
- **Why.** `BreathModuleStateChannel` already stamps phase markers and (via the biometric pipeline) samples on the client wall clock: `_wireTimestamp(offsetMs) = _originWallClock + offsetMs`. But `ModuleStateChannel.start({type, refId})` and `end()` send `ActivityStartCmd`/`ActivityEndCmd` with **no** client time, so the server falls back to its receipt `now()`. This task sends the client timestamps so the whole timeline is on one clock.
- **Depends on the mind_api task** (`.ai-factory/notes/57-client-sourced-activity-timestamps.md` over there): the proto fields `client_timestamp_ms` on `ActivityStartCmd`/`ActivityEndCmd` must exist server-side first. Proto is owned by `mind_api` — copy, don't author.

## Details

### Proto sync (per `CLAUDE.md` proto ownership)

- After mind_api lands its proto change, copy `mind_api/proto/module_state.proto` → `mind_mobile/proto/module_state.proto` (copy, never symlink) and run `./scripts/gen_proto.sh` to regenerate Dart stubs. The int64 field surfaces as `Int64` (package `fixnum`) in the generated `ActivityStartCmd`/`ActivityEndCmd`.

### `lib/Core/Grpc/ModuleStateChannel.dart`

- Public params are Dart `int?` (epoch millis). The generated proto field is `$fixnum.Int64`, so wrap with `Int64(clientTimestampMs)` — `import 'package:fixnum/fixnum.dart';` — exactly as `ModuleInstructionStream.dart:186` already does (`timestamp: Int64(sample.timestamp)`). Do not invent another encoding.
- `start({required ActivityType type, String? refId, int? clientTimestampMs})`: when non-null, `proto.ActivityStartCmd(activityType: …, refId: …, clientTimestampMs: Int64(clientTimestampMs))`.
- `end({int? clientTimestampMs})`: when non-null, `proto.ActivityEndCmd(clientTimestampMs: Int64(clientTimestampMs))`.
- Params are optional only to keep `null` safe at call sites — both real callers (breath, meditation) **always** pass a value (below). When `null`, omit the field (today's behavior).

### `lib/BreathModule/Core/BreathModuleStateChannel.dart` (the bug site)

- On start (line ~81): `_channel.start(type: ActivityType.breath, refId: _sessionId, clientTimestampMs: _originWallClock!.millisecondsSinceEpoch)` — `_originWallClock` is set immediately before this call.
- On end (line ~101): `_channel.end(clientTimestampMs: _wireTimestamp(_stopwatch.elapsedMilliseconds))` — origin + elapsed = the true client completion instant, same clock and origin as the phase `offsetMs` markers.

### `lib/MeditationModule/Core/MeditationModuleStateChannel.dart` (must compile with the new signature)

- Lifecycle-only, no offset axis. Pass `DateTime.now().millisecondsSinceEpoch` at both start (line ~39) and end (line ~42). Same client clock for start+end → correct `durationMs`. (No origin/stopwatch needed here.)

### Guards

- Do not author or hand-edit proto — copy from `mind_api` and regenerate (`scripts/gen_proto.sh`).
- Land after the mind_api proto change exists; until then the field is absent and the server uses `now()` (today's behavior).
- Breath: only send when `_originWallClock`/`_stopwatch` are valid (they are inside the `_started` lifecycle branches). Keep `_wireTimestamp` as the single source for the end instant — don't recompute `DateTime.now()` at end (that would diverge from the `offsetMs` axis).
- Don't touch pause/resume (already on the client offset axis via the instruction stream) or `stop()`.

### Verification

1. Reproduce a breath session; in logs `session complete at offset=X` (client) should now match the server `Session ended … durationMs` (≈ X), not exceed it by several seconds.
2. Web: the last phase bar renders at its nominal length; biometrics no longer appear cut off before the bars end.
3. Old behavior when run against a server without the proto field (graceful: server ignores absent field / falls back to `now()`).

### Out of scope (do not touch)

- The diagnostic logs already in `BreathModuleStateChannel` (`phase=… offset=…`, `session complete at offset=…`) — leave them exactly as they are. This task neither adds nor removes them.
- Pause/resume (`_emitMarker`) and `stop()` — unchanged.

## Decisions (settled — do not re-open)

- **Both start and end are sent**, always, by both callers. This is not optional and not "end-only" — start alignment removes the residual start-skew and keeps the whole timeline on one client clock. An implementer must wire both.
- Encoding is `Int64(...)` from `package:fixnum` (above) — no alternative.
