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

class $BreathSessionsTable extends BreathSessions
    with TableInfo<$BreathSessionsTable, BreathSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BreathSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sharedMeta = const VerificationMeta('shared');
  @override
  late final GeneratedColumn<bool> shared = GeneratedColumn<bool>(
    'shared',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("shared" IN (0, 1))',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<ExerciseSet>, String>
  exercises = GeneratedColumn<String>(
    'exercises',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<List<ExerciseSet>>($BreathSessionsTable.$converterexercises);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    description,
    shared,
    exercises,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'breath_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<BreathSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('shared')) {
      context.handle(
        _sharedMeta,
        shared.isAcceptableOrUnknown(data['shared']!, _sharedMeta),
      );
    } else if (isInserting) {
      context.missing(_sharedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BreathSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BreathSessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      shared: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}shared'],
      )!,
      exercises: $BreathSessionsTable.$converterexercises.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}exercises'],
        )!,
      ),
    );
  }

  @override
  $BreathSessionsTable createAlias(String alias) {
    return $BreathSessionsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<ExerciseSet>, String> $converterexercises =
      const ExerciseSetListConverter();
}

class BreathSessionRow extends DataClass
    implements Insertable<BreathSessionRow> {
  final String id;
  final String userId;
  final String description;
  final bool shared;
  final List<ExerciseSet> exercises;
  const BreathSessionRow({
    required this.id,
    required this.userId,
    required this.description,
    required this.shared,
    required this.exercises,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['description'] = Variable<String>(description);
    map['shared'] = Variable<bool>(shared);
    {
      map['exercises'] = Variable<String>(
        $BreathSessionsTable.$converterexercises.toSql(exercises),
      );
    }
    return map;
  }

  BreathSessionsCompanion toCompanion(bool nullToAbsent) {
    return BreathSessionsCompanion(
      id: Value(id),
      userId: Value(userId),
      description: Value(description),
      shared: Value(shared),
      exercises: Value(exercises),
    );
  }

  factory BreathSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BreathSessionRow(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      description: serializer.fromJson<String>(json['description']),
      shared: serializer.fromJson<bool>(json['shared']),
      exercises: serializer.fromJson<List<ExerciseSet>>(json['exercises']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'description': serializer.toJson<String>(description),
      'shared': serializer.toJson<bool>(shared),
      'exercises': serializer.toJson<List<ExerciseSet>>(exercises),
    };
  }

  BreathSessionRow copyWith({
    String? id,
    String? userId,
    String? description,
    bool? shared,
    List<ExerciseSet>? exercises,
  }) => BreathSessionRow(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    description: description ?? this.description,
    shared: shared ?? this.shared,
    exercises: exercises ?? this.exercises,
  );
  BreathSessionRow copyWithCompanion(BreathSessionsCompanion data) {
    return BreathSessionRow(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      description: data.description.present
          ? data.description.value
          : this.description,
      shared: data.shared.present ? data.shared.value : this.shared,
      exercises: data.exercises.present ? data.exercises.value : this.exercises,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BreathSessionRow(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('description: $description, ')
          ..write('shared: $shared, ')
          ..write('exercises: $exercises')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, description, shared, exercises);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BreathSessionRow &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.description == this.description &&
          other.shared == this.shared &&
          other.exercises == this.exercises);
}

class BreathSessionsCompanion extends UpdateCompanion<BreathSessionRow> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> description;
  final Value<bool> shared;
  final Value<List<ExerciseSet>> exercises;
  final Value<int> rowid;
  const BreathSessionsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.description = const Value.absent(),
    this.shared = const Value.absent(),
    this.exercises = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BreathSessionsCompanion.insert({
    required String id,
    required String userId,
    required String description,
    required bool shared,
    required List<ExerciseSet> exercises,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       description = Value(description),
       shared = Value(shared),
       exercises = Value(exercises);
  static Insertable<BreathSessionRow> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? description,
    Expression<bool>? shared,
    Expression<String>? exercises,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (description != null) 'description': description,
      if (shared != null) 'shared': shared,
      if (exercises != null) 'exercises': exercises,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BreathSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? description,
    Value<bool>? shared,
    Value<List<ExerciseSet>>? exercises,
    Value<int>? rowid,
  }) {
    return BreathSessionsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      description: description ?? this.description,
      shared: shared ?? this.shared,
      exercises: exercises ?? this.exercises,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (shared.present) {
      map['shared'] = Variable<bool>(shared.value);
    }
    if (exercises.present) {
      map['exercises'] = Variable<String>(
        $BreathSessionsTable.$converterexercises.toSql(exercises.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BreathSessionsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('description: $description, ')
          ..write('shared: $shared, ')
          ..write('exercises: $exercises, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$Database extends GeneratedDatabase {
  _$Database(QueryExecutor e) : super(e);
  $DatabaseManager get managers => $DatabaseManager(this);
  late final $UserRecordTable userRecord = $UserRecordTable(this);
  late final $BreathSessionsTable breathSessions = $BreathSessionsTable(this);
  late final UserDao userDao = UserDao(this as Database);
  late final BreathSessionDao breathSessionDao = BreathSessionDao(
    this as Database,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    userRecord,
    breathSessions,
  ];
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
typedef $$BreathSessionsTableCreateCompanionBuilder =
    BreathSessionsCompanion Function({
      required String id,
      required String userId,
      required String description,
      required bool shared,
      required List<ExerciseSet> exercises,
      Value<int> rowid,
    });
typedef $$BreathSessionsTableUpdateCompanionBuilder =
    BreathSessionsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> description,
      Value<bool> shared,
      Value<List<ExerciseSet>> exercises,
      Value<int> rowid,
    });

class $$BreathSessionsTableFilterComposer
    extends Composer<_$Database, $BreathSessionsTable> {
  $$BreathSessionsTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get shared => $composableBuilder(
    column: $table.shared,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<ExerciseSet>, List<ExerciseSet>, String>
  get exercises => $composableBuilder(
    column: $table.exercises,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$BreathSessionsTableOrderingComposer
    extends Composer<_$Database, $BreathSessionsTable> {
  $$BreathSessionsTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get shared => $composableBuilder(
    column: $table.shared,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exercises => $composableBuilder(
    column: $table.exercises,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BreathSessionsTableAnnotationComposer
    extends Composer<_$Database, $BreathSessionsTable> {
  $$BreathSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get shared =>
      $composableBuilder(column: $table.shared, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<ExerciseSet>, String> get exercises =>
      $composableBuilder(column: $table.exercises, builder: (column) => column);
}

class $$BreathSessionsTableTableManager
    extends
        RootTableManager<
          _$Database,
          $BreathSessionsTable,
          BreathSessionRow,
          $$BreathSessionsTableFilterComposer,
          $$BreathSessionsTableOrderingComposer,
          $$BreathSessionsTableAnnotationComposer,
          $$BreathSessionsTableCreateCompanionBuilder,
          $$BreathSessionsTableUpdateCompanionBuilder,
          (
            BreathSessionRow,
            BaseReferences<_$Database, $BreathSessionsTable, BreathSessionRow>,
          ),
          BreathSessionRow,
          PrefetchHooks Function()
        > {
  $$BreathSessionsTableTableManager(_$Database db, $BreathSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BreathSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BreathSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BreathSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<bool> shared = const Value.absent(),
                Value<List<ExerciseSet>> exercises = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BreathSessionsCompanion(
                id: id,
                userId: userId,
                description: description,
                shared: shared,
                exercises: exercises,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String description,
                required bool shared,
                required List<ExerciseSet> exercises,
                Value<int> rowid = const Value.absent(),
              }) => BreathSessionsCompanion.insert(
                id: id,
                userId: userId,
                description: description,
                shared: shared,
                exercises: exercises,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BreathSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$Database,
      $BreathSessionsTable,
      BreathSessionRow,
      $$BreathSessionsTableFilterComposer,
      $$BreathSessionsTableOrderingComposer,
      $$BreathSessionsTableAnnotationComposer,
      $$BreathSessionsTableCreateCompanionBuilder,
      $$BreathSessionsTableUpdateCompanionBuilder,
      (
        BreathSessionRow,
        BaseReferences<_$Database, $BreathSessionsTable, BreathSessionRow>,
      ),
      BreathSessionRow,
      PrefetchHooks Function()
    >;

class $DatabaseManager {
  final _$Database _db;
  $DatabaseManager(this._db);
  $$UserRecordTableTableManager get userRecord =>
      $$UserRecordTableTableManager(_db, _db.userRecord);
  $$BreathSessionsTableTableManager get breathSessions =>
      $$BreathSessionsTableTableManager(_db, _db.breathSessions);
}

mixin _$UserDaoMixin on DatabaseAccessor<Database> {
  $UserRecordTable get userRecord => attachedDatabase.userRecord;
}
mixin _$BreathSessionDaoMixin on DatabaseAccessor<Database> {
  $BreathSessionsTable get breathSessions => attachedDatabase.breathSessions;
}
