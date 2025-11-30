// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Database.dart';

// ignore_for_file: type=lint
class $UserRecordTable extends UserRecord
    with TableInfo<$UserRecordTable, Users> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserRecordTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firebaseUidMeta = const VerificationMeta(
    'firebaseUid',
  );
  @override
  late final GeneratedColumn<String> firebaseUid = GeneratedColumn<String>(
    'firebase_uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isGuestMeta = const VerificationMeta(
    'isGuest',
  );
  @override
  late final GeneratedColumn<bool> isGuest = GeneratedColumn<bool>(
    'is_guest',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_guest" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [id, firebaseUid, email, name, isGuest];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_record';
  @override
  VerificationContext validateIntegrity(
    Insertable<Users> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('firebase_uid')) {
      context.handle(
        _firebaseUidMeta,
        firebaseUid.isAcceptableOrUnknown(
          data['firebase_uid']!,
          _firebaseUidMeta,
        ),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_guest')) {
      context.handle(
        _isGuestMeta,
        isGuest.isAcceptableOrUnknown(data['is_guest']!, _isGuestMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Users map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Users(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      firebaseUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firebase_uid'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isGuest: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_guest'],
      )!,
    );
  }

  @override
  $UserRecordTable createAlias(String alias) {
    return $UserRecordTable(attachedDatabase, alias);
  }
}

class Users extends DataClass implements Insertable<Users> {
  final String id;
  final String? firebaseUid;
  final String email;
  final String name;
  final bool isGuest;
  const Users({
    required this.id,
    this.firebaseUid,
    required this.email,
    required this.name,
    required this.isGuest,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || firebaseUid != null) {
      map['firebase_uid'] = Variable<String>(firebaseUid);
    }
    map['email'] = Variable<String>(email);
    map['name'] = Variable<String>(name);
    map['is_guest'] = Variable<bool>(isGuest);
    return map;
  }

  UserRecordCompanion toCompanion(bool nullToAbsent) {
    return UserRecordCompanion(
      id: Value(id),
      firebaseUid: firebaseUid == null && nullToAbsent
          ? const Value.absent()
          : Value(firebaseUid),
      email: Value(email),
      name: Value(name),
      isGuest: Value(isGuest),
    );
  }

  factory Users.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Users(
      id: serializer.fromJson<String>(json['id']),
      firebaseUid: serializer.fromJson<String?>(json['firebaseUid']),
      email: serializer.fromJson<String>(json['email']),
      name: serializer.fromJson<String>(json['name']),
      isGuest: serializer.fromJson<bool>(json['isGuest']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'firebaseUid': serializer.toJson<String?>(firebaseUid),
      'email': serializer.toJson<String>(email),
      'name': serializer.toJson<String>(name),
      'isGuest': serializer.toJson<bool>(isGuest),
    };
  }

  Users copyWith({
    String? id,
    Value<String?> firebaseUid = const Value.absent(),
    String? email,
    String? name,
    bool? isGuest,
  }) => Users(
    id: id ?? this.id,
    firebaseUid: firebaseUid.present ? firebaseUid.value : this.firebaseUid,
    email: email ?? this.email,
    name: name ?? this.name,
    isGuest: isGuest ?? this.isGuest,
  );
  Users copyWithCompanion(UserRecordCompanion data) {
    return Users(
      id: data.id.present ? data.id.value : this.id,
      firebaseUid: data.firebaseUid.present
          ? data.firebaseUid.value
          : this.firebaseUid,
      email: data.email.present ? data.email.value : this.email,
      name: data.name.present ? data.name.value : this.name,
      isGuest: data.isGuest.present ? data.isGuest.value : this.isGuest,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Users(')
          ..write('id: $id, ')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('email: $email, ')
          ..write('name: $name, ')
          ..write('isGuest: $isGuest')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, firebaseUid, email, name, isGuest);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Users &&
          other.id == this.id &&
          other.firebaseUid == this.firebaseUid &&
          other.email == this.email &&
          other.name == this.name &&
          other.isGuest == this.isGuest);
}

class UserRecordCompanion extends UpdateCompanion<Users> {
  final Value<String> id;
  final Value<String?> firebaseUid;
  final Value<String> email;
  final Value<String> name;
  final Value<bool> isGuest;
  final Value<int> rowid;
  const UserRecordCompanion({
    this.id = const Value.absent(),
    this.firebaseUid = const Value.absent(),
    this.email = const Value.absent(),
    this.name = const Value.absent(),
    this.isGuest = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserRecordCompanion.insert({
    required String id,
    this.firebaseUid = const Value.absent(),
    required String email,
    required String name,
    this.isGuest = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       email = Value(email),
       name = Value(name);
  static Insertable<Users> custom({
    Expression<String>? id,
    Expression<String>? firebaseUid,
    Expression<String>? email,
    Expression<String>? name,
    Expression<bool>? isGuest,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (firebaseUid != null) 'firebase_uid': firebaseUid,
      if (email != null) 'email': email,
      if (name != null) 'name': name,
      if (isGuest != null) 'is_guest': isGuest,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserRecordCompanion copyWith({
    Value<String>? id,
    Value<String?>? firebaseUid,
    Value<String>? email,
    Value<String>? name,
    Value<bool>? isGuest,
    Value<int>? rowid,
  }) {
    return UserRecordCompanion(
      id: id ?? this.id,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      email: email ?? this.email,
      name: name ?? this.name,
      isGuest: isGuest ?? this.isGuest,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (firebaseUid.present) {
      map['firebase_uid'] = Variable<String>(firebaseUid.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isGuest.present) {
      map['is_guest'] = Variable<bool>(isGuest.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserRecordCompanion(')
          ..write('id: $id, ')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('email: $email, ')
          ..write('name: $name, ')
          ..write('isGuest: $isGuest, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$Database extends GeneratedDatabase {
  _$Database(QueryExecutor e) : super(e);
  $DatabaseManager get managers => $DatabaseManager(this);
  late final $UserRecordTable userRecord = $UserRecordTable(this);
  late final UserDao userDao = UserDao(this as Database);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [userRecord];
}

typedef $$UserRecordTableCreateCompanionBuilder =
    UserRecordCompanion Function({
      required String id,
      Value<String?> firebaseUid,
      required String email,
      required String name,
      Value<bool> isGuest,
      Value<int> rowid,
    });
typedef $$UserRecordTableUpdateCompanionBuilder =
    UserRecordCompanion Function({
      Value<String> id,
      Value<String?> firebaseUid,
      Value<String> email,
      Value<String> name,
      Value<bool> isGuest,
      Value<int> rowid,
    });

class $$UserRecordTableFilterComposer
    extends Composer<_$Database, $UserRecordTable> {
  $$UserRecordTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firebaseUid => $composableBuilder(
    column: $table.firebaseUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isGuest => $composableBuilder(
    column: $table.isGuest,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserRecordTableOrderingComposer
    extends Composer<_$Database, $UserRecordTable> {
  $$UserRecordTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firebaseUid => $composableBuilder(
    column: $table.firebaseUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isGuest => $composableBuilder(
    column: $table.isGuest,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserRecordTableAnnotationComposer
    extends Composer<_$Database, $UserRecordTable> {
  $$UserRecordTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get firebaseUid => $composableBuilder(
    column: $table.firebaseUid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isGuest =>
      $composableBuilder(column: $table.isGuest, builder: (column) => column);
}

class $$UserRecordTableTableManager
    extends
        RootTableManager<
          _$Database,
          $UserRecordTable,
          Users,
          $$UserRecordTableFilterComposer,
          $$UserRecordTableOrderingComposer,
          $$UserRecordTableAnnotationComposer,
          $$UserRecordTableCreateCompanionBuilder,
          $$UserRecordTableUpdateCompanionBuilder,
          (Users, BaseReferences<_$Database, $UserRecordTable, Users>),
          Users,
          PrefetchHooks Function()
        > {
  $$UserRecordTableTableManager(_$Database db, $UserRecordTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserRecordTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserRecordTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserRecordTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> firebaseUid = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isGuest = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserRecordCompanion(
                id: id,
                firebaseUid: firebaseUid,
                email: email,
                name: name,
                isGuest: isGuest,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> firebaseUid = const Value.absent(),
                required String email,
                required String name,
                Value<bool> isGuest = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserRecordCompanion.insert(
                id: id,
                firebaseUid: firebaseUid,
                email: email,
                name: name,
                isGuest: isGuest,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserRecordTableProcessedTableManager =
    ProcessedTableManager<
      _$Database,
      $UserRecordTable,
      Users,
      $$UserRecordTableFilterComposer,
      $$UserRecordTableOrderingComposer,
      $$UserRecordTableAnnotationComposer,
      $$UserRecordTableCreateCompanionBuilder,
      $$UserRecordTableUpdateCompanionBuilder,
      (Users, BaseReferences<_$Database, $UserRecordTable, Users>),
      Users,
      PrefetchHooks Function()
    >;

class $DatabaseManager {
  final _$Database _db;
  $DatabaseManager(this._db);
  $$UserRecordTableTableManager get userRecord =>
      $$UserRecordTableTableManager(_db, _db.userRecord);
}

mixin _$UserDaoMixin on DatabaseAccessor<Database> {
  $UserRecordTable get userRecord => attachedDatabase.userRecord;
}
