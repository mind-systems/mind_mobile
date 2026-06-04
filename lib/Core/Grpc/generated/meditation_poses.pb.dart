// This is a generated file - do not edit.
//
// Generated from meditation_poses.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Maps to MeditationPose entity in src/meditation-poses/.
/// Auth identity comes from metadata/interceptor, not the message.
/// No timestamps or user identity fields — poses are a server-side catalogue.
class MeditationPose extends $pb.GeneratedMessage {
  factory MeditationPose({
    $core.String? id,
    $core.String? slug,
    $core.int? displayOrder,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (slug != null) result.slug = slug;
    if (displayOrder != null) result.displayOrder = displayOrder;
    return result;
  }

  MeditationPose._();

  factory MeditationPose.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MeditationPose.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MeditationPose',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'slug')
    ..aI(3, _omitFieldNames ? '' : 'displayOrder')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MeditationPose clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MeditationPose copyWith(void Function(MeditationPose) updates) =>
      super.copyWith((message) => updates(message as MeditationPose))
          as MeditationPose;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MeditationPose create() => MeditationPose._();
  @$core.override
  MeditationPose createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MeditationPose getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MeditationPose>(create);
  static MeditationPose? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get slug => $_getSZ(1);
  @$pb.TagNumber(2)
  set slug($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSlug() => $_has(1);
  @$pb.TagNumber(2)
  void clearSlug() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get displayOrder => $_getIZ(2);
  @$pb.TagNumber(3)
  set displayOrder($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDisplayOrder() => $_has(2);
  @$pb.TagNumber(3)
  void clearDisplayOrder() => $_clearField(3);
}

/// ListPoses — auth identity comes from metadata/interceptor, not the message.
class ListMeditationPosesResponse extends $pb.GeneratedMessage {
  factory ListMeditationPosesResponse({
    $core.Iterable<MeditationPose>? poses,
  }) {
    final result = create();
    if (poses != null) result.poses.addAll(poses);
    return result;
  }

  ListMeditationPosesResponse._();

  factory ListMeditationPosesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListMeditationPosesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListMeditationPosesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..pPM<MeditationPose>(1, _omitFieldNames ? '' : 'poses',
        subBuilder: MeditationPose.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListMeditationPosesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListMeditationPosesResponse copyWith(
          void Function(ListMeditationPosesResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ListMeditationPosesResponse))
          as ListMeditationPosesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListMeditationPosesResponse create() =>
      ListMeditationPosesResponse._();
  @$core.override
  ListMeditationPosesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListMeditationPosesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListMeditationPosesResponse>(create);
  static ListMeditationPosesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<MeditationPose> get poses => $_getList(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
