// This is a generated file - do not edit.
//
// Generated from breath_sessions.proto.

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

@$core.Deprecated('Use stepTypeDescriptor instead')
const StepType$json = {
  '1': 'StepType',
  '2': [
    {'1': 'INHALE', '2': 0},
    {'1': 'EXHALE', '2': 1},
    {'1': 'HOLD', '2': 2},
  ],
};

/// Descriptor for `StepType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List stepTypeDescriptor = $convert.base64Decode(
    'CghTdGVwVHlwZRIKCgZJTkhBTEUQABIKCgZFWEhBTEUQARIICgRIT0xEEAI=');

@$core.Deprecated('Use timeOfDayDescriptor instead')
const TimeOfDay$json = {
  '1': 'TimeOfDay',
  '2': [
    {'1': 'MORNING', '2': 0},
    {'1': 'MIDDAY', '2': 1},
    {'1': 'EVENING', '2': 2},
  ],
};

/// Descriptor for `TimeOfDay`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List timeOfDayDescriptor = $convert.base64Decode(
    'CglUaW1lT2ZEYXkSCwoHTU9STklORxAAEgoKBk1JRERBWRABEgsKB0VWRU5JTkcQAg==');

@$core.Deprecated('Use sessionSectionDescriptor instead')
const SessionSection$json = {
  '1': 'SessionSection',
  '2': [
    {'1': 'STARRED', '2': 0},
    {'1': 'MINE', '2': 1},
    {'1': 'SHARED', '2': 2},
  ],
};

/// Descriptor for `SessionSection`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List sessionSectionDescriptor = $convert.base64Decode(
    'Cg5TZXNzaW9uU2VjdGlvbhILCgdTVEFSUkVEEAASCAoETUlORRABEgoKBlNIQVJFRBAC');

@$core.Deprecated('Use stepDtoDescriptor instead')
const StepDto$json = {
  '1': 'StepDto',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 14, '6': '.mind.StepType', '10': 'type'},
    {'1': 'duration', '3': 2, '4': 1, '5': 1, '10': 'duration'},
  ],
};

/// Descriptor for `StepDto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stepDtoDescriptor = $convert.base64Decode(
    'CgdTdGVwRHRvEiIKBHR5cGUYASABKA4yDi5taW5kLlN0ZXBUeXBlUgR0eXBlEhoKCGR1cmF0aW'
    '9uGAIgASgBUghkdXJhdGlvbg==');

@$core.Deprecated('Use exerciseDtoDescriptor instead')
const ExerciseDto$json = {
  '1': 'ExerciseDto',
  '2': [
    {
      '1': 'steps',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.mind.StepDto',
      '10': 'steps'
    },
    {'1': 'rest_duration', '3': 2, '4': 1, '5': 1, '10': 'restDuration'},
    {'1': 'repeat_count', '3': 3, '4': 1, '5': 5, '10': 'repeatCount'},
  ],
};

/// Descriptor for `ExerciseDto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseDtoDescriptor = $convert.base64Decode(
    'CgtFeGVyY2lzZUR0bxIjCgVzdGVwcxgBIAMoCzINLm1pbmQuU3RlcER0b1IFc3RlcHMSIwoNcm'
    'VzdF9kdXJhdGlvbhgCIAEoAVIMcmVzdER1cmF0aW9uEiEKDHJlcGVhdF9jb3VudBgDIAEoBVIL'
    'cmVwZWF0Q291bnQ=');

@$core.Deprecated('Use exerciseListDescriptor instead')
const ExerciseList$json = {
  '1': 'ExerciseList',
  '2': [
    {
      '1': 'exercises',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.mind.ExerciseDto',
      '10': 'exercises'
    },
  ],
};

/// Descriptor for `ExerciseList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseListDescriptor = $convert.base64Decode(
    'CgxFeGVyY2lzZUxpc3QSLwoJZXhlcmNpc2VzGAEgAygLMhEubWluZC5FeGVyY2lzZUR0b1IJZX'
    'hlcmNpc2Vz');

@$core.Deprecated('Use breathSessionDtoDescriptor instead')
const BreathSessionDto$json = {
  '1': 'BreathSessionDto',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {
      '1': 'exercises',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.mind.ExerciseDto',
      '10': 'exercises'
    },
    {'1': 'complexity', '3': 5, '4': 1, '5': 1, '10': 'complexity'},
    {'1': 'shared', '3': 6, '4': 1, '5': 8, '10': 'shared'},
    {
      '1': 'time_of_day',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.mind.TimeOfDay',
      '9': 0,
      '10': 'timeOfDay',
      '17': true
    },
    {'1': 'created_at', '3': 8, '4': 1, '5': 9, '10': 'createdAt'},
    {'1': 'updated_at', '3': 9, '4': 1, '5': 9, '10': 'updatedAt'},
    {
      '1': 'deleted_at',
      '3': 10,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'deletedAt',
      '17': true
    },
  ],
  '8': [
    {'1': '_time_of_day'},
    {'1': '_deleted_at'},
  ],
};

/// Descriptor for `BreathSessionDto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List breathSessionDtoDescriptor = $convert.base64Decode(
    'ChBCcmVhdGhTZXNzaW9uRHRvEg4KAmlkGAEgASgJUgJpZBIXCgd1c2VyX2lkGAIgASgJUgZ1c2'
    'VySWQSIAoLZGVzY3JpcHRpb24YAyABKAlSC2Rlc2NyaXB0aW9uEi8KCWV4ZXJjaXNlcxgEIAMo'
    'CzIRLm1pbmQuRXhlcmNpc2VEdG9SCWV4ZXJjaXNlcxIeCgpjb21wbGV4aXR5GAUgASgBUgpjb2'
    '1wbGV4aXR5EhYKBnNoYXJlZBgGIAEoCFIGc2hhcmVkEjQKC3RpbWVfb2ZfZGF5GAcgASgOMg8u'
    'bWluZC5UaW1lT2ZEYXlIAFIJdGltZU9mRGF5iAEBEh0KCmNyZWF0ZWRfYXQYCCABKAlSCWNyZW'
    'F0ZWRBdBIdCgp1cGRhdGVkX2F0GAkgASgJUgl1cGRhdGVkQXQSIgoKZGVsZXRlZF9hdBgKIAEo'
    'CUgBUglkZWxldGVkQXSIAQFCDgoMX3RpbWVfb2ZfZGF5Qg0KC19kZWxldGVkX2F0');

@$core.Deprecated('Use breathSessionWithStarredDtoDescriptor instead')
const BreathSessionWithStarredDto$json = {
  '1': 'BreathSessionWithStarredDto',
  '2': [
    {
      '1': 'session',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.mind.BreathSessionDto',
      '10': 'session'
    },
    {
      '1': 'is_starred',
      '3': 2,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'isStarred',
      '17': true
    },
  ],
  '8': [
    {'1': '_is_starred'},
  ],
};

/// Descriptor for `BreathSessionWithStarredDto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List breathSessionWithStarredDtoDescriptor =
    $convert.base64Decode(
        'ChtCcmVhdGhTZXNzaW9uV2l0aFN0YXJyZWREdG8SMAoHc2Vzc2lvbhgBIAEoCzIWLm1pbmQuQn'
        'JlYXRoU2Vzc2lvbkR0b1IHc2Vzc2lvbhIiCgppc19zdGFycmVkGAIgASgISABSCWlzU3RhcnJl'
        'ZIgBAUINCgtfaXNfc3RhcnJlZA==');

@$core.Deprecated('Use sessionListItemDescriptor instead')
const SessionListItem$json = {
  '1': 'SessionListItem',
  '2': [
    {
      '1': 'session',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.mind.BreathSessionWithStarredDto',
      '10': 'session'
    },
    {
      '1': 'section',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.mind.SessionSection',
      '10': 'section'
    },
  ],
};

/// Descriptor for `SessionListItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionListItemDescriptor = $convert.base64Decode(
    'Cg9TZXNzaW9uTGlzdEl0ZW0SOwoHc2Vzc2lvbhgBIAEoCzIhLm1pbmQuQnJlYXRoU2Vzc2lvbl'
    'dpdGhTdGFycmVkRHRvUgdzZXNzaW9uEi4KB3NlY3Rpb24YAiABKA4yFC5taW5kLlNlc3Npb25T'
    'ZWN0aW9uUgdzZWN0aW9u');

@$core.Deprecated('Use createSessionRequestDescriptor instead')
const CreateSessionRequest$json = {
  '1': 'CreateSessionRequest',
  '2': [
    {'1': 'description', '3': 1, '4': 1, '5': 9, '10': 'description'},
    {
      '1': 'exercises',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.mind.ExerciseDto',
      '10': 'exercises'
    },
    {'1': 'shared', '3': 3, '4': 1, '5': 8, '9': 0, '10': 'shared', '17': true},
    {
      '1': 'time_of_day',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.mind.TimeOfDay',
      '9': 1,
      '10': 'timeOfDay',
      '17': true
    },
  ],
  '8': [
    {'1': '_shared'},
    {'1': '_time_of_day'},
  ],
};

/// Descriptor for `CreateSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createSessionRequestDescriptor = $convert.base64Decode(
    'ChRDcmVhdGVTZXNzaW9uUmVxdWVzdBIgCgtkZXNjcmlwdGlvbhgBIAEoCVILZGVzY3JpcHRpb2'
    '4SLwoJZXhlcmNpc2VzGAIgAygLMhEubWluZC5FeGVyY2lzZUR0b1IJZXhlcmNpc2VzEhsKBnNo'
    'YXJlZBgDIAEoCEgAUgZzaGFyZWSIAQESNAoLdGltZV9vZl9kYXkYBCABKA4yDy5taW5kLlRpbW'
    'VPZkRheUgBUgl0aW1lT2ZEYXmIAQFCCQoHX3NoYXJlZEIOCgxfdGltZV9vZl9kYXk=');

@$core.Deprecated('Use updateSessionRequestDescriptor instead')
const UpdateSessionRequest$json = {
  '1': 'UpdateSessionRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {
      '1': 'description',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'description',
      '17': true
    },
    {
      '1': 'exercises',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.mind.ExerciseList',
      '9': 1,
      '10': 'exercises',
      '17': true
    },
    {'1': 'shared', '3': 4, '4': 1, '5': 8, '9': 2, '10': 'shared', '17': true},
    {
      '1': 'time_of_day',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.mind.TimeOfDay',
      '9': 3,
      '10': 'timeOfDay',
      '17': true
    },
  ],
  '8': [
    {'1': '_description'},
    {'1': '_exercises'},
    {'1': '_shared'},
    {'1': '_time_of_day'},
  ],
};

/// Descriptor for `UpdateSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateSessionRequestDescriptor = $convert.base64Decode(
    'ChRVcGRhdGVTZXNzaW9uUmVxdWVzdBIOCgJpZBgBIAEoCVICaWQSJQoLZGVzY3JpcHRpb24YAi'
    'ABKAlIAFILZGVzY3JpcHRpb26IAQESNQoJZXhlcmNpc2VzGAMgASgLMhIubWluZC5FeGVyY2lz'
    'ZUxpc3RIAVIJZXhlcmNpc2VziAEBEhsKBnNoYXJlZBgEIAEoCEgCUgZzaGFyZWSIAQESNAoLdG'
    'ltZV9vZl9kYXkYBSABKA4yDy5taW5kLlRpbWVPZkRheUgDUgl0aW1lT2ZEYXmIAQFCDgoMX2Rl'
    'c2NyaXB0aW9uQgwKCl9leGVyY2lzZXNCCQoHX3NoYXJlZEIOCgxfdGltZV9vZl9kYXk=');

@$core.Deprecated('Use replaceSessionRequestDescriptor instead')
const ReplaceSessionRequest$json = {
  '1': 'ReplaceSessionRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'description', '3': 2, '4': 1, '5': 9, '10': 'description'},
    {
      '1': 'exercises',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.mind.ExerciseDto',
      '10': 'exercises'
    },
    {'1': 'shared', '3': 4, '4': 1, '5': 8, '10': 'shared'},
    {
      '1': 'time_of_day',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.mind.TimeOfDay',
      '9': 0,
      '10': 'timeOfDay',
      '17': true
    },
  ],
  '8': [
    {'1': '_time_of_day'},
  ],
};

/// Descriptor for `ReplaceSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List replaceSessionRequestDescriptor = $convert.base64Decode(
    'ChVSZXBsYWNlU2Vzc2lvblJlcXVlc3QSDgoCaWQYASABKAlSAmlkEiAKC2Rlc2NyaXB0aW9uGA'
    'IgASgJUgtkZXNjcmlwdGlvbhIvCglleGVyY2lzZXMYAyADKAsyES5taW5kLkV4ZXJjaXNlRHRv'
    'UglleGVyY2lzZXMSFgoGc2hhcmVkGAQgASgIUgZzaGFyZWQSNAoLdGltZV9vZl9kYXkYBSABKA'
    '4yDy5taW5kLlRpbWVPZkRheUgAUgl0aW1lT2ZEYXmIAQFCDgoMX3RpbWVfb2ZfZGF5');

@$core.Deprecated('Use updateSessionSettingsRequestDescriptor instead')
const UpdateSessionSettingsRequest$json = {
  '1': 'UpdateSessionSettingsRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'starred', '3': 2, '4': 1, '5': 8, '10': 'starred'},
  ],
};

/// Descriptor for `UpdateSessionSettingsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateSessionSettingsRequestDescriptor =
    $convert.base64Decode(
        'ChxVcGRhdGVTZXNzaW9uU2V0dGluZ3NSZXF1ZXN0Eg4KAmlkGAEgASgJUgJpZBIYCgdzdGFycm'
        'VkGAIgASgIUgdzdGFycmVk');

@$core.Deprecated('Use updateSessionSettingsResponseDescriptor instead')
const UpdateSessionSettingsResponse$json = {
  '1': 'UpdateSessionSettingsResponse',
  '2': [
    {'1': 'starred', '3': 1, '4': 1, '5': 8, '10': 'starred'},
  ],
};

/// Descriptor for `UpdateSessionSettingsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateSessionSettingsResponseDescriptor =
    $convert.base64Decode(
        'Ch1VcGRhdGVTZXNzaW9uU2V0dGluZ3NSZXNwb25zZRIYCgdzdGFycmVkGAEgASgIUgdzdGFycm'
        'Vk');

@$core.Deprecated('Use deleteSessionRequestDescriptor instead')
const DeleteSessionRequest$json = {
  '1': 'DeleteSessionRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteSessionRequestDescriptor = $convert
    .base64Decode('ChREZWxldGVTZXNzaW9uUmVxdWVzdBIOCgJpZBgBIAEoCVICaWQ=');

@$core.Deprecated('Use deleteSessionResponseDescriptor instead')
const DeleteSessionResponse$json = {
  '1': 'DeleteSessionResponse',
  '2': [
    {'1': 'message', '3': 1, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `DeleteSessionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteSessionResponseDescriptor =
    $convert.base64Decode(
        'ChVEZWxldGVTZXNzaW9uUmVzcG9uc2USGAoHbWVzc2FnZRgBIAEoCVIHbWVzc2FnZQ==');

@$core.Deprecated('Use listSessionsRequestDescriptor instead')
const ListSessionsRequest$json = {
  '1': 'ListSessionsRequest',
  '2': [
    {'1': 'cursor', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'cursor', '17': true},
    {'1': 'page_size', '3': 2, '4': 1, '5': 5, '10': 'pageSize'},
  ],
  '8': [
    {'1': '_cursor'},
  ],
};

/// Descriptor for `ListSessionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listSessionsRequestDescriptor = $convert.base64Decode(
    'ChNMaXN0U2Vzc2lvbnNSZXF1ZXN0EhsKBmN1cnNvchgBIAEoCUgAUgZjdXJzb3KIAQESGwoJcG'
    'FnZV9zaXplGAIgASgFUghwYWdlU2l6ZUIJCgdfY3Vyc29y');

@$core.Deprecated('Use listSessionsResponseDescriptor instead')
const ListSessionsResponse$json = {
  '1': 'ListSessionsResponse',
  '2': [
    {
      '1': 'items',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.mind.SessionListItem',
      '10': 'items'
    },
    {
      '1': 'next_cursor',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'nextCursor',
      '17': true
    },
  ],
  '8': [
    {'1': '_next_cursor'},
  ],
};

/// Descriptor for `ListSessionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listSessionsResponseDescriptor = $convert.base64Decode(
    'ChRMaXN0U2Vzc2lvbnNSZXNwb25zZRIrCgVpdGVtcxgBIAMoCzIVLm1pbmQuU2Vzc2lvbkxpc3'
    'RJdGVtUgVpdGVtcxIkCgtuZXh0X2N1cnNvchgCIAEoCUgAUgpuZXh0Q3Vyc29yiAEBQg4KDF9u'
    'ZXh0X2N1cnNvcg==');

@$core.Deprecated('Use getSessionRequestDescriptor instead')
const GetSessionRequest$json = {
  '1': 'GetSessionRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `GetSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSessionRequestDescriptor =
    $convert.base64Decode('ChFHZXRTZXNzaW9uUmVxdWVzdBIOCgJpZBgBIAEoCVICaWQ=');

@$core.Deprecated('Use getSuggestionsRequestDescriptor instead')
const GetSuggestionsRequest$json = {
  '1': 'GetSuggestionsRequest',
  '2': [
    {
      '1': 'time_of_day',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.mind.TimeOfDay',
      '10': 'timeOfDay'
    },
  ],
};

/// Descriptor for `GetSuggestionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSuggestionsRequestDescriptor = $convert.base64Decode(
    'ChVHZXRTdWdnZXN0aW9uc1JlcXVlc3QSLwoLdGltZV9vZl9kYXkYASABKA4yDy5taW5kLlRpbW'
    'VPZkRheVIJdGltZU9mRGF5');

@$core.Deprecated('Use getSuggestionsResponseDescriptor instead')
const GetSuggestionsResponse$json = {
  '1': 'GetSuggestionsResponse',
  '2': [
    {
      '1': 'suggestions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.mind.BreathSessionDto',
      '10': 'suggestions'
    },
  ],
};

/// Descriptor for `GetSuggestionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSuggestionsResponseDescriptor =
    $convert.base64Decode(
        'ChZHZXRTdWdnZXN0aW9uc1Jlc3BvbnNlEjgKC3N1Z2dlc3Rpb25zGAEgAygLMhYubWluZC5Ccm'
        'VhdGhTZXNzaW9uRHRvUgtzdWdnZXN0aW9ucw==');

@$core.Deprecated('Use batchGetSessionsRequestDescriptor instead')
const BatchGetSessionsRequest$json = {
  '1': 'BatchGetSessionsRequest',
  '2': [
    {'1': 'ids', '3': 1, '4': 3, '5': 9, '10': 'ids'},
  ],
};

/// Descriptor for `BatchGetSessionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List batchGetSessionsRequestDescriptor =
    $convert.base64Decode(
        'ChdCYXRjaEdldFNlc3Npb25zUmVxdWVzdBIQCgNpZHMYASADKAlSA2lkcw==');

@$core.Deprecated('Use batchGetSessionsResponseDescriptor instead')
const BatchGetSessionsResponse$json = {
  '1': 'BatchGetSessionsResponse',
  '2': [
    {
      '1': 'sessions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.mind.BreathSessionWithStarredDto',
      '10': 'sessions'
    },
  ],
};

/// Descriptor for `BatchGetSessionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List batchGetSessionsResponseDescriptor =
    $convert.base64Decode(
        'ChhCYXRjaEdldFNlc3Npb25zUmVzcG9uc2USPQoIc2Vzc2lvbnMYASADKAsyIS5taW5kLkJyZW'
        'F0aFNlc3Npb25XaXRoU3RhcnJlZER0b1IIc2Vzc2lvbnM=');
