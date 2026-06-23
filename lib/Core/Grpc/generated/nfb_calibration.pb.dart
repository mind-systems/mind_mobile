// This is a generated file - do not edit.
//
// Generated from nfb_calibration.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Maps to NfbCalibration entity in src/nfb-calibration/.
/// calibrated_at / created_at are ISO-8601 strings to match the project convention
/// used in SyncEventDto (proto/sync.proto).
class NfbCalibrationRecord extends $pb.GeneratedMessage {
  factory NfbCalibrationRecord({
    $core.String? id,
    $core.String? deviceSerial,
    $core.String? calibratedAt,
    $core.bool? isValid,
    $core.String? failReason,
    $core.double? individualFrequency,
    $core.double? individualPeakFrequencyPower,
    $core.double? individualPeakFrequencySuppression,
    $core.double? individualBandwidth,
    $core.double? individualNormalizedPower,
    $core.double? lowerFrequency,
    $core.double? upperFrequency,
    $core.String? createdAt,
    $core.double? individualPeakFrequency,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (deviceSerial != null) result.deviceSerial = deviceSerial;
    if (calibratedAt != null) result.calibratedAt = calibratedAt;
    if (isValid != null) result.isValid = isValid;
    if (failReason != null) result.failReason = failReason;
    if (individualFrequency != null)
      result.individualFrequency = individualFrequency;
    if (individualPeakFrequencyPower != null)
      result.individualPeakFrequencyPower = individualPeakFrequencyPower;
    if (individualPeakFrequencySuppression != null)
      result.individualPeakFrequencySuppression =
          individualPeakFrequencySuppression;
    if (individualBandwidth != null)
      result.individualBandwidth = individualBandwidth;
    if (individualNormalizedPower != null)
      result.individualNormalizedPower = individualNormalizedPower;
    if (lowerFrequency != null) result.lowerFrequency = lowerFrequency;
    if (upperFrequency != null) result.upperFrequency = upperFrequency;
    if (createdAt != null) result.createdAt = createdAt;
    if (individualPeakFrequency != null)
      result.individualPeakFrequency = individualPeakFrequency;
    return result;
  }

  NfbCalibrationRecord._();

  factory NfbCalibrationRecord.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NfbCalibrationRecord.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NfbCalibrationRecord',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'deviceSerial')
    ..aOS(3, _omitFieldNames ? '' : 'calibratedAt')
    ..aOB(4, _omitFieldNames ? '' : 'isValid')
    ..aOS(5, _omitFieldNames ? '' : 'failReason')
    ..aD(6, _omitFieldNames ? '' : 'individualFrequency',
        fieldType: $pb.PbFieldType.OF)
    ..aD(7, _omitFieldNames ? '' : 'individualPeakFrequencyPower',
        fieldType: $pb.PbFieldType.OF)
    ..aD(8, _omitFieldNames ? '' : 'individualPeakFrequencySuppression',
        fieldType: $pb.PbFieldType.OF)
    ..aD(9, _omitFieldNames ? '' : 'individualBandwidth',
        fieldType: $pb.PbFieldType.OF)
    ..aD(10, _omitFieldNames ? '' : 'individualNormalizedPower',
        fieldType: $pb.PbFieldType.OF)
    ..aD(11, _omitFieldNames ? '' : 'lowerFrequency',
        fieldType: $pb.PbFieldType.OF)
    ..aD(12, _omitFieldNames ? '' : 'upperFrequency',
        fieldType: $pb.PbFieldType.OF)
    ..aOS(13, _omitFieldNames ? '' : 'createdAt')
    ..aD(14, _omitFieldNames ? '' : 'individualPeakFrequency',
        fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NfbCalibrationRecord clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NfbCalibrationRecord copyWith(void Function(NfbCalibrationRecord) updates) =>
      super.copyWith((message) => updates(message as NfbCalibrationRecord))
          as NfbCalibrationRecord;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NfbCalibrationRecord create() => NfbCalibrationRecord._();
  @$core.override
  NfbCalibrationRecord createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NfbCalibrationRecord getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NfbCalibrationRecord>(create);
  static NfbCalibrationRecord? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get deviceSerial => $_getSZ(1);
  @$pb.TagNumber(2)
  set deviceSerial($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeviceSerial() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceSerial() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get calibratedAt => $_getSZ(2);
  @$pb.TagNumber(3)
  set calibratedAt($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCalibratedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearCalibratedAt() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get isValid => $_getBF(3);
  @$pb.TagNumber(4)
  set isValid($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIsValid() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsValid() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get failReason => $_getSZ(4);
  @$pb.TagNumber(5)
  set failReason($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFailReason() => $_has(4);
  @$pb.TagNumber(5)
  void clearFailReason() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get individualFrequency => $_getN(5);
  @$pb.TagNumber(6)
  set individualFrequency($core.double value) => $_setFloat(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIndividualFrequency() => $_has(5);
  @$pb.TagNumber(6)
  void clearIndividualFrequency() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.double get individualPeakFrequencyPower => $_getN(6);
  @$pb.TagNumber(7)
  set individualPeakFrequencyPower($core.double value) => $_setFloat(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIndividualPeakFrequencyPower() => $_has(6);
  @$pb.TagNumber(7)
  void clearIndividualPeakFrequencyPower() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.double get individualPeakFrequencySuppression => $_getN(7);
  @$pb.TagNumber(8)
  set individualPeakFrequencySuppression($core.double value) =>
      $_setFloat(7, value);
  @$pb.TagNumber(8)
  $core.bool hasIndividualPeakFrequencySuppression() => $_has(7);
  @$pb.TagNumber(8)
  void clearIndividualPeakFrequencySuppression() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.double get individualBandwidth => $_getN(8);
  @$pb.TagNumber(9)
  set individualBandwidth($core.double value) => $_setFloat(8, value);
  @$pb.TagNumber(9)
  $core.bool hasIndividualBandwidth() => $_has(8);
  @$pb.TagNumber(9)
  void clearIndividualBandwidth() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.double get individualNormalizedPower => $_getN(9);
  @$pb.TagNumber(10)
  set individualNormalizedPower($core.double value) => $_setFloat(9, value);
  @$pb.TagNumber(10)
  $core.bool hasIndividualNormalizedPower() => $_has(9);
  @$pb.TagNumber(10)
  void clearIndividualNormalizedPower() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.double get lowerFrequency => $_getN(10);
  @$pb.TagNumber(11)
  set lowerFrequency($core.double value) => $_setFloat(10, value);
  @$pb.TagNumber(11)
  $core.bool hasLowerFrequency() => $_has(10);
  @$pb.TagNumber(11)
  void clearLowerFrequency() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.double get upperFrequency => $_getN(11);
  @$pb.TagNumber(12)
  set upperFrequency($core.double value) => $_setFloat(11, value);
  @$pb.TagNumber(12)
  $core.bool hasUpperFrequency() => $_has(11);
  @$pb.TagNumber(12)
  void clearUpperFrequency() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get createdAt => $_getSZ(12);
  @$pb.TagNumber(13)
  set createdAt($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasCreatedAt() => $_has(12);
  @$pb.TagNumber(13)
  void clearCreatedAt() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.double get individualPeakFrequency => $_getN(13);
  @$pb.TagNumber(14)
  set individualPeakFrequency($core.double value) => $_setFloat(13, value);
  @$pb.TagNumber(14)
  $core.bool hasIndividualPeakFrequency() => $_has(13);
  @$pb.TagNumber(14)
  void clearIndividualPeakFrequency() => $_clearField(14);
}

/// Record — auth identity comes from metadata/interceptor, not the message.
class RecordNfbCalibrationRequest extends $pb.GeneratedMessage {
  factory RecordNfbCalibrationRequest({
    $core.String? deviceSerial,
    $core.String? calibratedAt,
    $core.bool? isValid,
    $core.String? failReason,
    $core.double? individualFrequency,
    $core.double? individualPeakFrequencyPower,
    $core.double? individualPeakFrequencySuppression,
    $core.double? individualBandwidth,
    $core.double? individualNormalizedPower,
    $core.double? lowerFrequency,
    $core.double? upperFrequency,
    $core.double? individualPeakFrequency,
  }) {
    final result = create();
    if (deviceSerial != null) result.deviceSerial = deviceSerial;
    if (calibratedAt != null) result.calibratedAt = calibratedAt;
    if (isValid != null) result.isValid = isValid;
    if (failReason != null) result.failReason = failReason;
    if (individualFrequency != null)
      result.individualFrequency = individualFrequency;
    if (individualPeakFrequencyPower != null)
      result.individualPeakFrequencyPower = individualPeakFrequencyPower;
    if (individualPeakFrequencySuppression != null)
      result.individualPeakFrequencySuppression =
          individualPeakFrequencySuppression;
    if (individualBandwidth != null)
      result.individualBandwidth = individualBandwidth;
    if (individualNormalizedPower != null)
      result.individualNormalizedPower = individualNormalizedPower;
    if (lowerFrequency != null) result.lowerFrequency = lowerFrequency;
    if (upperFrequency != null) result.upperFrequency = upperFrequency;
    if (individualPeakFrequency != null)
      result.individualPeakFrequency = individualPeakFrequency;
    return result;
  }

  RecordNfbCalibrationRequest._();

  factory RecordNfbCalibrationRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecordNfbCalibrationRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecordNfbCalibrationRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceSerial')
    ..aOS(2, _omitFieldNames ? '' : 'calibratedAt')
    ..aOB(3, _omitFieldNames ? '' : 'isValid')
    ..aOS(4, _omitFieldNames ? '' : 'failReason')
    ..aD(5, _omitFieldNames ? '' : 'individualFrequency',
        fieldType: $pb.PbFieldType.OF)
    ..aD(6, _omitFieldNames ? '' : 'individualPeakFrequencyPower',
        fieldType: $pb.PbFieldType.OF)
    ..aD(7, _omitFieldNames ? '' : 'individualPeakFrequencySuppression',
        fieldType: $pb.PbFieldType.OF)
    ..aD(8, _omitFieldNames ? '' : 'individualBandwidth',
        fieldType: $pb.PbFieldType.OF)
    ..aD(9, _omitFieldNames ? '' : 'individualNormalizedPower',
        fieldType: $pb.PbFieldType.OF)
    ..aD(10, _omitFieldNames ? '' : 'lowerFrequency',
        fieldType: $pb.PbFieldType.OF)
    ..aD(11, _omitFieldNames ? '' : 'upperFrequency',
        fieldType: $pb.PbFieldType.OF)
    ..aD(12, _omitFieldNames ? '' : 'individualPeakFrequency',
        fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordNfbCalibrationRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordNfbCalibrationRequest copyWith(
          void Function(RecordNfbCalibrationRequest) updates) =>
      super.copyWith(
              (message) => updates(message as RecordNfbCalibrationRequest))
          as RecordNfbCalibrationRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecordNfbCalibrationRequest create() =>
      RecordNfbCalibrationRequest._();
  @$core.override
  RecordNfbCalibrationRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RecordNfbCalibrationRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecordNfbCalibrationRequest>(create);
  static RecordNfbCalibrationRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceSerial => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceSerial($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceSerial() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceSerial() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get calibratedAt => $_getSZ(1);
  @$pb.TagNumber(2)
  set calibratedAt($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCalibratedAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearCalibratedAt() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isValid => $_getBF(2);
  @$pb.TagNumber(3)
  set isValid($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsValid() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsValid() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get failReason => $_getSZ(3);
  @$pb.TagNumber(4)
  set failReason($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFailReason() => $_has(3);
  @$pb.TagNumber(4)
  void clearFailReason() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get individualFrequency => $_getN(4);
  @$pb.TagNumber(5)
  set individualFrequency($core.double value) => $_setFloat(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIndividualFrequency() => $_has(4);
  @$pb.TagNumber(5)
  void clearIndividualFrequency() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get individualPeakFrequencyPower => $_getN(5);
  @$pb.TagNumber(6)
  set individualPeakFrequencyPower($core.double value) => $_setFloat(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIndividualPeakFrequencyPower() => $_has(5);
  @$pb.TagNumber(6)
  void clearIndividualPeakFrequencyPower() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.double get individualPeakFrequencySuppression => $_getN(6);
  @$pb.TagNumber(7)
  set individualPeakFrequencySuppression($core.double value) =>
      $_setFloat(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIndividualPeakFrequencySuppression() => $_has(6);
  @$pb.TagNumber(7)
  void clearIndividualPeakFrequencySuppression() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.double get individualBandwidth => $_getN(7);
  @$pb.TagNumber(8)
  set individualBandwidth($core.double value) => $_setFloat(7, value);
  @$pb.TagNumber(8)
  $core.bool hasIndividualBandwidth() => $_has(7);
  @$pb.TagNumber(8)
  void clearIndividualBandwidth() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.double get individualNormalizedPower => $_getN(8);
  @$pb.TagNumber(9)
  set individualNormalizedPower($core.double value) => $_setFloat(8, value);
  @$pb.TagNumber(9)
  $core.bool hasIndividualNormalizedPower() => $_has(8);
  @$pb.TagNumber(9)
  void clearIndividualNormalizedPower() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.double get lowerFrequency => $_getN(9);
  @$pb.TagNumber(10)
  set lowerFrequency($core.double value) => $_setFloat(9, value);
  @$pb.TagNumber(10)
  $core.bool hasLowerFrequency() => $_has(9);
  @$pb.TagNumber(10)
  void clearLowerFrequency() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.double get upperFrequency => $_getN(10);
  @$pb.TagNumber(11)
  set upperFrequency($core.double value) => $_setFloat(10, value);
  @$pb.TagNumber(11)
  $core.bool hasUpperFrequency() => $_has(10);
  @$pb.TagNumber(11)
  void clearUpperFrequency() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.double get individualPeakFrequency => $_getN(11);
  @$pb.TagNumber(12)
  set individualPeakFrequency($core.double value) => $_setFloat(11, value);
  @$pb.TagNumber(12)
  $core.bool hasIndividualPeakFrequency() => $_has(11);
  @$pb.TagNumber(12)
  void clearIndividualPeakFrequency() => $_clearField(12);
}

/// List — auth identity comes from metadata/interceptor, not the message.
class ListNfbCalibrationsRequest extends $pb.GeneratedMessage {
  factory ListNfbCalibrationsRequest({
    $core.String? deviceSerial,
    $core.int? limit,
  }) {
    final result = create();
    if (deviceSerial != null) result.deviceSerial = deviceSerial;
    if (limit != null) result.limit = limit;
    return result;
  }

  ListNfbCalibrationsRequest._();

  factory ListNfbCalibrationsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListNfbCalibrationsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListNfbCalibrationsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceSerial')
    ..aI(2, _omitFieldNames ? '' : 'limit')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListNfbCalibrationsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListNfbCalibrationsRequest copyWith(
          void Function(ListNfbCalibrationsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as ListNfbCalibrationsRequest))
          as ListNfbCalibrationsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListNfbCalibrationsRequest create() => ListNfbCalibrationsRequest._();
  @$core.override
  ListNfbCalibrationsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListNfbCalibrationsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListNfbCalibrationsRequest>(create);
  static ListNfbCalibrationsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceSerial => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceSerial($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceSerial() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceSerial() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get limit => $_getIZ(1);
  @$pb.TagNumber(2)
  set limit($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLimit() => $_has(1);
  @$pb.TagNumber(2)
  void clearLimit() => $_clearField(2);
}

class ListNfbCalibrationsResponse extends $pb.GeneratedMessage {
  factory ListNfbCalibrationsResponse({
    $core.Iterable<NfbCalibrationRecord>? records,
  }) {
    final result = create();
    if (records != null) result.records.addAll(records);
    return result;
  }

  ListNfbCalibrationsResponse._();

  factory ListNfbCalibrationsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListNfbCalibrationsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListNfbCalibrationsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..pPM<NfbCalibrationRecord>(1, _omitFieldNames ? '' : 'records',
        subBuilder: NfbCalibrationRecord.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListNfbCalibrationsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListNfbCalibrationsResponse copyWith(
          void Function(ListNfbCalibrationsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ListNfbCalibrationsResponse))
          as ListNfbCalibrationsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListNfbCalibrationsResponse create() =>
      ListNfbCalibrationsResponse._();
  @$core.override
  ListNfbCalibrationsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListNfbCalibrationsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListNfbCalibrationsResponse>(create);
  static ListNfbCalibrationsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<NfbCalibrationRecord> get records => $_getList(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
