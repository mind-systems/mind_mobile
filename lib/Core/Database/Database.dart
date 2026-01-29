import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

import 'package:mind/User/Models/User.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Models/ExerciseStep.dart';
import 'package:mind/BreathModule/Presentation/CommonModels/StepType.dart';


part 'Database.g.dart';
part 'UserDao.dart';
part 'BreathSessionDao.dart';

@DriftDatabase(tables: [UserRecord, BreathSessions], daos: [UserDao, BreathSessionDao])
class Database extends _$Database {
  Database([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from == 1) {
        await migrator.addColumn(userRecord, userRecord.isGuest);
      }
      if (from == 2) {
        await migrator.createTable(breathSessions);
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
