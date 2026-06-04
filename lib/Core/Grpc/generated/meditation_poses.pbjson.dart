// This is a generated file - do not edit.
//
// Generated from meditation_poses.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use meditationPoseDescriptor instead')
const MeditationPose$json = {
  '1': 'MeditationPose',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'slug', '3': 2, '4': 1, '5': 9, '10': 'slug'},
    {'1': 'display_order', '3': 3, '4': 1, '5': 5, '10': 'displayOrder'},
  ],
};

/// Descriptor for `MeditationPose`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List meditationPoseDescriptor = $convert.base64Decode(
    'Cg5NZWRpdGF0aW9uUG9zZRIOCgJpZBgBIAEoCVICaWQSEgoEc2x1ZxgCIAEoCVIEc2x1ZxIjCg'
    '1kaXNwbGF5X29yZGVyGAMgASgFUgxkaXNwbGF5T3JkZXI=');

@$core.Deprecated('Use listMeditationPosesResponseDescriptor instead')
const ListMeditationPosesResponse$json = {
  '1': 'ListMeditationPosesResponse',
  '2': [
    {
      '1': 'poses',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.mind.MeditationPose',
      '10': 'poses'
    },
  ],
};

/// Descriptor for `ListMeditationPosesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listMeditationPosesResponseDescriptor =
    $convert.base64Decode(
        'ChtMaXN0TWVkaXRhdGlvblBvc2VzUmVzcG9uc2USKgoFcG9zZXMYASADKAsyFC5taW5kLk1lZG'
        'l0YXRpb25Qb3NlUgVwb3Nlcw==');
