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

  @override
  Set<Column> get primaryKey => {id};
}

/// ----------
/// DAO
/// ----------

@DriftAccessor(tables: [BreathSessions])
class BreathSessionDao extends DatabaseAccessor<Database>
    with _$BreathSessionDaoMixin {
  BreathSessionDao(super.db);

  Future<List<BreathSession>> getSessions() async {
    final rows = await select(breathSessions).get();

    return rows.map(_mapRowToDomain).toList();
  }

  Future<void> saveSession(BreathSession session) async {
    await into(breathSessions).insertOnConflictUpdate(
      _mapDomainToCompanion(session),
    );
  }

  Future<void> saveSessions(List<BreathSession> sessions) async {
    for (final session in sessions) {
      await into(breathSessions).insertOnConflictUpdate(
        _mapDomainToCompanion(session),
      );
    }
  }

  Future<void> deleteSession(String id) async {
    await (delete(breathSessions)..where((tbl) => tbl.id.equals(id))).go();
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
      exercises: row.exercises,
    );
  }

  BreathSessionsCompanion _mapDomainToCompanion(BreathSession session) {
    return BreathSessionsCompanion(
      id: Value(session.id),
      userId: Value(session.userId),
      description: Value(session.description),
      shared: Value(session.shared),
      exercises: Value(session.exercises),
    );
  }
}
