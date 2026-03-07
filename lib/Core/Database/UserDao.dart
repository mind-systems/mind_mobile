part of 'Database.dart';

@DataClassName('Users')
class UserRecord extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get name => text()();
  BoolColumn get isGuest => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftAccessor(tables: [UserRecord])
class UserDao extends DatabaseAccessor<Database> with _$UserDaoMixin implements IUserDao {
  UserDao(super.db);

  @override
  Future<User?> getUser() async {
    final row = await select(userRecord).getSingleOrNull();
    if (row == null) return null;
    return _mapRowToUser(row);
  }

  @override
  Future<void> saveUser(User user) async {
    final companion = _mapUserToCompanion(user);
    await into(userRecord).insertOnConflictUpdate(companion);
  }

  @override
  Future<void> deleteUser(String id) async {
    (delete(userRecord)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<void> clear() async => delete(userRecord).go();

  User _mapRowToUser(Users row) {
    return User(
      id: row.id,
      email: row.email,
      name: row.name,
      isGuest: row.isGuest,
    );
  }

  UserRecordCompanion _mapUserToCompanion(User user) {
    return UserRecordCompanion(
      id: Value(user.id),
      email: Value(user.email),
      name: Value(user.name),
      isGuest: Value(user.isGuest),
    );
  }
}

