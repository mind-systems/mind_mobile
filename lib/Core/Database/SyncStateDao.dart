part of 'Database.dart';

/// ----------
/// Table
/// ----------

@DataClassName('SyncStateRow')
class SyncState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// ----------
/// DAO
/// ----------

@DriftAccessor(tables: [SyncState])
class SyncStateDao extends DatabaseAccessor<Database>
    with _$SyncStateDaoMixin
    implements ISyncStateDao {
  SyncStateDao(super.db);

  @override
  Future<int> getLastEventId() async {
    final row = await (select(syncState)..where((tbl) => tbl.key.equals('lastEventId'))).getSingleOrNull();
    if (row == null) return 0;
    return int.parse(row.value);
  }

  @override
  Future<void> setLastEventId(int eventId) async {
    await into(syncState).insertOnConflictUpdate(
      SyncStateCompanion(key: const Value('lastEventId'), value: Value('$eventId')),
    );
  }

  @override
  Future<void> reset() async {
    await (delete(syncState)..where((tbl) => tbl.key.equals('lastEventId'))).go();
  }
}
