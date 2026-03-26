# Review: 18-delete-syncapi-dart (patch round)

**Patch applied:** `.ai-factory/patches/18-delete-syncapi-dart-patch-1.md`

## Changed files

| File | Change |
|------|--------|
| `lib/Core/Api/Models/ChangeEvent.dart` | Removed dead `factory ChangeEvent.fromJson(...)` |

## Verification

| Check | Result |
|-------|--------|
| `ChangeEvent.fromJson` callers in `lib/` | Zero — only match is `sync.pb.dart` (different class in proto namespace) |
| `ChangeEvent.fromJson` callers in `test/` | Zero |
| `ChangeEvent` class still valid after removal | Yes — named constructor, all four fields intact |
| Importers unaffected | `SyncGrpcApi`, `SyncGrpcListener`, `SyncEngine`, `SyncResponse` all use the named constructor, never `fromJson` |

## Issues found

None.

REVIEW_PASS
