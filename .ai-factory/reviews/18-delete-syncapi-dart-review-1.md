# Review: 18-delete-syncapi-dart

## Changed files

| File | Change |
|------|--------|
| `lib/Core/Api/Models/SyncResponse.dart` | Removed `factory SyncResponse.fromJson(...)` |
| `lib/Core/Api/Models/BatchSessionsResponse.dart` | Removed `factory BatchSessionsResponse.fromJson(...)` |
| `.ai-factory/ROADMAP.md` | Marked milestone 2.8 "Delete SyncApi.dart" as complete |
| `.ai-factory/plans/18-delete-syncapi-dart.md` | New plan file |

## Verification

### Dead code confirmation

- `SyncResponse.fromJson` — grep across `lib/` and `test/`: **zero callers**. Only the deleted `SyncApi.dart` called it. `SyncGrpcApi.fetchChanges()` constructs `SyncResponse(...)` directly via named params.
- `BatchSessionsResponse.fromJson` — grep across `lib/` and `test/`: **zero callers**. Only the deleted `SyncApi.dart` called it. `SyncGrpcApi.fetchSessionsBatch()` constructs `BatchSessionsResponse(...)` directly via named params.
- `ChangeEvent.fromJson` — **correctly preserved**. Still called by `SyncSocketListener._onSyncChanged()` to parse Socket.io JSON payloads.

### Import validity after removal

- `SyncResponse.dart` still imports `ChangeEvent.dart` — needed for the `List<ChangeEvent> events` field. Correct.
- `BatchSessionsResponse.dart` still imports `BreathSession.dart` — needed for the `List<BreathSession> data` field. Correct.

### No runtime impact

Both removed factories were JSON deserialization constructors for the REST/Dio path. The gRPC path (`SyncGrpcApi`) never called them — it constructs domain objects directly from proto DTOs. No code path reaches `fromJson` at runtime.

### Roadmap update

Milestone 2.8 "Delete SyncApi.dart" correctly marked `[x]`. The file was already deleted in commit `c33a586` during SyncGrpcApi implementation.

## Issues found

None.

REVIEW_PASS
