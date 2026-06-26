part of 'Database.dart';

/// ----------
/// Table
/// ----------

@DataClassName('ModuleSessionNoteRow')
class ModuleSessionNotes extends Table {
  TextColumn get id => text()();
  TextColumn get noteText => text()();
  IntColumn get createdAt => integer()();
  TextColumn get serverSessionId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// ----------
/// DAO
/// ----------

@DriftAccessor(tables: [ModuleSessionNotes])
class ModuleSessionNotesDao extends DatabaseAccessor<Database>
    with _$ModuleSessionNotesDaoMixin {
  ModuleSessionNotesDao(super.db);

  Future<void> insertNote(ModuleSessionNotesCompanion entry) =>
      into(moduleSessionNotes).insert(entry);
}
