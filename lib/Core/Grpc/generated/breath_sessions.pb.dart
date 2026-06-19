// This is a generated file - do not edit.
//
// Generated from breath_sessions.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'breath_sessions.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'breath_sessions.pbenum.dart';

/// Maps to BreathStep interface in src/breath-sessions/entities/breath-session.entity.ts
/// duration is in seconds.
class StepDto extends $pb.GeneratedMessage {
  factory StepDto({
    StepType? type,
    $core.double? duration,
  }) {
    final result = create();
    if (type != null) result.type = type;
    if (duration != null) result.duration = duration;
    return result;
  }

  StepDto._();

  factory StepDto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StepDto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StepDto',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aE<StepType>(1, _omitFieldNames ? '' : 'type',
        enumValues: StepType.values)
    ..aD(2, _omitFieldNames ? '' : 'duration')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StepDto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StepDto copyWith(void Function(StepDto) updates) =>
      super.copyWith((message) => updates(message as StepDto)) as StepDto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StepDto create() => StepDto._();
  @$core.override
  StepDto createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StepDto getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StepDto>(create);
  static StepDto? _defaultInstance;

  @$pb.TagNumber(1)
  StepType get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(StepType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get duration => $_getN(1);
  @$pb.TagNumber(2)
  set duration($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDuration() => $_has(1);
  @$pb.TagNumber(2)
  void clearDuration() => $_clearField(2);
}

/// Maps to BreathExercise interface in src/breath-sessions/entities/breath-session.entity.ts.
/// An exercise with empty steps acts as a rest separator between exercise blocks.
class ExerciseDto extends $pb.GeneratedMessage {
  factory ExerciseDto({
    $core.Iterable<StepDto>? steps,
    $core.double? restDuration,
    $core.int? repeatCount,
  }) {
    final result = create();
    if (steps != null) result.steps.addAll(steps);
    if (restDuration != null) result.restDuration = restDuration;
    if (repeatCount != null) result.repeatCount = repeatCount;
    return result;
  }

  ExerciseDto._();

  factory ExerciseDto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExerciseDto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExerciseDto',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..pPM<StepDto>(1, _omitFieldNames ? '' : 'steps',
        subBuilder: StepDto.create)
    ..aD(2, _omitFieldNames ? '' : 'restDuration')
    ..aI(3, _omitFieldNames ? '' : 'repeatCount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExerciseDto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExerciseDto copyWith(void Function(ExerciseDto) updates) =>
      super.copyWith((message) => updates(message as ExerciseDto))
          as ExerciseDto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExerciseDto create() => ExerciseDto._();
  @$core.override
  ExerciseDto createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExerciseDto getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExerciseDto>(create);
  static ExerciseDto? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<StepDto> get steps => $_getList(0);

  @$pb.TagNumber(2)
  $core.double get restDuration => $_getN(1);
  @$pb.TagNumber(2)
  set restDuration($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRestDuration() => $_has(1);
  @$pb.TagNumber(2)
  void clearRestDuration() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get repeatCount => $_getIZ(2);
  @$pb.TagNumber(3)
  set repeatCount($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRepeatCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearRepeatCount() => $_clearField(3);
}

/// Wrapper for repeated ExerciseDto to support PATCH presence tracking in UpdateSessionRequest.
/// proto3 optional cannot be applied to repeated fields; wrapping the list in a message
/// gives presence tracking via has_exercises, so the server can distinguish
/// "field not sent" (don't change) from "sent with empty list" (clear all exercises).
class ExerciseList extends $pb.GeneratedMessage {
  factory ExerciseList({
    $core.Iterable<ExerciseDto>? exercises,
  }) {
    final result = create();
    if (exercises != null) result.exercises.addAll(exercises);
    return result;
  }

  ExerciseList._();

  factory ExerciseList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExerciseList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExerciseList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..pPM<ExerciseDto>(1, _omitFieldNames ? '' : 'exercises',
        subBuilder: ExerciseDto.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExerciseList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExerciseList copyWith(void Function(ExerciseList) updates) =>
      super.copyWith((message) => updates(message as ExerciseList))
          as ExerciseList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExerciseList create() => ExerciseList._();
  @$core.override
  ExerciseList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExerciseList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExerciseList>(create);
  static ExerciseList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ExerciseDto> get exercises => $_getList(0);
}

/// Maps to BreathSession entity in src/breath-sessions/entities/breath-session.entity.ts.
/// Timestamps are ISO-8601 strings for cross-language simplicity (same convention as TokenDto in auth.proto).
/// complexity is computed server-side and is read-only in responses.
class BreathSessionDto extends $pb.GeneratedMessage {
  factory BreathSessionDto({
    $core.String? id,
    $core.String? userId,
    $core.String? description,
    $core.Iterable<ExerciseDto>? exercises,
    $core.double? complexity,
    $core.bool? shared,
    TimeOfDay? timeOfDay,
    $core.String? createdAt,
    $core.String? updatedAt,
    $core.String? deletedAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (userId != null) result.userId = userId;
    if (description != null) result.description = description;
    if (exercises != null) result.exercises.addAll(exercises);
    if (complexity != null) result.complexity = complexity;
    if (shared != null) result.shared = shared;
    if (timeOfDay != null) result.timeOfDay = timeOfDay;
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    if (deletedAt != null) result.deletedAt = deletedAt;
    return result;
  }

  BreathSessionDto._();

  factory BreathSessionDto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BreathSessionDto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BreathSessionDto',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..pPM<ExerciseDto>(4, _omitFieldNames ? '' : 'exercises',
        subBuilder: ExerciseDto.create)
    ..aD(5, _omitFieldNames ? '' : 'complexity')
    ..aOB(6, _omitFieldNames ? '' : 'shared')
    ..aE<TimeOfDay>(7, _omitFieldNames ? '' : 'timeOfDay',
        enumValues: TimeOfDay.values)
    ..aOS(8, _omitFieldNames ? '' : 'createdAt')
    ..aOS(9, _omitFieldNames ? '' : 'updatedAt')
    ..aOS(10, _omitFieldNames ? '' : 'deletedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BreathSessionDto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BreathSessionDto copyWith(void Function(BreathSessionDto) updates) =>
      super.copyWith((message) => updates(message as BreathSessionDto))
          as BreathSessionDto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BreathSessionDto create() => BreathSessionDto._();
  @$core.override
  BreathSessionDto createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BreathSessionDto getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BreathSessionDto>(create);
  static BreathSessionDto? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<ExerciseDto> get exercises => $_getList(3);

  @$pb.TagNumber(5)
  $core.double get complexity => $_getN(4);
  @$pb.TagNumber(5)
  set complexity($core.double value) => $_setDouble(4, value);
  @$pb.TagNumber(5)
  $core.bool hasComplexity() => $_has(4);
  @$pb.TagNumber(5)
  void clearComplexity() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get shared => $_getBF(5);
  @$pb.TagNumber(6)
  set shared($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasShared() => $_has(5);
  @$pb.TagNumber(6)
  void clearShared() => $_clearField(6);

  @$pb.TagNumber(7)
  TimeOfDay get timeOfDay => $_getN(6);
  @$pb.TagNumber(7)
  set timeOfDay(TimeOfDay value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasTimeOfDay() => $_has(6);
  @$pb.TagNumber(7)
  void clearTimeOfDay() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get createdAt => $_getSZ(7);
  @$pb.TagNumber(8)
  set createdAt($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCreatedAt() => $_has(7);
  @$pb.TagNumber(8)
  void clearCreatedAt() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get updatedAt => $_getSZ(8);
  @$pb.TagNumber(9)
  set updatedAt($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasUpdatedAt() => $_has(8);
  @$pb.TagNumber(9)
  void clearUpdatedAt() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get deletedAt => $_getSZ(9);
  @$pb.TagNumber(10)
  set deletedAt($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasDeletedAt() => $_has(9);
  @$pb.TagNumber(10)
  void clearDeletedAt() => $_clearField(10);
}

/// Maps to BreathSessionWithStarredDto in src/breath-sessions/dto/breath-session.dto.ts.
/// Uses composition instead of duplicating all fields: any new field added to BreathSessionDto
/// is inherited automatically, avoiding silent contract drift.
/// is_starred is present only when the caller is authenticated.
class BreathSessionWithStarredDto extends $pb.GeneratedMessage {
  factory BreathSessionWithStarredDto({
    BreathSessionDto? session,
    $core.bool? isStarred,
  }) {
    final result = create();
    if (session != null) result.session = session;
    if (isStarred != null) result.isStarred = isStarred;
    return result;
  }

  BreathSessionWithStarredDto._();

  factory BreathSessionWithStarredDto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BreathSessionWithStarredDto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BreathSessionWithStarredDto',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOM<BreathSessionDto>(1, _omitFieldNames ? '' : 'session',
        subBuilder: BreathSessionDto.create)
    ..aOB(2, _omitFieldNames ? '' : 'isStarred')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BreathSessionWithStarredDto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BreathSessionWithStarredDto copyWith(
          void Function(BreathSessionWithStarredDto) updates) =>
      super.copyWith(
              (message) => updates(message as BreathSessionWithStarredDto))
          as BreathSessionWithStarredDto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BreathSessionWithStarredDto create() =>
      BreathSessionWithStarredDto._();
  @$core.override
  BreathSessionWithStarredDto createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BreathSessionWithStarredDto getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BreathSessionWithStarredDto>(create);
  static BreathSessionWithStarredDto? _defaultInstance;

  @$pb.TagNumber(1)
  BreathSessionDto get session => $_getN(0);
  @$pb.TagNumber(1)
  set session(BreathSessionDto value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);
  @$pb.TagNumber(1)
  BreathSessionDto ensureSession() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.bool get isStarred => $_getBF(1);
  @$pb.TagNumber(2)
  set isStarred($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIsStarred() => $_has(1);
  @$pb.TagNumber(2)
  void clearIsStarred() => $_clearField(2);
}

/// Wraps a session with its section so the client can render grouped lists.
class SessionListItem extends $pb.GeneratedMessage {
  factory SessionListItem({
    BreathSessionWithStarredDto? session,
    SessionSection? section,
  }) {
    final result = create();
    if (session != null) result.session = session;
    if (section != null) result.section = section;
    return result;
  }

  SessionListItem._();

  factory SessionListItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SessionListItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionListItem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOM<BreathSessionWithStarredDto>(1, _omitFieldNames ? '' : 'session',
        subBuilder: BreathSessionWithStarredDto.create)
    ..aE<SessionSection>(2, _omitFieldNames ? '' : 'section',
        enumValues: SessionSection.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionListItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionListItem copyWith(void Function(SessionListItem) updates) =>
      super.copyWith((message) => updates(message as SessionListItem))
          as SessionListItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SessionListItem create() => SessionListItem._();
  @$core.override
  SessionListItem createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SessionListItem getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SessionListItem>(create);
  static SessionListItem? _defaultInstance;

  @$pb.TagNumber(1)
  BreathSessionWithStarredDto get session => $_getN(0);
  @$pb.TagNumber(1)
  set session(BreathSessionWithStarredDto value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);
  @$pb.TagNumber(1)
  BreathSessionWithStarredDto ensureSession() => $_ensure(0);

  @$pb.TagNumber(2)
  SessionSection get section => $_getN(1);
  @$pb.TagNumber(2)
  set section(SessionSection value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSection() => $_has(1);
  @$pb.TagNumber(2)
  void clearSection() => $_clearField(2);
}

/// CreateSession — maps to CreateBreathSessionDto in src/breath-sessions/dto/breath-session.dto.ts.
/// Auth identity comes from metadata/interceptor, not the message.
class CreateSessionRequest extends $pb.GeneratedMessage {
  factory CreateSessionRequest({
    $core.String? description,
    $core.Iterable<ExerciseDto>? exercises,
    $core.bool? shared,
    TimeOfDay? timeOfDay,
  }) {
    final result = create();
    if (description != null) result.description = description;
    if (exercises != null) result.exercises.addAll(exercises);
    if (shared != null) result.shared = shared;
    if (timeOfDay != null) result.timeOfDay = timeOfDay;
    return result;
  }

  CreateSessionRequest._();

  factory CreateSessionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateSessionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateSessionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'description')
    ..pPM<ExerciseDto>(2, _omitFieldNames ? '' : 'exercises',
        subBuilder: ExerciseDto.create)
    ..aOB(3, _omitFieldNames ? '' : 'shared')
    ..aE<TimeOfDay>(4, _omitFieldNames ? '' : 'timeOfDay',
        enumValues: TimeOfDay.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateSessionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateSessionRequest copyWith(void Function(CreateSessionRequest) updates) =>
      super.copyWith((message) => updates(message as CreateSessionRequest))
          as CreateSessionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateSessionRequest create() => CreateSessionRequest._();
  @$core.override
  CreateSessionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateSessionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateSessionRequest>(create);
  static CreateSessionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get description => $_getSZ(0);
  @$pb.TagNumber(1)
  set description($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDescription() => $_has(0);
  @$pb.TagNumber(1)
  void clearDescription() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<ExerciseDto> get exercises => $_getList(1);

  @$pb.TagNumber(3)
  $core.bool get shared => $_getBF(2);
  @$pb.TagNumber(3)
  set shared($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasShared() => $_has(2);
  @$pb.TagNumber(3)
  void clearShared() => $_clearField(3);

  @$pb.TagNumber(4)
  TimeOfDay get timeOfDay => $_getN(3);
  @$pb.TagNumber(4)
  set timeOfDay(TimeOfDay value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasTimeOfDay() => $_has(3);
  @$pb.TagNumber(4)
  void clearTimeOfDay() => $_clearField(4);
}

/// UpdateSession — maps to UpdateBreathSessionDto in src/breath-sessions/dto/breath-session.dto.ts.
/// PATCH semantics: only provided fields are updated.
/// exercises uses the ExerciseList wrapper so proto3 presence tracking can distinguish
/// "not sent" (don't change) from "sent with empty list" (clear all exercises).
class UpdateSessionRequest extends $pb.GeneratedMessage {
  factory UpdateSessionRequest({
    $core.String? id,
    $core.String? description,
    ExerciseList? exercises,
    $core.bool? shared,
    TimeOfDay? timeOfDay,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (description != null) result.description = description;
    if (exercises != null) result.exercises = exercises;
    if (shared != null) result.shared = shared;
    if (timeOfDay != null) result.timeOfDay = timeOfDay;
    return result;
  }

  UpdateSessionRequest._();

  factory UpdateSessionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateSessionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateSessionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'description')
    ..aOM<ExerciseList>(3, _omitFieldNames ? '' : 'exercises',
        subBuilder: ExerciseList.create)
    ..aOB(4, _omitFieldNames ? '' : 'shared')
    ..aE<TimeOfDay>(5, _omitFieldNames ? '' : 'timeOfDay',
        enumValues: TimeOfDay.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateSessionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateSessionRequest copyWith(void Function(UpdateSessionRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateSessionRequest))
          as UpdateSessionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateSessionRequest create() => UpdateSessionRequest._();
  @$core.override
  UpdateSessionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateSessionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateSessionRequest>(create);
  static UpdateSessionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get description => $_getSZ(1);
  @$pb.TagNumber(2)
  set description($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDescription() => $_has(1);
  @$pb.TagNumber(2)
  void clearDescription() => $_clearField(2);

  @$pb.TagNumber(3)
  ExerciseList get exercises => $_getN(2);
  @$pb.TagNumber(3)
  set exercises(ExerciseList value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasExercises() => $_has(2);
  @$pb.TagNumber(3)
  void clearExercises() => $_clearField(3);
  @$pb.TagNumber(3)
  ExerciseList ensureExercises() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.bool get shared => $_getBF(3);
  @$pb.TagNumber(4)
  set shared($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasShared() => $_has(3);
  @$pb.TagNumber(4)
  void clearShared() => $_clearField(4);

  @$pb.TagNumber(5)
  TimeOfDay get timeOfDay => $_getN(4);
  @$pb.TagNumber(5)
  set timeOfDay(TimeOfDay value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasTimeOfDay() => $_has(4);
  @$pb.TagNumber(5)
  void clearTimeOfDay() => $_clearField(5);
}

/// UpdateSessionSettings — maps to UpdateBreathSessionSettingsDto in src/breath-sessions/dto/breath-session-settings.dto.ts
class UpdateSessionSettingsRequest extends $pb.GeneratedMessage {
  factory UpdateSessionSettingsRequest({
    $core.String? id,
    $core.bool? starred,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (starred != null) result.starred = starred;
    return result;
  }

  UpdateSessionSettingsRequest._();

  factory UpdateSessionSettingsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateSessionSettingsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateSessionSettingsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOB(2, _omitFieldNames ? '' : 'starred')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateSessionSettingsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateSessionSettingsRequest copyWith(
          void Function(UpdateSessionSettingsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as UpdateSessionSettingsRequest))
          as UpdateSessionSettingsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateSessionSettingsRequest create() =>
      UpdateSessionSettingsRequest._();
  @$core.override
  UpdateSessionSettingsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateSessionSettingsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateSessionSettingsRequest>(create);
  static UpdateSessionSettingsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get starred => $_getBF(1);
  @$pb.TagNumber(2)
  set starred($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStarred() => $_has(1);
  @$pb.TagNumber(2)
  void clearStarred() => $_clearField(2);
}

/// Maps to BreathSessionSettingsResponseDto in src/breath-sessions/dto/breath-session-settings.dto.ts
class UpdateSessionSettingsResponse extends $pb.GeneratedMessage {
  factory UpdateSessionSettingsResponse({
    $core.bool? starred,
  }) {
    final result = create();
    if (starred != null) result.starred = starred;
    return result;
  }

  UpdateSessionSettingsResponse._();

  factory UpdateSessionSettingsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateSessionSettingsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateSessionSettingsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'starred')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateSessionSettingsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateSessionSettingsResponse copyWith(
          void Function(UpdateSessionSettingsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as UpdateSessionSettingsResponse))
          as UpdateSessionSettingsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateSessionSettingsResponse create() =>
      UpdateSessionSettingsResponse._();
  @$core.override
  UpdateSessionSettingsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateSessionSettingsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateSessionSettingsResponse>(create);
  static UpdateSessionSettingsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get starred => $_getBF(0);
  @$pb.TagNumber(1)
  set starred($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStarred() => $_has(0);
  @$pb.TagNumber(1)
  void clearStarred() => $_clearField(1);
}

/// DeleteSession
class DeleteSessionRequest extends $pb.GeneratedMessage {
  factory DeleteSessionRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeleteSessionRequest._();

  factory DeleteSessionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteSessionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteSessionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSessionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSessionRequest copyWith(void Function(DeleteSessionRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteSessionRequest))
          as DeleteSessionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteSessionRequest create() => DeleteSessionRequest._();
  @$core.override
  DeleteSessionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteSessionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteSessionRequest>(create);
  static DeleteSessionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class DeleteSessionResponse extends $pb.GeneratedMessage {
  factory DeleteSessionResponse({
    $core.String? message,
  }) {
    final result = create();
    if (message != null) result.message = message;
    return result;
  }

  DeleteSessionResponse._();

  factory DeleteSessionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteSessionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteSessionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSessionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSessionResponse copyWith(
          void Function(DeleteSessionResponse) updates) =>
      super.copyWith((message) => updates(message as DeleteSessionResponse))
          as DeleteSessionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteSessionResponse create() => DeleteSessionResponse._();
  @$core.override
  DeleteSessionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteSessionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteSessionResponse>(create);
  static DeleteSessionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get message => $_getSZ(0);
  @$pb.TagNumber(1)
  set message($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => $_clearField(1);
}

/// ListSessions — cursor-based pagination.
/// Auth is optional: anonymous users see shared sessions only; authenticated users
/// receive is_starred on each item and the full STARRED/MINE/SHARED grouping.
class ListSessionsRequest extends $pb.GeneratedMessage {
  factory ListSessionsRequest({
    $core.String? cursor,
    $core.int? pageSize,
  }) {
    final result = create();
    if (cursor != null) result.cursor = cursor;
    if (pageSize != null) result.pageSize = pageSize;
    return result;
  }

  ListSessionsRequest._();

  factory ListSessionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListSessionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListSessionsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'cursor')
    ..aI(2, _omitFieldNames ? '' : 'pageSize')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSessionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSessionsRequest copyWith(void Function(ListSessionsRequest) updates) =>
      super.copyWith((message) => updates(message as ListSessionsRequest))
          as ListSessionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListSessionsRequest create() => ListSessionsRequest._();
  @$core.override
  ListSessionsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListSessionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListSessionsRequest>(create);
  static ListSessionsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get cursor => $_getSZ(0);
  @$pb.TagNumber(1)
  set cursor($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCursor() => $_has(0);
  @$pb.TagNumber(1)
  void clearCursor() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get pageSize => $_getIZ(1);
  @$pb.TagNumber(2)
  set pageSize($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPageSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearPageSize() => $_clearField(2);
}

class ListSessionsResponse extends $pb.GeneratedMessage {
  factory ListSessionsResponse({
    $core.Iterable<SessionListItem>? items,
    $core.String? nextCursor,
  }) {
    final result = create();
    if (items != null) result.items.addAll(items);
    if (nextCursor != null) result.nextCursor = nextCursor;
    return result;
  }

  ListSessionsResponse._();

  factory ListSessionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListSessionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListSessionsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..pPM<SessionListItem>(1, _omitFieldNames ? '' : 'items',
        subBuilder: SessionListItem.create)
    ..aOS(2, _omitFieldNames ? '' : 'nextCursor')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSessionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSessionsResponse copyWith(void Function(ListSessionsResponse) updates) =>
      super.copyWith((message) => updates(message as ListSessionsResponse))
          as ListSessionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListSessionsResponse create() => ListSessionsResponse._();
  @$core.override
  ListSessionsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListSessionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListSessionsResponse>(create);
  static ListSessionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<SessionListItem> get items => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get nextCursor => $_getSZ(1);
  @$pb.TagNumber(2)
  set nextCursor($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNextCursor() => $_has(1);
  @$pb.TagNumber(2)
  void clearNextCursor() => $_clearField(2);
}

/// GetSession — auth optional: authenticated users receive is_starred in the response.
class GetSessionRequest extends $pb.GeneratedMessage {
  factory GetSessionRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  GetSessionRequest._();

  factory GetSessionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetSessionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSessionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSessionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSessionRequest copyWith(void Function(GetSessionRequest) updates) =>
      super.copyWith((message) => updates(message as GetSessionRequest))
          as GetSessionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetSessionRequest create() => GetSessionRequest._();
  @$core.override
  GetSessionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetSessionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetSessionRequest>(create);
  static GetSessionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

/// GetSuggestions — maps to SuggestionsQueryDto in src/breath-sessions/dto/breath-session.dto.ts.
/// Requires auth — uses the caller's stats for the complexity baseline.
class GetSuggestionsRequest extends $pb.GeneratedMessage {
  factory GetSuggestionsRequest({
    TimeOfDay? timeOfDay,
  }) {
    final result = create();
    if (timeOfDay != null) result.timeOfDay = timeOfDay;
    return result;
  }

  GetSuggestionsRequest._();

  factory GetSuggestionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetSuggestionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSuggestionsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aE<TimeOfDay>(1, _omitFieldNames ? '' : 'timeOfDay',
        enumValues: TimeOfDay.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSuggestionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSuggestionsRequest copyWith(
          void Function(GetSuggestionsRequest) updates) =>
      super.copyWith((message) => updates(message as GetSuggestionsRequest))
          as GetSuggestionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetSuggestionsRequest create() => GetSuggestionsRequest._();
  @$core.override
  GetSuggestionsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetSuggestionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetSuggestionsRequest>(create);
  static GetSuggestionsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  TimeOfDay get timeOfDay => $_getN(0);
  @$pb.TagNumber(1)
  set timeOfDay(TimeOfDay value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTimeOfDay() => $_has(0);
  @$pb.TagNumber(1)
  void clearTimeOfDay() => $_clearField(1);
}

/// Returns up to 4 sessions. Suggestions endpoint does not attach is_starred —
/// the service returns plain BreathSession[].
class GetSuggestionsResponse extends $pb.GeneratedMessage {
  factory GetSuggestionsResponse({
    $core.Iterable<BreathSessionDto>? suggestions,
  }) {
    final result = create();
    if (suggestions != null) result.suggestions.addAll(suggestions);
    return result;
  }

  GetSuggestionsResponse._();

  factory GetSuggestionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetSuggestionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSuggestionsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..pPM<BreathSessionDto>(1, _omitFieldNames ? '' : 'suggestions',
        subBuilder: BreathSessionDto.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSuggestionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSuggestionsResponse copyWith(
          void Function(GetSuggestionsResponse) updates) =>
      super.copyWith((message) => updates(message as GetSuggestionsResponse))
          as GetSuggestionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetSuggestionsResponse create() => GetSuggestionsResponse._();
  @$core.override
  GetSuggestionsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetSuggestionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetSuggestionsResponse>(create);
  static GetSuggestionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<BreathSessionDto> get suggestions => $_getList(0);
}

/// BatchGetSessions — maps to BatchQueryDto in src/breath-sessions/dto/breath-session.dto.ts.
/// Auth optional; maximum 50 IDs per request.
class BatchGetSessionsRequest extends $pb.GeneratedMessage {
  factory BatchGetSessionsRequest({
    $core.Iterable<$core.String>? ids,
  }) {
    final result = create();
    if (ids != null) result.ids.addAll(ids);
    return result;
  }

  BatchGetSessionsRequest._();

  factory BatchGetSessionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BatchGetSessionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BatchGetSessionsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'ids')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchGetSessionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchGetSessionsRequest copyWith(
          void Function(BatchGetSessionsRequest) updates) =>
      super.copyWith((message) => updates(message as BatchGetSessionsRequest))
          as BatchGetSessionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BatchGetSessionsRequest create() => BatchGetSessionsRequest._();
  @$core.override
  BatchGetSessionsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BatchGetSessionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BatchGetSessionsRequest>(create);
  static BatchGetSessionsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get ids => $_getList(0);
}

/// findBatch attaches isStarred when authenticated, matching findOne / findList behaviour.
class BatchGetSessionsResponse extends $pb.GeneratedMessage {
  factory BatchGetSessionsResponse({
    $core.Iterable<BreathSessionWithStarredDto>? sessions,
  }) {
    final result = create();
    if (sessions != null) result.sessions.addAll(sessions);
    return result;
  }

  BatchGetSessionsResponse._();

  factory BatchGetSessionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BatchGetSessionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BatchGetSessionsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..pPM<BreathSessionWithStarredDto>(1, _omitFieldNames ? '' : 'sessions',
        subBuilder: BreathSessionWithStarredDto.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchGetSessionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchGetSessionsResponse copyWith(
          void Function(BatchGetSessionsResponse) updates) =>
      super.copyWith((message) => updates(message as BatchGetSessionsResponse))
          as BatchGetSessionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BatchGetSessionsResponse create() => BatchGetSessionsResponse._();
  @$core.override
  BatchGetSessionsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BatchGetSessionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BatchGetSessionsResponse>(create);
  static BatchGetSessionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<BreathSessionWithStarredDto> get sessions => $_getList(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
