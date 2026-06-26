import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

import 'package:mind/Core/Database/IUserDao.dart';
import 'package:mind/Core/Database/IBreathSessionDao.dart';
import 'package:mind/Core/Database/ISyncStateDao.dart';
import 'package:mind/User/Models/User.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Models/ExerciseStep.dart';
import 'package:mind/BreathModule/Models/StepType.dart';


part 'Database.g.dart';
part 'UserDao.dart';
part 'BreathSessionDao.dart';
part 'SyncStateDao.dart';
part 'MeditationPosesDao.dart';
part 'ModuleSessionNotesDao.dart';

@DriftDatabase(tables: [UserRecord, BreathSessions, SyncState, MeditationPoses, ModuleSessionNotes], daos: [UserDao, BreathSessionDao, SyncStateDao, MeditationPosesDao, ModuleSessionNotesDao])
class Database extends _$Database {
  Database([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      for (var step = from; step < to; step++) {
        if (step == 1) {
          await migrator.createTable(breathSessions);
        }
        if (step == 2) {
          await migrator.createTable(syncState);
        }
        if (step == 3) {
          await migrator.createTable(meditationPoses);
        }
        if (step == 4) {
          // Legacy notes table; superseded and dropped in step 5.
          await customStatement(
            'CREATE TABLE IF NOT EXISTS meditation_notes ('
            'id TEXT NOT NULL PRIMARY KEY, '
            'pose_id TEXT NOT NULL, '
            'note_text TEXT NOT NULL, '
            'created_at INTEGER NOT NULL, '
            'server_session_id TEXT)');
        }
        if (step == 5) {
          await customStatement('DROP TABLE IF EXISTS meditation_notes');
          await migrator.createTable(moduleSessionNotes);
        }
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'db.sqlite',
      native: const DriftNativeOptions(databaseDirectory: getApplicationSupportDirectory,),
    );
  }
}
