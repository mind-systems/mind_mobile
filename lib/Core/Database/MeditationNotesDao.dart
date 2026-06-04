part of 'Database.dart';

/// ----------
/// Table
/// ----------

@DataClassName('MeditationNoteRow')
class MeditationNotes extends Table {
  TextColumn get id => text()();
  TextColumn get poseId => text()();
  TextColumn get noteText => text()();
  IntColumn get createdAt => integer()();
  TextColumn get serverSessionId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// ----------
/// DAO
/// ----------

@DriftAccessor(tables: [MeditationNotes])
class MeditationNotesDao extends DatabaseAccessor<Database>
    with _$MeditationNotesDaoMixin {
  MeditationNotesDao(super.db);

  Future<void> insertNote(MeditationNotesCompanion entry) =>
      into(meditationNotes).insert(entry);
}
