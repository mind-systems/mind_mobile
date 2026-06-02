# Meditation Notes — Drift Table and Repository

**Date:** 2026-06-02
**Source:** conversation context

## Key Findings

- New Drift table `MeditationNotesTable` with no cascade delete — notes intentionally outlive sessions.
- `serverSessionId` is nullable — filled in later by the server-sync task (blocked on API contract); local saves work without it.
- `MeditationNoteRepository.save()` generates a local UUID and inserts; callers fire-and-forget.

## Details

### Drift table definition

**File:** `lib/Core/Database/MeditationNotesTable.dart` (or inline in `AppDatabase.dart`)

```dart
class MeditationNotesTable extends Table {
  TextColumn get id => text()();
  TextColumn get poseName => text()();
  TextColumn get noteText => text()();
  IntColumn get createdAt => integer()();
  TextColumn get serverSessionId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

No `references()` on `serverSessionId` — this is intentional. Notes are not FK-linked to any session table so they survive session deletion without any DB-level cascade.

### AppDatabase update

**File:** `lib/Core/Database/AppDatabase.dart`

Add `MeditationNotesTable` to the `@DriftDatabase(tables: [...])` annotation. After editing, run:

```bash
flutter pub run build_runner build
```

Verify `MeditationNotesTableData` and `MeditationNotesTableCompanion` appear in generated code.

### MeditationNoteRepository

**File:** `lib/MeditationModule/MeditationNoteRepository.dart`

```dart
class MeditationNoteRepository {
  final AppDatabase _db;

  MeditationNoteRepository(this._db);

  Future<void> save(
    String poseName,
    String text, {
    String? serverSessionId,
  }) async {
    await _db.into(_db.meditationNotesTable).insert(
      MeditationNotesTableCompanion.insert(
        id: const Uuid().v4(),
        poseName: poseName,
        noteText: text,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        serverSessionId: Value(serverSessionId),
      ),
    );
  }
}
```

**uuid package:** check `pubspec.yaml` — if `uuid` is not already a dependency, add it with `flutter pub add uuid`. It is likely already present (used elsewhere in the codebase for session IDs).

### App.dart

Add `late final MeditationNoteRepository meditationNoteRepository` field. In `initialize()`, after `AppDatabase` is constructed:

```dart
meditationNoteRepository = MeditationNoteRepository(database);
```

### Verify

Open the app, complete a meditation session, check that a row appears in `meditation_notes` via a Drift inspector or debug print in `save()`.

## Open Questions

- Confirm whether `uuid` is already in `pubspec.yaml` before adding it.
- The exact location of the Drift table file — either a standalone file or inline in `AppDatabase.dart` — should match the project's existing convention (check how other tables like the breath session tables are organized).
