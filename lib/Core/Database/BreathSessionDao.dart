part of 'Database.dart';

/// ----------
/// Converters
/// ----------

class ExerciseSetListConverter extends TypeConverter<List<ExerciseSet>, String> {
  const ExerciseSetListConverter();

  @override
  List<ExerciseSet> fromSql(String fromDb) {
    final List decoded = jsonDecode(fromDb) as List;
    return decoded.map((e) => _exerciseSetFromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  String toSql(List<ExerciseSet> value) {
    return jsonEncode(value.map(_exerciseSetToJson).toList());
  }

  Map<String, dynamic> _exerciseSetToJson(ExerciseSet set) {
    return {
      'restDuration': set.restDuration,
      'repeatCount': set.repeatCount,
      'steps': set.steps.map((s) => {
        'type': s.type.name,
        'duration': s.duration,
      }).toList(),
    };
  }

  ExerciseSet _exerciseSetFromJson(Map<String, dynamic> json) {
    return ExerciseSet(
      restDuration: json['restDuration'] as int,
      repeatCount: json['repeatCount'] as int,
      steps: (json['steps'] as List)
          .map(
            (s) => ExerciseStep(
          type: StepType.values.byName(s['type'] as String),
          duration: s['duration'] as int,
        ),
      )
          .toList(),
    );
  }
}

/// ----------
/// Table
/// ----------

@DataClassName('BreathSessionRow')
class BreathSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get description => text()();
  BoolColumn get shared => boolean()();

  TextColumn get exercises =>
      text().map(const ExerciseSetListConverter())();

  BoolColumn get isStarred => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(Constant(DateTime.fromMillisecondsSinceEpoch(0)))();

  RealColumn get complexity => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// ----------
/// DAO
/// ----------

@DriftAccessor(tables: [BreathSessions])
class BreathSessionDao extends DatabaseAccessor<Database>
    with _$BreathSessionDaoMixin
    implements IBreathSessionDao {
  BreathSessionDao(super.db);

  /// Returns sessions sorted by [createdAt] DESC so that the ViewModel
  /// receives rows in the same newest-first order the server provides.
  /// [..orderBy] mutates the same [SimpleSelectStatement] in place,
  /// so the subsequent [query.limit] applies to the already-ordered query.
  @override
  Future<List<BreathSession>> getSessions({int? limit, int? offset}) async {
    final query = select(breathSessions)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (limit != null) query.limit(limit, offset: offset);
    final rows = await query.get();
    return rows.map(_mapRowToDomain).toList();
  }

  @override
  Future<void> saveSession(BreathSession session) async {
    await into(breathSessions).insertOnConflictUpdate(
      _mapDomainToCompanion(session),
    );
  }

  @override
  Future<void> saveSessions(List<BreathSession> sessions) async {
    for (final session in sessions) {
      await into(breathSessions).insertOnConflictUpdate(
        _mapDomainToCompanion(session),
      );
    }
  }

  @override
  Future<void> deleteSession(String id) async {
    await (delete(breathSessions)..where((tbl) => tbl.id.equals(id))).go();
  }

  @override
  Future<void> deleteAllSessions() async {
    await delete(breathSessions).go();
  }

  @override
  Future<BreathSession?> getSessionById(String id) async {
    final row = await (select(breathSessions)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _mapRowToDomain(row);
  }

  /// ----------
  /// Mapping
  /// ----------

  BreathSession _mapRowToDomain(BreathSessionRow row) {
    return BreathSession(
      id: row.id,
      userId: row.userId,
      description: row.description,
      shared: row.shared,
      isStarred: row.isStarred,
      complexity: row.complexity,
      createdAt: row.createdAt,
      exercises: row.exercises,
    );
  }

  BreathSessionsCompanion _mapDomainToCompanion(BreathSession session) {
    return BreathSessionsCompanion(
      id: Value(session.id),
      userId: Value(session.userId),
      description: Value(session.description),
      shared: Value(session.shared),
      isStarred: Value(session.isStarred),
      complexity: Value(session.complexity),
      createdAt: Value(session.createdAt),
      exercises: Value(session.exercises),
    );
  }
}
