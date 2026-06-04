part of 'Database.dart';

/// ----------
/// Table
/// ----------

@DataClassName('MeditationPoseRow')
class MeditationPoses extends Table {
  TextColumn get id => text()();
  TextColumn get slug => text()();
  IntColumn get displayOrder => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// ----------
/// DAO
/// ----------

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
