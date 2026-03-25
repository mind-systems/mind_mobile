// This is a generated file - do not edit.
//
// Generated from device.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Ping — maps to DevicePingDto in src/device/dto/device-ping.dto.ts.
class PingRequest extends $pb.GeneratedMessage {
  factory PingRequest({
    $core.String? installationId,
    $core.String? platform,
    $core.String? osVersion,
    $core.String? locale,
    $core.String? timezone,
    $core.int? screenWidth,
    $core.int? screenHeight,
    $core.String? appVersion,
    $core.String? buildNumber,
    $core.String? model,
    $core.String? manufacturer,
  }) {
    final result = create();
    if (installationId != null) result.installationId = installationId;
    if (platform != null) result.platform = platform;
    if (osVersion != null) result.osVersion = osVersion;
    if (locale != null) result.locale = locale;
    if (timezone != null) result.timezone = timezone;
    if (screenWidth != null) result.screenWidth = screenWidth;
    if (screenHeight != null) result.screenHeight = screenHeight;
    if (appVersion != null) result.appVersion = appVersion;
    if (buildNumber != null) result.buildNumber = buildNumber;
    if (model != null) result.model = model;
    if (manufacturer != null) result.manufacturer = manufacturer;
    return result;
  }

  PingRequest._();

  factory PingRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PingRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PingRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'installationId')
    ..aOS(2, _omitFieldNames ? '' : 'platform')
    ..aOS(3, _omitFieldNames ? '' : 'osVersion')
    ..aOS(4, _omitFieldNames ? '' : 'locale')
    ..aOS(5, _omitFieldNames ? '' : 'timezone')
    ..aI(6, _omitFieldNames ? '' : 'screenWidth')
    ..aI(7, _omitFieldNames ? '' : 'screenHeight')
    ..aOS(8, _omitFieldNames ? '' : 'appVersion')
    ..aOS(9, _omitFieldNames ? '' : 'buildNumber')
    ..aOS(10, _omitFieldNames ? '' : 'model')
    ..aOS(11, _omitFieldNames ? '' : 'manufacturer')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingRequest copyWith(void Function(PingRequest) updates) =>
      super.copyWith((message) => updates(message as PingRequest))
          as PingRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PingRequest create() => PingRequest._();
  @$core.override
  PingRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PingRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PingRequest>(create);
  static PingRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get installationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set installationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasInstallationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearInstallationId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get platform => $_getSZ(1);
  @$pb.TagNumber(2)
  set platform($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPlatform() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlatform() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get osVersion => $_getSZ(2);
  @$pb.TagNumber(3)
  set osVersion($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOsVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearOsVersion() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get locale => $_getSZ(3);
  @$pb.TagNumber(4)
  set locale($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLocale() => $_has(3);
  @$pb.TagNumber(4)
  void clearLocale() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get timezone => $_getSZ(4);
  @$pb.TagNumber(5)
  set timezone($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTimezone() => $_has(4);
  @$pb.TagNumber(5)
  void clearTimezone() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get screenWidth => $_getIZ(5);
  @$pb.TagNumber(6)
  set screenWidth($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasScreenWidth() => $_has(5);
  @$pb.TagNumber(6)
  void clearScreenWidth() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get screenHeight => $_getIZ(6);
  @$pb.TagNumber(7)
  set screenHeight($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasScreenHeight() => $_has(6);
  @$pb.TagNumber(7)
  void clearScreenHeight() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get appVersion => $_getSZ(7);
  @$pb.TagNumber(8)
  set appVersion($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAppVersion() => $_has(7);
  @$pb.TagNumber(8)
  void clearAppVersion() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get buildNumber => $_getSZ(8);
  @$pb.TagNumber(9)
  set buildNumber($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasBuildNumber() => $_has(8);
  @$pb.TagNumber(9)
  void clearBuildNumber() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get model => $_getSZ(9);
  @$pb.TagNumber(10)
  set model($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasModel() => $_has(9);
  @$pb.TagNumber(10)
  void clearModel() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get manufacturer => $_getSZ(10);
  @$pb.TagNumber(11)
  set manufacturer($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasManufacturer() => $_has(10);
  @$pb.TagNumber(11)
  void clearManufacturer() => $_clearField(11);
}

class PingResponse extends $pb.GeneratedMessage {
  factory PingResponse() => create();

  PingResponse._();

  factory PingResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PingResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PingResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingResponse copyWith(void Function(PingResponse) updates) =>
      super.copyWith((message) => updates(message as PingResponse))
          as PingResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PingResponse create() => PingResponse._();
  @$core.override
  PingResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PingResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PingResponse>(create);
  static PingResponse? _defaultInstance;
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
