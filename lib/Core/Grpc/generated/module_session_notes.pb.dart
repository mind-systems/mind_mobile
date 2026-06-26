// This is a generated file - do not edit.
//
// Generated from module_session_notes.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Maps to ModuleSessionNote entity in src/module-session-notes/.
/// created_at / updated_at are ISO-8601 strings to match the project convention
/// used in SyncEventDto (proto/sync.proto).
/// user_id is intentionally absent — identity comes from the JWT/gRPC interceptor,
/// matching BciDevice (proto/bci_devices.proto) and NfbCalibrationRecord
/// (proto/nfb_calibration.proto).
class ModuleSessionNote extends $pb.GeneratedMessage {
  factory ModuleSessionNote({
    $core.String? id,
    $core.String? sessionId,
    $core.String? noteText,
    $core.String? createdAt,
    $core.String? updatedAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (sessionId != null) result.sessionId = sessionId;
    if (noteText != null) result.noteText = noteText;
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    return result;
  }

  ModuleSessionNote._();

  factory ModuleSessionNote.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModuleSessionNote.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModuleSessionNote',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..aOS(4, _omitFieldNames ? '' : 'noteText')
    ..aOS(5, _omitFieldNames ? '' : 'createdAt')
    ..aOS(6, _omitFieldNames ? '' : 'updatedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleSessionNote clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleSessionNote copyWith(void Function(ModuleSessionNote) updates) =>
      super.copyWith((message) => updates(message as ModuleSessionNote))
          as ModuleSessionNote;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModuleSessionNote create() => ModuleSessionNote._();
  @$core.override
  ModuleSessionNote createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModuleSessionNote getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModuleSessionNote>(create);
  static ModuleSessionNote? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(4)
  $core.String get noteText => $_getSZ(2);
  @$pb.TagNumber(4)
  set noteText($core.String value) => $_setString(2, value);
  @$pb.TagNumber(4)
  $core.bool hasNoteText() => $_has(2);
  @$pb.TagNumber(4)
  void clearNoteText() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get createdAt => $_getSZ(3);
  @$pb.TagNumber(5)
  set createdAt($core.String value) => $_setString(3, value);
  @$pb.TagNumber(5)
  $core.bool hasCreatedAt() => $_has(3);
  @$pb.TagNumber(5)
  void clearCreatedAt() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get updatedAt => $_getSZ(4);
  @$pb.TagNumber(6)
  set updatedAt($core.String value) => $_setString(4, value);
  @$pb.TagNumber(6)
  $core.bool hasUpdatedAt() => $_has(4);
  @$pb.TagNumber(6)
  void clearUpdatedAt() => $_clearField(6);
}

/// Create — auth identity comes from metadata/interceptor, not the message.
class CreateNoteRequest extends $pb.GeneratedMessage {
  factory CreateNoteRequest({
    $core.String? sessionId,
    $core.String? noteText,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (noteText != null) result.noteText = noteText;
    return result;
  }

  CreateNoteRequest._();

  factory CreateNoteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateNoteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateNoteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(3, _omitFieldNames ? '' : 'noteText')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateNoteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateNoteRequest copyWith(void Function(CreateNoteRequest) updates) =>
      super.copyWith((message) => updates(message as CreateNoteRequest))
          as CreateNoteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateNoteRequest create() => CreateNoteRequest._();
  @$core.override
  CreateNoteRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateNoteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateNoteRequest>(create);
  static CreateNoteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(3)
  $core.String get noteText => $_getSZ(1);
  @$pb.TagNumber(3)
  set noteText($core.String value) => $_setString(1, value);
  @$pb.TagNumber(3)
  $core.bool hasNoteText() => $_has(1);
  @$pb.TagNumber(3)
  void clearNoteText() => $_clearField(3);
}

/// Update — auth identity comes from metadata/interceptor, not the message.
/// Only note_text is mutable; session binding is immutable after creation.
class UpdateNoteRequest extends $pb.GeneratedMessage {
  factory UpdateNoteRequest({
    $core.String? noteId,
    $core.String? noteText,
  }) {
    final result = create();
    if (noteId != null) result.noteId = noteId;
    if (noteText != null) result.noteText = noteText;
    return result;
  }

  UpdateNoteRequest._();

  factory UpdateNoteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateNoteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateNoteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'noteId')
    ..aOS(2, _omitFieldNames ? '' : 'noteText')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateNoteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateNoteRequest copyWith(void Function(UpdateNoteRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateNoteRequest))
          as UpdateNoteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateNoteRequest create() => UpdateNoteRequest._();
  @$core.override
  UpdateNoteRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateNoteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateNoteRequest>(create);
  static UpdateNoteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get noteId => $_getSZ(0);
  @$pb.TagNumber(1)
  set noteId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNoteId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNoteId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get noteText => $_getSZ(1);
  @$pb.TagNumber(2)
  set noteText($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNoteText() => $_has(1);
  @$pb.TagNumber(2)
  void clearNoteText() => $_clearField(2);
}

/// List — auth identity comes from metadata/interceptor, not the message.
/// page_token is an opaque cursor; pass empty string on the first page.
class ListNotesRequest extends $pb.GeneratedMessage {
  factory ListNotesRequest({
    $core.int? pageSize,
    $core.String? pageToken,
  }) {
    final result = create();
    if (pageSize != null) result.pageSize = pageSize;
    if (pageToken != null) result.pageToken = pageToken;
    return result;
  }

  ListNotesRequest._();

  factory ListNotesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListNotesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListNotesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'pageSize')
    ..aOS(2, _omitFieldNames ? '' : 'pageToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListNotesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListNotesRequest copyWith(void Function(ListNotesRequest) updates) =>
      super.copyWith((message) => updates(message as ListNotesRequest))
          as ListNotesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListNotesRequest create() => ListNotesRequest._();
  @$core.override
  ListNotesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListNotesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListNotesRequest>(create);
  static ListNotesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get pageSize => $_getIZ(0);
  @$pb.TagNumber(1)
  set pageSize($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPageSize() => $_has(0);
  @$pb.TagNumber(1)
  void clearPageSize() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get pageToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set pageToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPageToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearPageToken() => $_clearField(2);
}

class ListNotesResponse extends $pb.GeneratedMessage {
  factory ListNotesResponse({
    $core.Iterable<ModuleSessionNote>? notes,
    $core.String? nextPageToken,
  }) {
    final result = create();
    if (notes != null) result.notes.addAll(notes);
    if (nextPageToken != null) result.nextPageToken = nextPageToken;
    return result;
  }

  ListNotesResponse._();

  factory ListNotesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListNotesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListNotesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..pPM<ModuleSessionNote>(1, _omitFieldNames ? '' : 'notes',
        subBuilder: ModuleSessionNote.create)
    ..aOS(2, _omitFieldNames ? '' : 'nextPageToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListNotesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListNotesResponse copyWith(void Function(ListNotesResponse) updates) =>
      super.copyWith((message) => updates(message as ListNotesResponse))
          as ListNotesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListNotesResponse create() => ListNotesResponse._();
  @$core.override
  ListNotesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListNotesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListNotesResponse>(create);
  static ListNotesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ModuleSessionNote> get notes => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get nextPageToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set nextPageToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNextPageToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearNextPageToken() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
