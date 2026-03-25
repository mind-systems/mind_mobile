// This is a generated file - do not edit.
//
// Generated from stats.proto.

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

@$core.Deprecated('Use getStatsRequestDescriptor instead')
const GetStatsRequest$json = {
  '1': 'GetStatsRequest',
};

/// Descriptor for `GetStatsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getStatsRequestDescriptor =
    $convert.base64Decode('Cg9HZXRTdGF0c1JlcXVlc3Q=');

@$core.Deprecated('Use getStatsResponseDescriptor instead')
const GetStatsResponse$json = {
  '1': 'GetStatsResponse',
  '2': [
    {'1': 'total_sessions', '3': 1, '4': 1, '5': 5, '10': 'totalSessions'},
    {
      '1': 'total_duration_seconds',
      '3': 2,
      '4': 1,
      '5': 5,
      '10': 'totalDurationSeconds'
    },
    {'1': 'current_streak', '3': 3, '4': 1, '5': 5, '10': 'currentStreak'},
    {'1': 'longest_streak', '3': 4, '4': 1, '5': 5, '10': 'longestStreak'},
    {
      '1': 'last_session_date',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'lastSessionDate',
      '17': true
    },
    {
      '1': 'max_completed_complexity',
      '3': 6,
      '4': 1,
      '5': 1,
      '10': 'maxCompletedComplexity'
    },
  ],
  '8': [
    {'1': '_last_session_date'},
  ],
};

/// Descriptor for `GetStatsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getStatsResponseDescriptor = $convert.base64Decode(
    'ChBHZXRTdGF0c1Jlc3BvbnNlEiUKDnRvdGFsX3Nlc3Npb25zGAEgASgFUg10b3RhbFNlc3Npb2'
    '5zEjQKFnRvdGFsX2R1cmF0aW9uX3NlY29uZHMYAiABKAVSFHRvdGFsRHVyYXRpb25TZWNvbmRz'
    'EiUKDmN1cnJlbnRfc3RyZWFrGAMgASgFUg1jdXJyZW50U3RyZWFrEiUKDmxvbmdlc3Rfc3RyZW'
    'FrGAQgASgFUg1sb25nZXN0U3RyZWFrEi8KEWxhc3Rfc2Vzc2lvbl9kYXRlGAUgASgJSABSD2xh'
    'c3RTZXNzaW9uRGF0ZYgBARI4ChhtYXhfY29tcGxldGVkX2NvbXBsZXhpdHkYBiABKAFSFm1heE'
    'NvbXBsZXRlZENvbXBsZXhpdHlCFAoSX2xhc3Rfc2Vzc2lvbl9kYXRl');
