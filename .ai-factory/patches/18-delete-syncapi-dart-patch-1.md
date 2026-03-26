# Patch: 18-delete-syncapi-dart

**Source review:** `.ai-factory/reviews/18-delete-syncapi-dart-review-1.md`

## Issue 1: Dead `ChangeEvent.fromJson` factory

**File:** `lib/Core/Api/Models/ChangeEvent.dart`

**Problem:** The plan preserved `ChangeEvent.fromJson` because `SyncSocketListener._onSyncChanged()` was its only caller. However, `SyncSocketListener` was already deleted in milestone 3.6 (commit `32bc6a4`). Grep confirms zero callers of `ChangeEvent.fromJson` across `lib/` and `test/`. The factory is dead code, inconsistent with the removal of `SyncResponse.fromJson` and `BatchSessionsResponse.fromJson` in the same commit.

**Fix:** Remove the `factory ChangeEvent.fromJson(...)` constructor.

**Before:**
```dart
class ChangeEvent {
  final int id;
  final String entity;
  final String refId;
  final String action;

  ChangeEvent({
    required this.id,
    required this.entity,
    required this.refId,
    required this.action,
  });

  factory ChangeEvent.fromJson(Map<String, dynamic> json) => ChangeEvent(
    id: json['id'] as int,
    entity: json['entity'] as String,
    refId: json['refId'] as String,
    action: json['action'] as String,
  );
}
```

**After:**
```dart
class ChangeEvent {
  final int id;
  final String entity;
  final String refId;
  final String action;

  ChangeEvent({
    required this.id,
    required this.entity,
    required this.refId,
    required this.action,
  });
}
```

**Risk:** None — zero callers confirmed. The `ChangeEvent` class itself remains (used by `SyncGrpcApi`, `SyncGrpcListener`, `SyncEngine`, and `SyncResponse`), only the unused JSON deserialization factory is removed.
