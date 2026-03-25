// This is a generated file - do not edit.
//
// Generated from sync.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Maps to SyncEventDto in src/sync/dto/sync-changes.dto.ts.
/// created_at is an ISO-8601 string (same convention as BreathSessionDto timestamps
/// in breath_sessions.proto).
/// id uses int64 to accommodate auto-increment IDs that may exceed int32 range over time.
class SyncEventDto extends $pb.GeneratedMessage {
  factory SyncEventDto({
    $fixnum.Int64? id,
    $core.String? entity,
    $core.String? refId,
    $core.String? action,
    $core.String? createdAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (entity != null) result.entity = entity;
    if (refId != null) result.refId = refId;
    if (action != null) result.action = action;
    if (createdAt != null) result.createdAt = createdAt;
    return result;
  }

  SyncEventDto._();

  factory SyncEventDto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SyncEventDto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncEventDto',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'entity')
    ..aOS(3, _omitFieldNames ? '' : 'refId')
    ..aOS(4, _omitFieldNames ? '' : 'action')
    ..aOS(5, _omitFieldNames ? '' : 'createdAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncEventDto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncEventDto copyWith(void Function(SyncEventDto) updates) =>
      super.copyWith((message) => updates(message as SyncEventDto))
          as SyncEventDto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncEventDto create() => SyncEventDto._();
  @$core.override
  SyncEventDto createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SyncEventDto getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncEventDto>(create);
  static SyncEventDto? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get entity => $_getSZ(1);
  @$pb.TagNumber(2)
  set entity($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEntity() => $_has(1);
  @$pb.TagNumber(2)
  void clearEntity() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get refId => $_getSZ(2);
  @$pb.TagNumber(3)
  set refId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRefId() => $_has(2);
  @$pb.TagNumber(3)
  void clearRefId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get action => $_getSZ(3);
  @$pb.TagNumber(4)
  set action($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAction() => $_has(3);
  @$pb.TagNumber(4)
  void clearAction() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get createdAt => $_getSZ(4);
  @$pb.TagNumber(5)
  set createdAt($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCreatedAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearCreatedAt() => $_clearField(5);
}

/// Maps to SyncChangesResponseDto in src/sync/dto/sync-changes.dto.ts.
/// cursor uses int64 to match the id range of SyncEventDto.
class SyncChangesPayload extends $pb.GeneratedMessage {
  factory SyncChangesPayload({
    $core.Iterable<SyncEventDto>? events,
    $fixnum.Int64? cursor,
    $core.bool? hasMore,
  }) {
    final result = create();
    if (events != null) result.events.addAll(events);
    if (cursor != null) result.cursor = cursor;
    if (hasMore != null) result.hasMore = hasMore;
    return result;
  }

  SyncChangesPayload._();

  factory SyncChangesPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SyncChangesPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncChangesPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..pPM<SyncEventDto>(1, _omitFieldNames ? '' : 'events',
        subBuilder: SyncEventDto.create)
    ..aInt64(2, _omitFieldNames ? '' : 'cursor')
    ..aOB(3, _omitFieldNames ? '' : 'hasMore')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncChangesPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncChangesPayload copyWith(void Function(SyncChangesPayload) updates) =>
      super.copyWith((message) => updates(message as SyncChangesPayload))
          as SyncChangesPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncChangesPayload create() => SyncChangesPayload._();
  @$core.override
  SyncChangesPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SyncChangesPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncChangesPayload>(create);
  static SyncChangesPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<SyncEventDto> get events => $_getList(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get cursor => $_getI64(1);
  @$pb.TagNumber(2)
  set cursor($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCursor() => $_has(1);
  @$pb.TagNumber(2)
  void clearCursor() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get hasMore => $_getBF(2);
  @$pb.TagNumber(3)
  set hasMore($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHasMore() => $_has(2);
  @$pb.TagNumber(3)
  void clearHasMore() => $_clearField(3);
}

/// GetChanges — maps to SyncChangesQueryDto in src/sync/dto/sync-changes.dto.ts.
/// Auth identity comes from metadata/interceptor, not the message.
/// after uses int64 to match the id range of SyncEventDto (roadmap spec: after: int64).
class GetChangesRequest extends $pb.GeneratedMessage {
  factory GetChangesRequest({
    $fixnum.Int64? after,
    $core.int? limit,
  }) {
    final result = create();
    if (after != null) result.after = after;
    if (limit != null) result.limit = limit;
    return result;
  }

  GetChangesRequest._();

  factory GetChangesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetChangesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetChangesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'after')
    ..aI(2, _omitFieldNames ? '' : 'limit')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetChangesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetChangesRequest copyWith(void Function(GetChangesRequest) updates) =>
      super.copyWith((message) => updates(message as GetChangesRequest))
          as GetChangesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetChangesRequest create() => GetChangesRequest._();
  @$core.override
  GetChangesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetChangesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetChangesRequest>(create);
  static GetChangesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get after => $_getI64(0);
  @$pb.TagNumber(1)
  set after($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAfter() => $_has(0);
  @$pb.TagNumber(1)
  void clearAfter() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get limit => $_getIZ(1);
  @$pb.TagNumber(2)
  set limit($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLimit() => $_has(1);
  @$pb.TagNumber(2)
  void clearLimit() => $_clearField(2);
}

enum GetChangesResponse_Result { payload, fullResync, notSet }

/// GetChangesResponse uses oneof result to return either cursor-paginated events
/// or a full_resync flag, matching the REST GET /sync/changes behavior.
/// oneof is named "result" to describe the branching nature (not "event" or "command"
/// which are stream-specific conventions in live.proto / telemetry.proto).
class GetChangesResponse extends $pb.GeneratedMessage {
  factory GetChangesResponse({
    SyncChangesPayload? payload,
    $core.bool? fullResync,
  }) {
    final result = create();
    if (payload != null) result.payload = payload;
    if (fullResync != null) result.fullResync = fullResync;
    return result;
  }

  GetChangesResponse._();

  factory GetChangesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetChangesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, GetChangesResponse_Result>
      _GetChangesResponse_ResultByTag = {
    1: GetChangesResponse_Result.payload,
    2: GetChangesResponse_Result.fullResync,
    0: GetChangesResponse_Result.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetChangesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aOM<SyncChangesPayload>(1, _omitFieldNames ? '' : 'payload',
        subBuilder: SyncChangesPayload.create)
    ..aOB(2, _omitFieldNames ? '' : 'fullResync')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetChangesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetChangesResponse copyWith(void Function(GetChangesResponse) updates) =>
      super.copyWith((message) => updates(message as GetChangesResponse))
          as GetChangesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetChangesResponse create() => GetChangesResponse._();
  @$core.override
  GetChangesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetChangesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetChangesResponse>(create);
  static GetChangesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  GetChangesResponse_Result whichResult() =>
      _GetChangesResponse_ResultByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearResult() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  SyncChangesPayload get payload => $_getN(0);
  @$pb.TagNumber(1)
  set payload(SyncChangesPayload value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPayload() => $_has(0);
  @$pb.TagNumber(1)
  void clearPayload() => $_clearField(1);
  @$pb.TagNumber(1)
  SyncChangesPayload ensurePayload() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.bool get fullResync => $_getBF(1);
  @$pb.TagNumber(2)
  set fullResync($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFullResync() => $_has(1);
  @$pb.TagNumber(2)
  void clearFullResync() => $_clearField(2);
}

/// WatchChanges — auth identity comes from metadata/interceptor, not the message
/// (same convention as GetChangesRequest).
/// When after_id is omitted the server streams only new events from the connection
/// moment; when provided the server first sends a catchup batch of all events with
/// id > after_id, then continues streaming new events in realtime.
class WatchChangesRequest extends $pb.GeneratedMessage {
  factory WatchChangesRequest({
    $fixnum.Int64? afterId,
  }) {
    final result = create();
    if (afterId != null) result.afterId = afterId;
    return result;
  }

  WatchChangesRequest._();

  factory WatchChangesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WatchChangesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WatchChangesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'afterId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchChangesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchChangesRequest copyWith(void Function(WatchChangesRequest) updates) =>
      super.copyWith((message) => updates(message as WatchChangesRequest))
          as WatchChangesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WatchChangesRequest create() => WatchChangesRequest._();
  @$core.override
  WatchChangesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WatchChangesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WatchChangesRequest>(create);
  static WatchChangesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get afterId => $_getI64(0);
  @$pb.TagNumber(1)
  set afterId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAfterId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAfterId() => $_clearField(1);
}

/// Server-streamed response envelope for WatchChanges.
/// Carries one or more events per message, allowing the server to batch rapid
/// changes (matching the 300 ms coalescing pattern in SyncNotifierService).
/// Reuses the shared SyncEventDto message defined above.
class ChangeEvent extends $pb.GeneratedMessage {
  factory ChangeEvent({
    $core.Iterable<SyncEventDto>? events,
  }) {
    final result = create();
    if (events != null) result.events.addAll(events);
    return result;
  }

  ChangeEvent._();

  factory ChangeEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ChangeEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChangeEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..pPM<SyncEventDto>(1, _omitFieldNames ? '' : 'events',
        subBuilder: SyncEventDto.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChangeEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChangeEvent copyWith(void Function(ChangeEvent) updates) =>
      super.copyWith((message) => updates(message as ChangeEvent))
          as ChangeEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChangeEvent create() => ChangeEvent._();
  @$core.override
  ChangeEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ChangeEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ChangeEvent>(create);
  static ChangeEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<SyncEventDto> get events => $_getList(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
