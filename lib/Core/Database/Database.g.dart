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
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
  List<GeneratedColumn> get $columns => [id, email, name, language, isGuest];
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
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
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
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
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
  final String email;
  final String name;
  final String language;
  final bool isGuest;
  const Users({
    required this.id,
    required this.email,
    required this.name,
    required this.language,
    required this.isGuest,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['email'] = Variable<String>(email);
    map['name'] = Variable<String>(name);
    map['language'] = Variable<String>(language);
    map['is_guest'] = Variable<bool>(isGuest);
    return map;
  }

  UserRecordCompanion toCompanion(bool nullToAbsent) {
    return UserRecordCompanion(
      id: Value(id),
      email: Value(email),
      name: Value(name),
      language: Value(language),
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
      email: serializer.fromJson<String>(json['email']),
      name: serializer.fromJson<String>(json['name']),
      language: serializer.fromJson<String>(json['language']),
      isGuest: serializer.fromJson<bool>(json['isGuest']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'email': serializer.toJson<String>(email),
      'name': serializer.toJson<String>(name),
      'language': serializer.toJson<String>(language),
      'isGuest': serializer.toJson<bool>(isGuest),
    };
  }

  Users copyWith({
    String? id,
    String? email,
    String? name,
    String? language,
    bool? isGuest,
  }) => Users(
    id: id ?? this.id,
    email: email ?? this.email,
    name: name ?? this.name,
    language: language ?? this.language,
    isGuest: isGuest ?? this.isGuest,
  );
  Users copyWithCompanion(UserRecordCompanion data) {
    return Users(
      id: data.id.present ? data.id.value : this.id,
      email: data.email.present ? data.email.value : this.email,
      name: data.name.present ? data.name.value : this.name,
      language: data.language.present ? data.language.value : this.language,
      isGuest: data.isGuest.present ? data.isGuest.value : this.isGuest,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Users(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('name: $name, ')
          ..write('language: $language, ')
          ..write('isGuest: $isGuest')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, email, name, language, isGuest);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Users &&
          other.id == this.id &&
          other.email == this.email &&
          other.name == this.name &&
          other.language == this.language &&
          other.isGuest == this.isGuest);
}

class UserRecordCompanion extends UpdateCompanion<Users> {
  final Value<String> id;
  final Value<String> email;
  final Value<String> name;
  final Value<String> language;
  final Value<bool> isGuest;
  final Value<int> rowid;
  const UserRecordCompanion({
    this.id = const Value.absent(),
    this.email = const Value.absent(),
    this.name = const Value.absent(),
    this.language = const Value.absent(),
    this.isGuest = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserRecordCompanion.insert({
    required String id,
    required String email,
    required String name,
    this.language = const Value.absent(),
    this.isGuest = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       email = Value(email),
       name = Value(name);
  static Insertable<Users> custom({
    Expression<String>? id,
    Expression<String>? email,
    Expression<String>? name,
    Expression<String>? language,
    Expression<bool>? isGuest,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (email != null) 'email': email,
      if (name != null) 'name': name,
      if (language != null) 'language': language,
      if (isGuest != null) 'is_guest': isGuest,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserRecordCompanion copyWith({
    Value<String>? id,
    Value<String>? email,
    Value<String>? name,
    Value<String>? language,
    Value<bool>? isGuest,
    Value<int>? rowid,
  }) {
    return UserRecordCompanion(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      language: language ?? this.language,
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
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
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
          ..write('email: $email, ')
          ..write('name: $name, ')
          ..write('language: $language, ')
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
  static const VerificationMeta _isStarredMeta = const VerificationMeta(
    'isStarred',
  );
  @override
  late final GeneratedColumn<bool> isStarred = GeneratedColumn<bool>(
    'is_starred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_starred" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: Constant(DateTime.fromMillisecondsSinceEpoch(0)),
  );
  static const VerificationMeta _complexityMeta = const VerificationMeta(
    'complexity',
  );
  @override
  late final GeneratedColumn<double> complexity = GeneratedColumn<double>(
    'complexity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    description,
    shared,
    exercises,
    isStarred,
    createdAt,
    complexity,
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
    if (data.containsKey('is_starred')) {
      context.handle(
        _isStarredMeta,
        isStarred.isAcceptableOrUnknown(data['is_starred']!, _isStarredMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('complexity')) {
      context.handle(
        _complexityMeta,
        complexity.isAcceptableOrUnknown(data['complexity']!, _complexityMeta),
      );
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
      isStarred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_starred'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      complexity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}complexity'],
      )!,
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
  final bool isStarred;
  final DateTime createdAt;
  final double complexity;
  const BreathSessionRow({
    required this.id,
    required this.userId,
    required this.description,
    required this.shared,
    required this.exercises,
    required this.isStarred,
    required this.createdAt,
    required this.complexity,
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
    map['is_starred'] = Variable<bool>(isStarred);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['complexity'] = Variable<double>(complexity);
    return map;
  }

  BreathSessionsCompanion toCompanion(bool nullToAbsent) {
    return BreathSessionsCompanion(
      id: Value(id),
      userId: Value(userId),
      description: Value(description),
      shared: Value(shared),
      exercises: Value(exercises),
      isStarred: Value(isStarred),
      createdAt: Value(createdAt),
      complexity: Value(complexity),
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
      isStarred: serializer.fromJson<bool>(json['isStarred']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      complexity: serializer.fromJson<double>(json['complexity']),
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
      'isStarred': serializer.toJson<bool>(isStarred),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'complexity': serializer.toJson<double>(complexity),
    };
  }

  BreathSessionRow copyWith({
    String? id,
    String? userId,
    String? description,
    bool? shared,
    List<ExerciseSet>? exercises,
    bool? isStarred,
    DateTime? createdAt,
    double? complexity,
  }) => BreathSessionRow(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    description: description ?? this.description,
    shared: shared ?? this.shared,
    exercises: exercises ?? this.exercises,
    isStarred: isStarred ?? this.isStarred,
    createdAt: createdAt ?? this.createdAt,
    complexity: complexity ?? this.complexity,
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
      isStarred: data.isStarred.present ? data.isStarred.value : this.isStarred,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      complexity: data.complexity.present
          ? data.complexity.value
          : this.complexity,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BreathSessionRow(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('description: $description, ')
          ..write('shared: $shared, ')
          ..write('exercises: $exercises, ')
          ..write('isStarred: $isStarred, ')
          ..write('createdAt: $createdAt, ')
          ..write('complexity: $complexity')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    description,
    shared,
    exercises,
    isStarred,
    createdAt,
    complexity,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BreathSessionRow &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.description == this.description &&
          other.shared == this.shared &&
          other.exercises == this.exercises &&
          other.isStarred == this.isStarred &&
          other.createdAt == this.createdAt &&
          other.complexity == this.complexity);
}

class BreathSessionsCompanion extends UpdateCompanion<BreathSessionRow> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> description;
  final Value<bool> shared;
  final Value<List<ExerciseSet>> exercises;
  final Value<bool> isStarred;
  final Value<DateTime> createdAt;
  final Value<double> complexity;
  final Value<int> rowid;
  const BreathSessionsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.description = const Value.absent(),
    this.shared = const Value.absent(),
    this.exercises = const Value.absent(),
    this.isStarred = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.complexity = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BreathSessionsCompanion.insert({
    required String id,
    required String userId,
    required String description,
    required bool shared,
    required List<ExerciseSet> exercises,
    this.isStarred = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.complexity = const Value.absent(),
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
    Expression<bool>? isStarred,
    Expression<DateTime>? createdAt,
    Expression<double>? complexity,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (description != null) 'description': description,
      if (shared != null) 'shared': shared,
      if (exercises != null) 'exercises': exercises,
      if (isStarred != null) 'is_starred': isStarred,
      if (createdAt != null) 'created_at': createdAt,
      if (complexity != null) 'complexity': complexity,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BreathSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? description,
    Value<bool>? shared,
    Value<List<ExerciseSet>>? exercises,
    Value<bool>? isStarred,
    Value<DateTime>? createdAt,
    Value<double>? complexity,
    Value<int>? rowid,
  }) {
    return BreathSessionsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      description: description ?? this.description,
      shared: shared ?? this.shared,
      exercises: exercises ?? this.exercises,
      isStarred: isStarred ?? this.isStarred,
      createdAt: createdAt ?? this.createdAt,
      complexity: complexity ?? this.complexity,
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
    if (isStarred.present) {
      map['is_starred'] = Variable<bool>(isStarred.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (complexity.present) {
      map['complexity'] = Variable<double>(complexity.value);
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
          ..write('isStarred: $isStarred, ')
          ..write('createdAt: $createdAt, ')
          ..write('complexity: $complexity, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateRow extends DataClass implements Insertable<SyncStateRow> {
  final String key;
  final String value;
  const SyncStateRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(key: Value(key), value: Value(value));
  }

  factory SyncStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncStateRow copyWith({String? key, String? value}) =>
      SyncStateRow(key: key ?? this.key, value: value ?? this.value);
  SyncStateRow copyWithCompanion(SyncStateCompanion data) {
    return SyncStateRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncStateRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncStateCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MeditationPosesTable extends MeditationPoses
    with TableInfo<$MeditationPosesTable, MeditationPoseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MeditationPosesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
    'slug',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayOrderMeta = const VerificationMeta(
    'displayOrder',
  );
  @override
  late final GeneratedColumn<int> displayOrder = GeneratedColumn<int>(
    'display_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, slug, displayOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meditation_poses';
  @override
  VerificationContext validateIntegrity(
    Insertable<MeditationPoseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('slug')) {
      context.handle(
        _slugMeta,
        slug.isAcceptableOrUnknown(data['slug']!, _slugMeta),
      );
    } else if (isInserting) {
      context.missing(_slugMeta);
    }
    if (data.containsKey('display_order')) {
      context.handle(
        _displayOrderMeta,
        displayOrder.isAcceptableOrUnknown(
          data['display_order']!,
          _displayOrderMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MeditationPoseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MeditationPoseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      slug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slug'],
      )!,
      displayOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}display_order'],
      )!,
    );
  }

  @override
  $MeditationPosesTable createAlias(String alias) {
    return $MeditationPosesTable(attachedDatabase, alias);
  }
}

class MeditationPoseRow extends DataClass
    implements Insertable<MeditationPoseRow> {
  final String id;
  final String slug;
  final int displayOrder;
  const MeditationPoseRow({
    required this.id,
    required this.slug,
    required this.displayOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['slug'] = Variable<String>(slug);
    map['display_order'] = Variable<int>(displayOrder);
    return map;
  }

  MeditationPosesCompanion toCompanion(bool nullToAbsent) {
    return MeditationPosesCompanion(
      id: Value(id),
      slug: Value(slug),
      displayOrder: Value(displayOrder),
    );
  }

  factory MeditationPoseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MeditationPoseRow(
      id: serializer.fromJson<String>(json['id']),
      slug: serializer.fromJson<String>(json['slug']),
      displayOrder: serializer.fromJson<int>(json['displayOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'slug': serializer.toJson<String>(slug),
      'displayOrder': serializer.toJson<int>(displayOrder),
    };
  }

  MeditationPoseRow copyWith({String? id, String? slug, int? displayOrder}) =>
      MeditationPoseRow(
        id: id ?? this.id,
        slug: slug ?? this.slug,
        displayOrder: displayOrder ?? this.displayOrder,
      );
  MeditationPoseRow copyWithCompanion(MeditationPosesCompanion data) {
    return MeditationPoseRow(
      id: data.id.present ? data.id.value : this.id,
      slug: data.slug.present ? data.slug.value : this.slug,
      displayOrder: data.displayOrder.present
          ? data.displayOrder.value
          : this.displayOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MeditationPoseRow(')
          ..write('id: $id, ')
          ..write('slug: $slug, ')
          ..write('displayOrder: $displayOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, slug, displayOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MeditationPoseRow &&
          other.id == this.id &&
          other.slug == this.slug &&
          other.displayOrder == this.displayOrder);
}

class MeditationPosesCompanion extends UpdateCompanion<MeditationPoseRow> {
  final Value<String> id;
  final Value<String> slug;
  final Value<int> displayOrder;
  final Value<int> rowid;
  const MeditationPosesCompanion({
    this.id = const Value.absent(),
    this.slug = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MeditationPosesCompanion.insert({
    required String id,
    required String slug,
    required int displayOrder,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       slug = Value(slug),
       displayOrder = Value(displayOrder);
  static Insertable<MeditationPoseRow> custom({
    Expression<String>? id,
    Expression<String>? slug,
    Expression<int>? displayOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (slug != null) 'slug': slug,
      if (displayOrder != null) 'display_order': displayOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MeditationPosesCompanion copyWith({
    Value<String>? id,
    Value<String>? slug,
    Value<int>? displayOrder,
    Value<int>? rowid,
  }) {
    return MeditationPosesCompanion(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      displayOrder: displayOrder ?? this.displayOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    if (displayOrder.present) {
      map['display_order'] = Variable<int>(displayOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MeditationPosesCompanion(')
          ..write('id: $id, ')
          ..write('slug: $slug, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MeditationNotesTable extends MeditationNotes
    with TableInfo<$MeditationNotesTable, MeditationNoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MeditationNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _poseIdMeta = const VerificationMeta('poseId');
  @override
  late final GeneratedColumn<String> poseId = GeneratedColumn<String>(
    'pose_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteTextMeta = const VerificationMeta(
    'noteText',
  );
  @override
  late final GeneratedColumn<String> noteText = GeneratedColumn<String>(
    'note_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverSessionIdMeta = const VerificationMeta(
    'serverSessionId',
  );
  @override
  late final GeneratedColumn<String> serverSessionId = GeneratedColumn<String>(
    'server_session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    poseId,
    noteText,
    createdAt,
    serverSessionId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meditation_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<MeditationNoteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('pose_id')) {
      context.handle(
        _poseIdMeta,
        poseId.isAcceptableOrUnknown(data['pose_id']!, _poseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_poseIdMeta);
    }
    if (data.containsKey('note_text')) {
      context.handle(
        _noteTextMeta,
        noteText.isAcceptableOrUnknown(data['note_text']!, _noteTextMeta),
      );
    } else if (isInserting) {
      context.missing(_noteTextMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('server_session_id')) {
      context.handle(
        _serverSessionIdMeta,
        serverSessionId.isAcceptableOrUnknown(
          data['server_session_id']!,
          _serverSessionIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MeditationNoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MeditationNoteRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      poseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pose_id'],
      )!,
      noteText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_text'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      serverSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_session_id'],
      ),
    );
  }

  @override
  $MeditationNotesTable createAlias(String alias) {
    return $MeditationNotesTable(attachedDatabase, alias);
  }
}

class MeditationNoteRow extends DataClass
    implements Insertable<MeditationNoteRow> {
  final String id;
  final String poseId;
  final String noteText;
  final int createdAt;
  final String? serverSessionId;
  const MeditationNoteRow({
    required this.id,
    required this.poseId,
    required this.noteText,
    required this.createdAt,
    this.serverSessionId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['pose_id'] = Variable<String>(poseId);
    map['note_text'] = Variable<String>(noteText);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || serverSessionId != null) {
      map['server_session_id'] = Variable<String>(serverSessionId);
    }
    return map;
  }

  MeditationNotesCompanion toCompanion(bool nullToAbsent) {
    return MeditationNotesCompanion(
      id: Value(id),
      poseId: Value(poseId),
      noteText: Value(noteText),
      createdAt: Value(createdAt),
      serverSessionId: serverSessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSessionId),
    );
  }

  factory MeditationNoteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MeditationNoteRow(
      id: serializer.fromJson<String>(json['id']),
      poseId: serializer.fromJson<String>(json['poseId']),
      noteText: serializer.fromJson<String>(json['noteText']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      serverSessionId: serializer.fromJson<String?>(json['serverSessionId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'poseId': serializer.toJson<String>(poseId),
      'noteText': serializer.toJson<String>(noteText),
      'createdAt': serializer.toJson<int>(createdAt),
      'serverSessionId': serializer.toJson<String?>(serverSessionId),
    };
  }

  MeditationNoteRow copyWith({
    String? id,
    String? poseId,
    String? noteText,
    int? createdAt,
    Value<String?> serverSessionId = const Value.absent(),
  }) => MeditationNoteRow(
    id: id ?? this.id,
    poseId: poseId ?? this.poseId,
    noteText: noteText ?? this.noteText,
    createdAt: createdAt ?? this.createdAt,
    serverSessionId: serverSessionId.present
        ? serverSessionId.value
        : this.serverSessionId,
  );
  MeditationNoteRow copyWithCompanion(MeditationNotesCompanion data) {
    return MeditationNoteRow(
      id: data.id.present ? data.id.value : this.id,
      poseId: data.poseId.present ? data.poseId.value : this.poseId,
      noteText: data.noteText.present ? data.noteText.value : this.noteText,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      serverSessionId: data.serverSessionId.present
          ? data.serverSessionId.value
          : this.serverSessionId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MeditationNoteRow(')
          ..write('id: $id, ')
          ..write('poseId: $poseId, ')
          ..write('noteText: $noteText, ')
          ..write('createdAt: $createdAt, ')
          ..write('serverSessionId: $serverSessionId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, poseId, noteText, createdAt, serverSessionId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MeditationNoteRow &&
          other.id == this.id &&
          other.poseId == this.poseId &&
          other.noteText == this.noteText &&
          other.createdAt == this.createdAt &&
          other.serverSessionId == this.serverSessionId);
}

class MeditationNotesCompanion extends UpdateCompanion<MeditationNoteRow> {
  final Value<String> id;
  final Value<String> poseId;
  final Value<String> noteText;
  final Value<int> createdAt;
  final Value<String?> serverSessionId;
  final Value<int> rowid;
  const MeditationNotesCompanion({
    this.id = const Value.absent(),
    this.poseId = const Value.absent(),
    this.noteText = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.serverSessionId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MeditationNotesCompanion.insert({
    required String id,
    required String poseId,
    required String noteText,
    required int createdAt,
    this.serverSessionId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       poseId = Value(poseId),
       noteText = Value(noteText),
       createdAt = Value(createdAt);
  static Insertable<MeditationNoteRow> custom({
    Expression<String>? id,
    Expression<String>? poseId,
    Expression<String>? noteText,
    Expression<int>? createdAt,
    Expression<String>? serverSessionId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (poseId != null) 'pose_id': poseId,
      if (noteText != null) 'note_text': noteText,
      if (createdAt != null) 'created_at': createdAt,
      if (serverSessionId != null) 'server_session_id': serverSessionId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MeditationNotesCompanion copyWith({
    Value<String>? id,
    Value<String>? poseId,
    Value<String>? noteText,
    Value<int>? createdAt,
    Value<String?>? serverSessionId,
    Value<int>? rowid,
  }) {
    return MeditationNotesCompanion(
      id: id ?? this.id,
      poseId: poseId ?? this.poseId,
      noteText: noteText ?? this.noteText,
      createdAt: createdAt ?? this.createdAt,
      serverSessionId: serverSessionId ?? this.serverSessionId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (poseId.present) {
      map['pose_id'] = Variable<String>(poseId.value);
    }
    if (noteText.present) {
      map['note_text'] = Variable<String>(noteText.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (serverSessionId.present) {
      map['server_session_id'] = Variable<String>(serverSessionId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MeditationNotesCompanion(')
          ..write('id: $id, ')
          ..write('poseId: $poseId, ')
          ..write('noteText: $noteText, ')
          ..write('createdAt: $createdAt, ')
          ..write('serverSessionId: $serverSessionId, ')
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
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final $MeditationPosesTable meditationPoses = $MeditationPosesTable(
    this,
  );
  late final $MeditationNotesTable meditationNotes = $MeditationNotesTable(
    this,
  );
  late final UserDao userDao = UserDao(this as Database);
  late final BreathSessionDao breathSessionDao = BreathSessionDao(
    this as Database,
  );
  late final SyncStateDao syncStateDao = SyncStateDao(this as Database);
  late final MeditationPosesDao meditationPosesDao = MeditationPosesDao(
    this as Database,
  );
  late final MeditationNotesDao meditationNotesDao = MeditationNotesDao(
    this as Database,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    userRecord,
    breathSessions,
    syncState,
    meditationPoses,
    meditationNotes,
  ];
}

typedef $$UserRecordTableCreateCompanionBuilder =
    UserRecordCompanion Function({
      required String id,
      required String email,
      required String name,
      Value<String> language,
      Value<bool> isGuest,
      Value<int> rowid,
    });
typedef $$UserRecordTableUpdateCompanionBuilder =
    UserRecordCompanion Function({
      Value<String> id,
      Value<String> email,
      Value<String> name,
      Value<String> language,
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

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
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

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
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

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

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
                Value<String> email = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<bool> isGuest = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserRecordCompanion(
                id: id,
                email: email,
                name: name,
                language: language,
                isGuest: isGuest,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String email,
                required String name,
                Value<String> language = const Value.absent(),
                Value<bool> isGuest = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserRecordCompanion.insert(
                id: id,
                email: email,
                name: name,
                language: language,
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
      Value<bool> isStarred,
      Value<DateTime> createdAt,
      Value<double> complexity,
      Value<int> rowid,
    });
typedef $$BreathSessionsTableUpdateCompanionBuilder =
    BreathSessionsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> description,
      Value<bool> shared,
      Value<List<ExerciseSet>> exercises,
      Value<bool> isStarred,
      Value<DateTime> createdAt,
      Value<double> complexity,
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

  ColumnFilters<bool> get isStarred => $composableBuilder(
    column: $table.isStarred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get complexity => $composableBuilder(
    column: $table.complexity,
    builder: (column) => ColumnFilters(column),
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

  ColumnOrderings<bool> get isStarred => $composableBuilder(
    column: $table.isStarred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get complexity => $composableBuilder(
    column: $table.complexity,
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

  GeneratedColumn<bool> get isStarred =>
      $composableBuilder(column: $table.isStarred, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<double> get complexity => $composableBuilder(
    column: $table.complexity,
    builder: (column) => column,
  );
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
                Value<bool> isStarred = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<double> complexity = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BreathSessionsCompanion(
                id: id,
                userId: userId,
                description: description,
                shared: shared,
                exercises: exercises,
                isStarred: isStarred,
                createdAt: createdAt,
                complexity: complexity,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String description,
                required bool shared,
                required List<ExerciseSet> exercises,
                Value<bool> isStarred = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<double> complexity = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BreathSessionsCompanion.insert(
                id: id,
                userId: userId,
                description: description,
                shared: shared,
                exercises: exercises,
                isStarred: isStarred,
                createdAt: createdAt,
                complexity: complexity,
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
typedef $$SyncStateTableCreateCompanionBuilder =
    SyncStateCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SyncStateTableUpdateCompanionBuilder =
    SyncStateCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SyncStateTableFilterComposer
    extends Composer<_$Database, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$Database, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$Database, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$Database,
          $SyncStateTable,
          SyncStateRow,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateRow,
            BaseReferences<_$Database, $SyncStateTable, SyncStateRow>,
          ),
          SyncStateRow,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$Database db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$Database,
      $SyncStateTable,
      SyncStateRow,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (SyncStateRow, BaseReferences<_$Database, $SyncStateTable, SyncStateRow>),
      SyncStateRow,
      PrefetchHooks Function()
    >;
typedef $$MeditationPosesTableCreateCompanionBuilder =
    MeditationPosesCompanion Function({
      required String id,
      required String slug,
      required int displayOrder,
      Value<int> rowid,
    });
typedef $$MeditationPosesTableUpdateCompanionBuilder =
    MeditationPosesCompanion Function({
      Value<String> id,
      Value<String> slug,
      Value<int> displayOrder,
      Value<int> rowid,
    });

class $$MeditationPosesTableFilterComposer
    extends Composer<_$Database, $MeditationPosesTable> {
  $$MeditationPosesTableFilterComposer({
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

  ColumnFilters<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MeditationPosesTableOrderingComposer
    extends Composer<_$Database, $MeditationPosesTable> {
  $$MeditationPosesTableOrderingComposer({
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

  ColumnOrderings<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MeditationPosesTableAnnotationComposer
    extends Composer<_$Database, $MeditationPosesTable> {
  $$MeditationPosesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);

  GeneratedColumn<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => column,
  );
}

class $$MeditationPosesTableTableManager
    extends
        RootTableManager<
          _$Database,
          $MeditationPosesTable,
          MeditationPoseRow,
          $$MeditationPosesTableFilterComposer,
          $$MeditationPosesTableOrderingComposer,
          $$MeditationPosesTableAnnotationComposer,
          $$MeditationPosesTableCreateCompanionBuilder,
          $$MeditationPosesTableUpdateCompanionBuilder,
          (
            MeditationPoseRow,
            BaseReferences<
              _$Database,
              $MeditationPosesTable,
              MeditationPoseRow
            >,
          ),
          MeditationPoseRow,
          PrefetchHooks Function()
        > {
  $$MeditationPosesTableTableManager(_$Database db, $MeditationPosesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MeditationPosesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MeditationPosesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MeditationPosesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> slug = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MeditationPosesCompanion(
                id: id,
                slug: slug,
                displayOrder: displayOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String slug,
                required int displayOrder,
                Value<int> rowid = const Value.absent(),
              }) => MeditationPosesCompanion.insert(
                id: id,
                slug: slug,
                displayOrder: displayOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MeditationPosesTableProcessedTableManager =
    ProcessedTableManager<
      _$Database,
      $MeditationPosesTable,
      MeditationPoseRow,
      $$MeditationPosesTableFilterComposer,
      $$MeditationPosesTableOrderingComposer,
      $$MeditationPosesTableAnnotationComposer,
      $$MeditationPosesTableCreateCompanionBuilder,
      $$MeditationPosesTableUpdateCompanionBuilder,
      (
        MeditationPoseRow,
        BaseReferences<_$Database, $MeditationPosesTable, MeditationPoseRow>,
      ),
      MeditationPoseRow,
      PrefetchHooks Function()
    >;
typedef $$MeditationNotesTableCreateCompanionBuilder =
    MeditationNotesCompanion Function({
      required String id,
      required String poseId,
      required String noteText,
      required int createdAt,
      Value<String?> serverSessionId,
      Value<int> rowid,
    });
typedef $$MeditationNotesTableUpdateCompanionBuilder =
    MeditationNotesCompanion Function({
      Value<String> id,
      Value<String> poseId,
      Value<String> noteText,
      Value<int> createdAt,
      Value<String?> serverSessionId,
      Value<int> rowid,
    });

class $$MeditationNotesTableFilterComposer
    extends Composer<_$Database, $MeditationNotesTable> {
  $$MeditationNotesTableFilterComposer({
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

  ColumnFilters<String> get poseId => $composableBuilder(
    column: $table.poseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noteText => $composableBuilder(
    column: $table.noteText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverSessionId => $composableBuilder(
    column: $table.serverSessionId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MeditationNotesTableOrderingComposer
    extends Composer<_$Database, $MeditationNotesTable> {
  $$MeditationNotesTableOrderingComposer({
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

  ColumnOrderings<String> get poseId => $composableBuilder(
    column: $table.poseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noteText => $composableBuilder(
    column: $table.noteText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverSessionId => $composableBuilder(
    column: $table.serverSessionId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MeditationNotesTableAnnotationComposer
    extends Composer<_$Database, $MeditationNotesTable> {
  $$MeditationNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get poseId =>
      $composableBuilder(column: $table.poseId, builder: (column) => column);

  GeneratedColumn<String> get noteText =>
      $composableBuilder(column: $table.noteText, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get serverSessionId => $composableBuilder(
    column: $table.serverSessionId,
    builder: (column) => column,
  );
}

class $$MeditationNotesTableTableManager
    extends
        RootTableManager<
          _$Database,
          $MeditationNotesTable,
          MeditationNoteRow,
          $$MeditationNotesTableFilterComposer,
          $$MeditationNotesTableOrderingComposer,
          $$MeditationNotesTableAnnotationComposer,
          $$MeditationNotesTableCreateCompanionBuilder,
          $$MeditationNotesTableUpdateCompanionBuilder,
          (
            MeditationNoteRow,
            BaseReferences<
              _$Database,
              $MeditationNotesTable,
              MeditationNoteRow
            >,
          ),
          MeditationNoteRow,
          PrefetchHooks Function()
        > {
  $$MeditationNotesTableTableManager(_$Database db, $MeditationNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MeditationNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MeditationNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MeditationNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> poseId = const Value.absent(),
                Value<String> noteText = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String?> serverSessionId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MeditationNotesCompanion(
                id: id,
                poseId: poseId,
                noteText: noteText,
                createdAt: createdAt,
                serverSessionId: serverSessionId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String poseId,
                required String noteText,
                required int createdAt,
                Value<String?> serverSessionId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MeditationNotesCompanion.insert(
                id: id,
                poseId: poseId,
                noteText: noteText,
                createdAt: createdAt,
                serverSessionId: serverSessionId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MeditationNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$Database,
      $MeditationNotesTable,
      MeditationNoteRow,
      $$MeditationNotesTableFilterComposer,
      $$MeditationNotesTableOrderingComposer,
      $$MeditationNotesTableAnnotationComposer,
      $$MeditationNotesTableCreateCompanionBuilder,
      $$MeditationNotesTableUpdateCompanionBuilder,
      (
        MeditationNoteRow,
        BaseReferences<_$Database, $MeditationNotesTable, MeditationNoteRow>,
      ),
      MeditationNoteRow,
      PrefetchHooks Function()
    >;

class $DatabaseManager {
  final _$Database _db;
  $DatabaseManager(this._db);
  $$UserRecordTableTableManager get userRecord =>
      $$UserRecordTableTableManager(_db, _db.userRecord);
  $$BreathSessionsTableTableManager get breathSessions =>
      $$BreathSessionsTableTableManager(_db, _db.breathSessions);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
  $$MeditationPosesTableTableManager get meditationPoses =>
      $$MeditationPosesTableTableManager(_db, _db.meditationPoses);
  $$MeditationNotesTableTableManager get meditationNotes =>
      $$MeditationNotesTableTableManager(_db, _db.meditationNotes);
}

mixin _$UserDaoMixin on DatabaseAccessor<Database> {
  $UserRecordTable get userRecord => attachedDatabase.userRecord;
}
mixin _$BreathSessionDaoMixin on DatabaseAccessor<Database> {
  $BreathSessionsTable get breathSessions => attachedDatabase.breathSessions;
}
mixin _$SyncStateDaoMixin on DatabaseAccessor<Database> {
  $SyncStateTable get syncState => attachedDatabase.syncState;
}
mixin _$MeditationPosesDaoMixin on DatabaseAccessor<Database> {
  $MeditationPosesTable get meditationPoses => attachedDatabase.meditationPoses;
}
mixin _$MeditationNotesDaoMixin on DatabaseAccessor<Database> {
  $MeditationNotesTable get meditationNotes => attachedDatabase.meditationNotes;
}
