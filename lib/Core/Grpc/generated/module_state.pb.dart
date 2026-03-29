// This is a generated file - do not edit.
//
// Generated from module_state.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'module_state.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'module_state.pbenum.dart';

/// Maps to ActivityStartDto in src/realtime/dto/activity-start.dto.ts.
/// ref_id is the optional breath-session ID (activityRefId in the entity).
class ActivityStartCmd extends $pb.GeneratedMessage {
  factory ActivityStartCmd({
    ActivityType? activityType,
    $core.String? refId,
  }) {
    final result = create();
    if (activityType != null) result.activityType = activityType;
    if (refId != null) result.refId = refId;
    return result;
  }

  ActivityStartCmd._();

  factory ActivityStartCmd.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ActivityStartCmd.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ActivityStartCmd',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aE<ActivityType>(1, _omitFieldNames ? '' : 'activityType',
        enumValues: ActivityType.values)
    ..aOS(2, _omitFieldNames ? '' : 'refId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActivityStartCmd clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActivityStartCmd copyWith(void Function(ActivityStartCmd) updates) =>
      super.copyWith((message) => updates(message as ActivityStartCmd))
          as ActivityStartCmd;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ActivityStartCmd create() => ActivityStartCmd._();
  @$core.override
  ActivityStartCmd createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ActivityStartCmd getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ActivityStartCmd>(create);
  static ActivityStartCmd? _defaultInstance;

  @$pb.TagNumber(1)
  ActivityType get activityType => $_getN(0);
  @$pb.TagNumber(1)
  set activityType(ActivityType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasActivityType() => $_has(0);
  @$pb.TagNumber(1)
  void clearActivityType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get refId => $_getSZ(1);
  @$pb.TagNumber(2)
  set refId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRefId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRefId() => $_clearField(2);
}

/// Maps to ActivityEndDto in src/realtime/dto/activity-end.dto.ts.
class ActivityEndCmd extends $pb.GeneratedMessage {
  factory ActivityEndCmd() => create();

  ActivityEndCmd._();

  factory ActivityEndCmd.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ActivityEndCmd.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ActivityEndCmd',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActivityEndCmd clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActivityEndCmd copyWith(void Function(ActivityEndCmd) updates) =>
      super.copyWith((message) => updates(message as ActivityEndCmd))
          as ActivityEndCmd;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ActivityEndCmd create() => ActivityEndCmd._();
  @$core.override
  ActivityEndCmd createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ActivityEndCmd getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ActivityEndCmd>(create);
  static ActivityEndCmd? _defaultInstance;
}

/// Stop is handled inline in the gateway; no existing DTO.
class ActivityStopCmd extends $pb.GeneratedMessage {
  factory ActivityStopCmd() => create();

  ActivityStopCmd._();

  factory ActivityStopCmd.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ActivityStopCmd.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ActivityStopCmd',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActivityStopCmd clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActivityStopCmd copyWith(void Function(ActivityStopCmd) updates) =>
      super.copyWith((message) => updates(message as ActivityStopCmd))
          as ActivityStopCmd;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ActivityStopCmd create() => ActivityStopCmd._();
  @$core.override
  ActivityStopCmd createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ActivityStopCmd getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ActivityStopCmd>(create);
  static ActivityStopCmd? _defaultInstance;
}

class ActivityPauseCmd extends $pb.GeneratedMessage {
  factory ActivityPauseCmd() => create();

  ActivityPauseCmd._();

  factory ActivityPauseCmd.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ActivityPauseCmd.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ActivityPauseCmd',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActivityPauseCmd clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActivityPauseCmd copyWith(void Function(ActivityPauseCmd) updates) =>
      super.copyWith((message) => updates(message as ActivityPauseCmd))
          as ActivityPauseCmd;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ActivityPauseCmd create() => ActivityPauseCmd._();
  @$core.override
  ActivityPauseCmd createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ActivityPauseCmd getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ActivityPauseCmd>(create);
  static ActivityPauseCmd? _defaultInstance;
}

class ActivityResumeCmd extends $pb.GeneratedMessage {
  factory ActivityResumeCmd() => create();

  ActivityResumeCmd._();

  factory ActivityResumeCmd.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ActivityResumeCmd.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ActivityResumeCmd',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActivityResumeCmd clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActivityResumeCmd copyWith(void Function(ActivityResumeCmd) updates) =>
      super.copyWith((message) => updates(message as ActivityResumeCmd))
          as ActivityResumeCmd;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ActivityResumeCmd create() => ActivityResumeCmd._();
  @$core.override
  ActivityResumeCmd createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ActivityResumeCmd getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ActivityResumeCmd>(create);
  static ActivityResumeCmd? _defaultInstance;
}

/// Maps to SessionStateDto in src/realtime/dto/session-state.dto.ts.
class SessionStateEvent extends $pb.GeneratedMessage {
  factory SessionStateEvent({
    $core.String? moduleSessionId,
    SessionStatus? status,
    $core.bool? isPaused,
  }) {
    final result = create();
    if (moduleSessionId != null) result.moduleSessionId = moduleSessionId;
    if (status != null) result.status = status;
    if (isPaused != null) result.isPaused = isPaused;
    return result;
  }

  SessionStateEvent._();

  factory SessionStateEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SessionStateEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionStateEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'moduleSessionId')
    ..aE<SessionStatus>(2, _omitFieldNames ? '' : 'status',
        enumValues: SessionStatus.values)
    ..aOB(3, _omitFieldNames ? '' : 'isPaused')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionStateEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionStateEvent copyWith(void Function(SessionStateEvent) updates) =>
      super.copyWith((message) => updates(message as SessionStateEvent))
          as SessionStateEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SessionStateEvent create() => SessionStateEvent._();
  @$core.override
  SessionStateEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SessionStateEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SessionStateEvent>(create);
  static SessionStateEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get moduleSessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set moduleSessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasModuleSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearModuleSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  SessionStatus get status => $_getN(1);
  @$pb.TagNumber(2)
  set status(SessionStatus value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isPaused => $_getBF(2);
  @$pb.TagNumber(3)
  set isPaused($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsPaused() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsPaused() => $_clearField(3);
}

/// Maps to SessionErrorDto in src/realtime/dto/session-error.dto.ts.
/// timestamp is int64 Unix millis — not ISO-8601 — because error events are
/// high-frequency and don't need human-readable timestamps.
/// This message is top-level so module_instruction_stream.proto can import it later.
class SessionErrorEvent extends $pb.GeneratedMessage {
  factory SessionErrorEvent({
    $core.String? code,
    $core.String? message,
    $fixnum.Int64? timestamp,
  }) {
    final result = create();
    if (code != null) result.code = code;
    if (message != null) result.message = message;
    if (timestamp != null) result.timestamp = timestamp;
    return result;
  }

  SessionErrorEvent._();

  factory SessionErrorEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SessionErrorEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionErrorEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'code')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..aInt64(3, _omitFieldNames ? '' : 'timestamp')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionErrorEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionErrorEvent copyWith(void Function(SessionErrorEvent) updates) =>
      super.copyWith((message) => updates(message as SessionErrorEvent))
          as SessionErrorEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SessionErrorEvent create() => SessionErrorEvent._();
  @$core.override
  SessionErrorEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SessionErrorEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SessionErrorEvent>(create);
  static SessionErrorEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get code => $_getSZ(0);
  @$pb.TagNumber(1)
  set code($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestamp => $_getI64(2);
  @$pb.TagNumber(3)
  set timestamp($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTimestamp() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestamp() => $_clearField(3);
}

enum SessionRequest_Command {
  activityStart,
  activityEnd,
  activityStop,
  activityPause,
  activityResume,
  notSet
}

/// SessionRequest is the client-to-server stream envelope.
/// Each message carries exactly one command via the oneof.
class SessionRequest extends $pb.GeneratedMessage {
  factory SessionRequest({
    ActivityStartCmd? activityStart,
    ActivityEndCmd? activityEnd,
    ActivityStopCmd? activityStop,
    ActivityPauseCmd? activityPause,
    ActivityResumeCmd? activityResume,
  }) {
    final result = create();
    if (activityStart != null) result.activityStart = activityStart;
    if (activityEnd != null) result.activityEnd = activityEnd;
    if (activityStop != null) result.activityStop = activityStop;
    if (activityPause != null) result.activityPause = activityPause;
    if (activityResume != null) result.activityResume = activityResume;
    return result;
  }

  SessionRequest._();

  factory SessionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SessionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, SessionRequest_Command>
      _SessionRequest_CommandByTag = {
    1: SessionRequest_Command.activityStart,
    2: SessionRequest_Command.activityEnd,
    3: SessionRequest_Command.activityStop,
    4: SessionRequest_Command.activityPause,
    5: SessionRequest_Command.activityResume,
    0: SessionRequest_Command.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5])
    ..aOM<ActivityStartCmd>(1, _omitFieldNames ? '' : 'activityStart',
        subBuilder: ActivityStartCmd.create)
    ..aOM<ActivityEndCmd>(2, _omitFieldNames ? '' : 'activityEnd',
        subBuilder: ActivityEndCmd.create)
    ..aOM<ActivityStopCmd>(3, _omitFieldNames ? '' : 'activityStop',
        subBuilder: ActivityStopCmd.create)
    ..aOM<ActivityPauseCmd>(4, _omitFieldNames ? '' : 'activityPause',
        subBuilder: ActivityPauseCmd.create)
    ..aOM<ActivityResumeCmd>(5, _omitFieldNames ? '' : 'activityResume',
        subBuilder: ActivityResumeCmd.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionRequest copyWith(void Function(SessionRequest) updates) =>
      super.copyWith((message) => updates(message as SessionRequest))
          as SessionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SessionRequest create() => SessionRequest._();
  @$core.override
  SessionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SessionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SessionRequest>(create);
  static SessionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  SessionRequest_Command whichCommand() =>
      _SessionRequest_CommandByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  void clearCommand() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  ActivityStartCmd get activityStart => $_getN(0);
  @$pb.TagNumber(1)
  set activityStart(ActivityStartCmd value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasActivityStart() => $_has(0);
  @$pb.TagNumber(1)
  void clearActivityStart() => $_clearField(1);
  @$pb.TagNumber(1)
  ActivityStartCmd ensureActivityStart() => $_ensure(0);

  @$pb.TagNumber(2)
  ActivityEndCmd get activityEnd => $_getN(1);
  @$pb.TagNumber(2)
  set activityEnd(ActivityEndCmd value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasActivityEnd() => $_has(1);
  @$pb.TagNumber(2)
  void clearActivityEnd() => $_clearField(2);
  @$pb.TagNumber(2)
  ActivityEndCmd ensureActivityEnd() => $_ensure(1);

  @$pb.TagNumber(3)
  ActivityStopCmd get activityStop => $_getN(2);
  @$pb.TagNumber(3)
  set activityStop(ActivityStopCmd value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasActivityStop() => $_has(2);
  @$pb.TagNumber(3)
  void clearActivityStop() => $_clearField(3);
  @$pb.TagNumber(3)
  ActivityStopCmd ensureActivityStop() => $_ensure(2);

  @$pb.TagNumber(4)
  ActivityPauseCmd get activityPause => $_getN(3);
  @$pb.TagNumber(4)
  set activityPause(ActivityPauseCmd value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasActivityPause() => $_has(3);
  @$pb.TagNumber(4)
  void clearActivityPause() => $_clearField(4);
  @$pb.TagNumber(4)
  ActivityPauseCmd ensureActivityPause() => $_ensure(3);

  @$pb.TagNumber(5)
  ActivityResumeCmd get activityResume => $_getN(4);
  @$pb.TagNumber(5)
  set activityResume(ActivityResumeCmd value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasActivityResume() => $_has(4);
  @$pb.TagNumber(5)
  void clearActivityResume() => $_clearField(5);
  @$pb.TagNumber(5)
  ActivityResumeCmd ensureActivityResume() => $_ensure(4);
}

enum SessionResponse_Event { sessionState, sessionError, notSet }

/// SessionResponse is the server-to-client stream envelope.
/// Each message carries exactly one event via the oneof.
class SessionResponse extends $pb.GeneratedMessage {
  factory SessionResponse({
    SessionStateEvent? sessionState,
    SessionErrorEvent? sessionError,
  }) {
    final result = create();
    if (sessionState != null) result.sessionState = sessionState;
    if (sessionError != null) result.sessionError = sessionError;
    return result;
  }

  SessionResponse._();

  factory SessionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SessionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, SessionResponse_Event>
      _SessionResponse_EventByTag = {
    1: SessionResponse_Event.sessionState,
    2: SessionResponse_Event.sessionError,
    0: SessionResponse_Event.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aOM<SessionStateEvent>(1, _omitFieldNames ? '' : 'sessionState',
        subBuilder: SessionStateEvent.create)
    ..aOM<SessionErrorEvent>(2, _omitFieldNames ? '' : 'sessionError',
        subBuilder: SessionErrorEvent.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionResponse copyWith(void Function(SessionResponse) updates) =>
      super.copyWith((message) => updates(message as SessionResponse))
          as SessionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SessionResponse create() => SessionResponse._();
  @$core.override
  SessionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SessionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SessionResponse>(create);
  static SessionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  SessionResponse_Event whichEvent() =>
      _SessionResponse_EventByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearEvent() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  SessionStateEvent get sessionState => $_getN(0);
  @$pb.TagNumber(1)
  set sessionState(SessionStateEvent value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionState() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionState() => $_clearField(1);
  @$pb.TagNumber(1)
  SessionStateEvent ensureSessionState() => $_ensure(0);

  @$pb.TagNumber(2)
  SessionErrorEvent get sessionError => $_getN(1);
  @$pb.TagNumber(2)
  set sessionError(SessionErrorEvent value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionError() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionError() => $_clearField(2);
  @$pb.TagNumber(2)
  SessionErrorEvent ensureSessionError() => $_ensure(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
