import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../User/Models/User.dart';

part 'Database.g.dart';
part 'UserDao.dart';

@DriftDatabase(tables: [UserRecord], daos: [UserDao])
class Database extends _$Database {
  Database([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from == 1) {
        await migrator.addColumn(userRecord, userRecord.isGuest);
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
