# Code Review: 58 — Copy all proto files and regenerate

## Changes reviewed

| File | Change |
|------|--------|
| `proto/module_state.proto` | Removed `PresenceState` enum, `PresenceCmd` message, `presence` field 6 from `SessionRequest` oneof |
| `proto/sync.proto` | Comment update: `live.proto / telemetry.proto` → `module_session.proto / module_stream.proto` |
| `lib/Core/Grpc/generated/module_state.pb.dart` | Regenerated — `PresenceCmd` class removed, `SessionRequest` oneof trimmed to 5 commands |
| `lib/Core/Grpc/generated/module_state.pbenum.dart` | Regenerated — `PresenceState` enum class removed |
| `lib/Core/Grpc/generated/module_state.pbjson.dart` | Regenerated — JSON descriptors for `PresenceState`, `PresenceCmd`, and `presence` field removed |
| `lib/Core/Grpc/generated/sync.pb.dart` | Regenerated — comment update only |
| `.ai-factory/plans/57-*.md`, `58-*.md`, plan review | New planning files |

## Verification

### Proto source of truth alignment

Confirmed `mind_mobile/proto/module_state.proto` now matches `mind_api/proto/module_state.proto` exactly. The `PresenceState` enum (3 values), `PresenceCmd` message, and `SessionRequest.presence` field 6 are gone. The `sync.proto` comment now matches the API version.

### Generated stubs correctness

- **`module_state.pb.dart`**: `PresenceCmd` class fully removed. `SessionRequest` factory, `BuilderInfo`, and accessor methods now reference only fields 1–5 (`activityStart` through `activityResume`). The `..oo(0, [1, 2, 3, 4, 5])` oneof group is correct (was `[1, 2, 3, 4, 5, 6]`). The `SessionRequest_Command` enum has 5 values + `notSet` — correct.
- **`module_state.pbenum.dart`**: Only `ActivityType` and `SessionStatus` enums remain. `PresenceState` fully removed.
- **`module_state.pbjson.dart`**: JSON descriptors for `PresenceState$json`, `presenceStateDescriptor`, `PresenceCmd$json`, `presenceCmdDescriptor` all removed. The `SessionRequest$json` no longer includes the `presence` field entry. The base64 descriptor for `SessionRequest` is updated (shorter, no `presence` reference).

### Consumer code impact

Searched all hand-written Dart files under `lib/` for `PresenceCmd` and `PresenceState` — zero references found. The only consumer of `module_state.pbgrpc.dart` types is `ModuleStateChannel.dart`, which uses:
- `proto.SessionRequest`, `proto.SessionResponse`, `proto.SessionStateEvent` — still present
- `proto.ActivityStartCmd`, `proto.ActivityEndCmd`, `proto.ActivityStopCmd`, `proto.ActivityPauseCmd`, `proto.ActivityResumeCmd` — still present
- `proto.SessionStatus` (`.ACTIVE`, `.RESUMED`, `.DISCONNECTED`, `.COMPLETED`, `.INTERRUPTED`, `.ABANDONED`, `.SESSION_STATUS_UNSPECIFIED`) — still present
- `proto.ActivityType.BREATH` — still present
- `proto.SessionResponse_Event` (`.sessionState`, `.sessionError`, `.notSet`) — still present

No code changes needed. No runtime breakage.

### Wire compatibility

The removed `PresenceCmd`/`PresenceState` types were never sent by the mobile client (confirmed by reading `ModuleStateChannel.dart` — no `presence` field usage). The API server never expected or sent these types either (they don't exist in the API proto). Removing them from the mobile stubs has zero wire-protocol impact.

## Issues

None.

REVIEW_PASS
