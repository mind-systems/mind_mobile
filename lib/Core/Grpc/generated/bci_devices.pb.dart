// This is a generated file - do not edit.
//
// Generated from bci_devices.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Maps to BciDevice entity in src/bci/entities/bci-device.entity.ts.
/// created_at / updated_at are ISO-8601 strings to match the project convention
/// used in SyncEventDto (proto/sync.proto).
class BciDevice extends $pb.GeneratedMessage {
  factory BciDevice({
    $core.String? id,
    $core.String? serial,
    $core.String? createdAt,
    $core.String? updatedAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (serial != null) result.serial = serial;
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    return result;
  }

  BciDevice._();

  factory BciDevice.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BciDevice.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BciDevice',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'serial')
    ..aOS(3, _omitFieldNames ? '' : 'createdAt')
    ..aOS(4, _omitFieldNames ? '' : 'updatedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BciDevice clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BciDevice copyWith(void Function(BciDevice) updates) =>
      super.copyWith((message) => updates(message as BciDevice)) as BciDevice;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BciDevice create() => BciDevice._();
  @$core.override
  BciDevice createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BciDevice getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BciDevice>(create);
  static BciDevice? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get serial => $_getSZ(1);
  @$pb.TagNumber(2)
  set serial($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSerial() => $_has(1);
  @$pb.TagNumber(2)
  void clearSerial() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get createdAt => $_getSZ(2);
  @$pb.TagNumber(3)
  set createdAt($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCreatedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearCreatedAt() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get updatedAt => $_getSZ(3);
  @$pb.TagNumber(4)
  set updatedAt($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUpdatedAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearUpdatedAt() => $_clearField(4);
}

/// List — auth identity comes from metadata/interceptor, not the message.
class ListBciDevicesResponse extends $pb.GeneratedMessage {
  factory ListBciDevicesResponse({
    $core.Iterable<BciDevice>? devices,
  }) {
    final result = create();
    if (devices != null) result.devices.addAll(devices);
    return result;
  }

  ListBciDevicesResponse._();

  factory ListBciDevicesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListBciDevicesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListBciDevicesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..pPM<BciDevice>(1, _omitFieldNames ? '' : 'devices',
        subBuilder: BciDevice.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListBciDevicesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListBciDevicesResponse copyWith(
          void Function(ListBciDevicesResponse) updates) =>
      super.copyWith((message) => updates(message as ListBciDevicesResponse))
          as ListBciDevicesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListBciDevicesResponse create() => ListBciDevicesResponse._();
  @$core.override
  ListBciDevicesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListBciDevicesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListBciDevicesResponse>(create);
  static ListBciDevicesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<BciDevice> get devices => $_getList(0);
}

/// Register — auth identity comes from metadata/interceptor, not the message.
class RegisterBciDeviceRequest extends $pb.GeneratedMessage {
  factory RegisterBciDeviceRequest({
    $core.String? serial,
  }) {
    final result = create();
    if (serial != null) result.serial = serial;
    return result;
  }

  RegisterBciDeviceRequest._();

  factory RegisterBciDeviceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisterBciDeviceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterBciDeviceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'serial')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterBciDeviceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterBciDeviceRequest copyWith(
          void Function(RegisterBciDeviceRequest) updates) =>
      super.copyWith((message) => updates(message as RegisterBciDeviceRequest))
          as RegisterBciDeviceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterBciDeviceRequest create() => RegisterBciDeviceRequest._();
  @$core.override
  RegisterBciDeviceRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegisterBciDeviceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterBciDeviceRequest>(create);
  static RegisterBciDeviceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get serial => $_getSZ(0);
  @$pb.TagNumber(1)
  set serial($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSerial() => $_has(0);
  @$pb.TagNumber(1)
  void clearSerial() => $_clearField(1);
}

/// Delete — auth identity comes from metadata/interceptor, not the message.
class DeleteBciDeviceRequest extends $pb.GeneratedMessage {
  factory DeleteBciDeviceRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeleteBciDeviceRequest._();

  factory DeleteBciDeviceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteBciDeviceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteBciDeviceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteBciDeviceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteBciDeviceRequest copyWith(
          void Function(DeleteBciDeviceRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteBciDeviceRequest))
          as DeleteBciDeviceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteBciDeviceRequest create() => DeleteBciDeviceRequest._();
  @$core.override
  DeleteBciDeviceRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteBciDeviceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteBciDeviceRequest>(create);
  static DeleteBciDeviceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
