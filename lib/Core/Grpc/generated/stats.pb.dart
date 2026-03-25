// This is a generated file - do not edit.
//
// Generated from stats.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// GetStats — auth identity comes from metadata/interceptor, not the message
/// (same pattern as LogoutRequest in auth.proto).
class GetStatsRequest extends $pb.GeneratedMessage {
  factory GetStatsRequest() => create();

  GetStatsRequest._();

  factory GetStatsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetStatsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetStatsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStatsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStatsRequest copyWith(void Function(GetStatsRequest) updates) =>
      super.copyWith((message) => updates(message as GetStatsRequest))
          as GetStatsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetStatsRequest create() => GetStatsRequest._();
  @$core.override
  GetStatsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetStatsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetStatsRequest>(create);
  static GetStatsRequest? _defaultInstance;
}

/// Maps to UserStatsResponseDto in src/stats/dto/user-stats-response.dto.ts.
/// last_session_date is a date string in YYYY-MM-DD format (not ISO-8601 datetime).
class GetStatsResponse extends $pb.GeneratedMessage {
  factory GetStatsResponse({
    $core.int? totalSessions,
    $core.int? totalDurationSeconds,
    $core.int? currentStreak,
    $core.int? longestStreak,
    $core.String? lastSessionDate,
    $core.double? maxCompletedComplexity,
  }) {
    final result = create();
    if (totalSessions != null) result.totalSessions = totalSessions;
    if (totalDurationSeconds != null)
      result.totalDurationSeconds = totalDurationSeconds;
    if (currentStreak != null) result.currentStreak = currentStreak;
    if (longestStreak != null) result.longestStreak = longestStreak;
    if (lastSessionDate != null) result.lastSessionDate = lastSessionDate;
    if (maxCompletedComplexity != null)
      result.maxCompletedComplexity = maxCompletedComplexity;
    return result;
  }

  GetStatsResponse._();

  factory GetStatsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetStatsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetStatsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'totalSessions')
    ..aI(2, _omitFieldNames ? '' : 'totalDurationSeconds')
    ..aI(3, _omitFieldNames ? '' : 'currentStreak')
    ..aI(4, _omitFieldNames ? '' : 'longestStreak')
    ..aOS(5, _omitFieldNames ? '' : 'lastSessionDate')
    ..aD(6, _omitFieldNames ? '' : 'maxCompletedComplexity')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStatsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStatsResponse copyWith(void Function(GetStatsResponse) updates) =>
      super.copyWith((message) => updates(message as GetStatsResponse))
          as GetStatsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetStatsResponse create() => GetStatsResponse._();
  @$core.override
  GetStatsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetStatsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetStatsResponse>(create);
  static GetStatsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get totalSessions => $_getIZ(0);
  @$pb.TagNumber(1)
  set totalSessions($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTotalSessions() => $_has(0);
  @$pb.TagNumber(1)
  void clearTotalSessions() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get totalDurationSeconds => $_getIZ(1);
  @$pb.TagNumber(2)
  set totalDurationSeconds($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalDurationSeconds() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalDurationSeconds() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get currentStreak => $_getIZ(2);
  @$pb.TagNumber(3)
  set currentStreak($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCurrentStreak() => $_has(2);
  @$pb.TagNumber(3)
  void clearCurrentStreak() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get longestStreak => $_getIZ(3);
  @$pb.TagNumber(4)
  set longestStreak($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLongestStreak() => $_has(3);
  @$pb.TagNumber(4)
  void clearLongestStreak() => $_clearField(4);

  /// Date of the last qualifying session in YYYY-MM-DD format, or absent if none.
  @$pb.TagNumber(5)
  $core.String get lastSessionDate => $_getSZ(4);
  @$pb.TagNumber(5)
  set lastSessionDate($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLastSessionDate() => $_has(4);
  @$pb.TagNumber(5)
  void clearLastSessionDate() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get maxCompletedComplexity => $_getN(5);
  @$pb.TagNumber(6)
  set maxCompletedComplexity($core.double value) => $_setDouble(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMaxCompletedComplexity() => $_has(5);
  @$pb.TagNumber(6)
  void clearMaxCompletedComplexity() => $_clearField(6);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
