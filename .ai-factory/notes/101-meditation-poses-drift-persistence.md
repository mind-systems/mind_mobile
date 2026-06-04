# Persist Meditation Poses to Drift for Offline Use

**Date:** 2026-06-04
**Source:** conversation context — offline fallback for slug→UUID cache

## Key Findings

- `App.shared.meditationPoseUuids` is an in-memory `Map<String, String>` (slug→UUID). It is populated lazily when the meditation list opens via `MeditationListService.refresh()`, which calls `MeditationPosesGrpcApi.listPoses()` and stores the result. There is no local persistence.
- If the device is offline on first launch (or after a fresh install), `refresh()` throws, the map stays empty, and `meditationPoseUuids[slug] ?? slug` returns the slug — which triggers `invalid input syntax for type uuid` on the backend when starting a meditation session.
- Fix: add a Drift table for poses, write to it after every successful gRPC fetch, and pre-populate the in-memory map from Drift in `App.initialize()` before any screen opens.

## Details

### Current state

- **`lib/MeditationModule/MeditationPosesGrpcApi.dart`** — exists. `listPoses()` returns `List<({String id, String slug})>`.
- **`lib/MeditationModule/MeditationListService.dart`** — `refresh()` calls `meditationPosesApi.listPoses()` and writes `App.shared.meditationPoseUuids = { for (p in poses) p.slug: p.id }`. No Drift write.
- **`lib/Core/App.dart`** — `App.shared.meditationPoseUuids` declared at line ~99 as `Map<String, String> meditationPoseUuids = const {}`. `App.initialize()` creates the DB at line ~140; grpcClient at ~145; `meditationPosesApi` assigned at ~239.
- **`lib/Core/Database/Database.dart`** — `@DriftDatabase(tables: [UserRecord, BreathSessions, SyncState], daos: [...])`, schema version 3. No poses table.

### Changes

**1. New Drift table + DAO — `lib/Core/Database/MeditationPosesDao.dart`**

```dart
@DataClassName('MeditationPoseRow')
class MeditationPoses extends Table {
  TextColumn get id => text()();
  TextColumn get slug => text()();
  IntColumn get displayOrder => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftAccessor(tables: [MeditationPoses])
class MeditationPosesDao extends DatabaseAccessor<Database>
    with _$MeditationPosesDaoMixin {
  MeditationPosesDao(super.db);

  Future<List<MeditationPoseRow>> getAll() =>
      (select(meditationPoses)..orderBy([(t) => OrderingTerm.asc(t.displayOrder)])).get();

  Future<void> saveAll(List<({String id, String slug, int displayOrder})> poses) =>
      batch((b) {
        b.insertAllOnConflictUpdate(
          meditationPoses,
          poses.map((p) => MeditationPosesCompanion(
            id: Value(p.id),
            slug: Value(p.slug),
            displayOrder: Value(p.displayOrder),
          )).toList(),
        );
      });
}
```

**2. Register in Database.dart — bump schema version to 4**

```dart
@DriftDatabase(
  tables: [UserRecord, BreathSessions, SyncState, MeditationPoses],
  daos: [..., MeditationPosesDao],
)
class Database extends _$Database {
  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 4) {
        await m.createTable(meditationPoses);
      }
    },
  );
}
```

Run `flutter pub run build_runner build` after this step to regenerate Drift code.

**3. Add DAO accessor to App — `lib/Core/App.dart`**

Add alongside other `late final` DAO fields:
```dart
late final MeditationPosesDao meditationPosesDao;
```

Initialize in `App.initialize()` **right after** the DB is instantiated (~line 140):
```dart
final db = Database();
shared.meditationPosesDao = MeditationPosesDao(db);
```

**4. Pre-populate cache from Drift in `App.initialize()` — `lib/Core/App.dart`**

After `meditationPosesDao` is initialized, still in `App.initialize()`:
```dart
final cachedPoses = await shared.meditationPosesDao.getAll();
if (cachedPoses.isNotEmpty) {
  shared.meditationPoseUuids = {
    for (final p in cachedPoses) p.slug: p.id,
  };
}
```
Guard: only populate if Drift has rows — on first-ever launch the table is empty and the map stays `const {}` (populated later by `refresh()` when online).

**5. Extend `MeditationPosesGrpcApi.listPoses()` to return `displayOrder` — `lib/MeditationModule/MeditationPosesGrpcApi.dart`**

The current method returns `List<({String id, String slug})>` — it drops `display_order` from the proto response. The Drift table needs it for ordered reads. Extend the return record:

```dart
Future<List<({String id, String slug, int displayOrder})>> listPoses() async {
  final response = await _client.listPoses(Empty());
  return response.poses
      .map((p) => (id: p.id, slug: p.slug, displayOrder: p.displayOrder))
      .toList();
}
```

Update the interface type accordingly (`IBreathSessionApi`-style — check if there's an `IMeditationPosesGrpcApi` interface; if not, just update the concrete class). `MeditationListService.refresh()` already receives the result of `listPoses()`, so its call site needs the type updated too.

**6. Persist to Drift in `MeditationListService.refresh()` — `lib/MeditationModule/MeditationListService.dart`**

After a successful `listPoses()` call, write to Drift before updating the in-memory map:
```dart
@override
Future<void> refresh() async {
  try {
    final poses = await App.shared.meditationPosesApi.listPoses();
    await App.shared.meditationPosesDao.saveAll(
      poses.map((p) => (id: p.id, slug: p.slug, displayOrder: p.displayOrder)).toList(),
    );
    App.shared.meditationPoseUuids = {
      for (final p in poses) p.slug: p.id,
    };
  } catch (e) {
    debugPrint('MeditationListService.refresh failed: $e');
  }
}
```

### Data flow after this task

- **Cold start, online:** `initialize()` reads empty Drift → map stays `{}` → list opens → `refresh()` fetches → writes Drift → updates map. Session starts with correct UUID.
- **Cold start, offline:** `initialize()` reads empty Drift → map stays `{}` → list opens → `refresh()` fails (swallowed) → map still `{}` → session would still fail. **This edge case only affects first-ever launch with no connectivity** — unavoidable without seeding.
- **Subsequent start (ever been online once), offline:** `initialize()` reads Drift → map populated with cached UUIDs → session works offline.
- **Online refresh:** `refresh()` fetches new data, upserts Drift (handles server-side pose additions), updates map — list changes are picked up silently.

### Guards

- Do NOT delete rows from Drift on refresh — use `insertAllOnConflictUpdate` (upsert) so poses removed server-side are kept locally until the next successful full fetch. Pose catalog is append-only in practice.
- Do NOT call `refresh()` in `App.initialize()` directly — the gRPC client may not be connected yet and the call would fail silently anyway. The pre-populate is Drift-only; the background refresh happens lazily when the screen opens.
- `meditationPosesApi` is assigned at line ~239 of `App.initialize()`, AFTER `initialize()` places `meditationPosesDao`. The Drift read at step 4 must happen BEFORE line 239 (it only needs the DAO, not the API).

### How to verify

1. Launch app online, open meditation list → poses load, UUID cache populated.
2. Kill app, go offline, relaunch → open meditation list → start session → no UUID crash (uses cached UUIDs from Drift).
3. `flutter analyze` clean after build_runner run.
