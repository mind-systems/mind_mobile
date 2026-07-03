// This is a generated file - do not edit.
//
// Generated from module_state.proto.

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

@$core.Deprecated('Use activityTypeDescriptor instead')
const ActivityType$json = {
  '1': 'ActivityType',
  '2': [
    {'1': 'ACTIVITY_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'BREATH', '2': 1},
    {'1': 'MEDITATION', '2': 2},
    {'1': 'ROOT', '2': 3},
  ],
};

/// Descriptor for `ActivityType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List activityTypeDescriptor = $convert.base64Decode(
    'CgxBY3Rpdml0eVR5cGUSHQoZQUNUSVZJVFlfVFlQRV9VTlNQRUNJRklFRBAAEgoKBkJSRUFUSB'
    'ABEg4KCk1FRElUQVRJT04QAhIICgRST09UEAM=');

@$core.Deprecated('Use activityStatusDescriptor instead')
const ActivityStatus$json = {
  '1': 'ActivityStatus',
  '2': [
    {'1': 'ACTIVITY_STATUS_UNSPECIFIED', '2': 0},
    {'1': 'ACTIVE', '2': 1},
    {'1': 'DISCONNECTED', '2': 2},
    {'1': 'COMPLETED', '2': 3},
    {'1': 'ABANDONED', '2': 4},
    {'1': 'INTERRUPTED', '2': 5},
    {'1': 'RESUMED', '2': 6},
  ],
};

/// Descriptor for `ActivityStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List activityStatusDescriptor = $convert.base64Decode(
    'Cg5BY3Rpdml0eVN0YXR1cxIfChtBQ1RJVklUWV9TVEFUVVNfVU5TUEVDSUZJRUQQABIKCgZBQ1'
    'RJVkUQARIQCgxESVNDT05ORUNURUQQAhINCglDT01QTEVURUQQAxINCglBQkFORE9ORUQQBBIP'
    'CgtJTlRFUlJVUFRFRBAFEgsKB1JFU1VNRUQQBg==');

@$core.Deprecated('Use activityStartCmdDescriptor instead')
const ActivityStartCmd$json = {
  '1': 'ActivityStartCmd',
  '2': [
    {
      '1': 'activity_type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.mind.ActivityType',
      '10': 'activityType'
    },
    {'1': 'ref_id', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'refId', '17': true},
    {
      '1': 'client_timestamp_ms',
      '3': 4,
      '4': 1,
      '5': 3,
      '9': 1,
      '10': 'clientTimestampMs',
      '17': true
    },
    {
      '1': 'client_activity_id',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'clientActivityId',
      '17': true
    },
  ],
  '8': [
    {'1': '_ref_id'},
    {'1': '_client_timestamp_ms'},
    {'1': '_client_activity_id'},
  ],
  '9': [
    {'1': 3, '2': 4},
  ],
};

/// Descriptor for `ActivityStartCmd`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List activityStartCmdDescriptor = $convert.base64Decode(
    'ChBBY3Rpdml0eVN0YXJ0Q21kEjcKDWFjdGl2aXR5X3R5cGUYASABKA4yEi5taW5kLkFjdGl2aX'
    'R5VHlwZVIMYWN0aXZpdHlUeXBlEhoKBnJlZl9pZBgCIAEoCUgAUgVyZWZJZIgBARIzChNjbGll'
    'bnRfdGltZXN0YW1wX21zGAQgASgDSAFSEWNsaWVudFRpbWVzdGFtcE1ziAEBEjEKEmNsaWVudF'
    '9hY3Rpdml0eV9pZBgFIAEoCUgCUhBjbGllbnRBY3Rpdml0eUlkiAEBQgkKB19yZWZfaWRCFgoU'
    'X2NsaWVudF90aW1lc3RhbXBfbXNCFQoTX2NsaWVudF9hY3Rpdml0eV9pZEoECAMQBA==');

@$core.Deprecated('Use activityEndCmdDescriptor instead')
const ActivityEndCmd$json = {
  '1': 'ActivityEndCmd',
  '2': [
    {
      '1': 'client_timestamp_ms',
      '3': 1,
      '4': 1,
      '5': 3,
      '9': 0,
      '10': 'clientTimestampMs',
      '17': true
    },
    {
      '1': 'session_id',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'sessionId',
      '17': true
    },
  ],
  '8': [
    {'1': '_client_timestamp_ms'},
    {'1': '_session_id'},
  ],
};

/// Descriptor for `ActivityEndCmd`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List activityEndCmdDescriptor = $convert.base64Decode(
    'Cg5BY3Rpdml0eUVuZENtZBIzChNjbGllbnRfdGltZXN0YW1wX21zGAEgASgDSABSEWNsaWVudF'
    'RpbWVzdGFtcE1ziAEBEiIKCnNlc3Npb25faWQYAiABKAlIAVIJc2Vzc2lvbklkiAEBQhYKFF9j'
    'bGllbnRfdGltZXN0YW1wX21zQg0KC19zZXNzaW9uX2lk');

@$core.Deprecated('Use activityStopCmdDescriptor instead')
const ActivityStopCmd$json = {
  '1': 'ActivityStopCmd',
  '2': [
    {
      '1': 'session_id',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'sessionId',
      '17': true
    },
  ],
  '8': [
    {'1': '_session_id'},
  ],
};

/// Descriptor for `ActivityStopCmd`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List activityStopCmdDescriptor = $convert.base64Decode(
    'Cg9BY3Rpdml0eVN0b3BDbWQSIgoKc2Vzc2lvbl9pZBgBIAEoCUgAUglzZXNzaW9uSWSIAQFCDQ'
    'oLX3Nlc3Npb25faWQ=');

@$core.Deprecated('Use activityPauseCmdDescriptor instead')
const ActivityPauseCmd$json = {
  '1': 'ActivityPauseCmd',
  '2': [
    {
      '1': 'session_id',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'sessionId',
      '17': true
    },
  ],
  '8': [
    {'1': '_session_id'},
  ],
};

/// Descriptor for `ActivityPauseCmd`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List activityPauseCmdDescriptor = $convert.base64Decode(
    'ChBBY3Rpdml0eVBhdXNlQ21kEiIKCnNlc3Npb25faWQYASABKAlIAFIJc2Vzc2lvbklkiAEBQg'
    '0KC19zZXNzaW9uX2lk');

@$core.Deprecated('Use activityResumeCmdDescriptor instead')
const ActivityResumeCmd$json = {
  '1': 'ActivityResumeCmd',
  '2': [
    {
      '1': 'session_id',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'sessionId',
      '17': true
    },
  ],
  '8': [
    {'1': '_session_id'},
  ],
};

/// Descriptor for `ActivityResumeCmd`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List activityResumeCmdDescriptor = $convert.base64Decode(
    'ChFBY3Rpdml0eVJlc3VtZUNtZBIiCgpzZXNzaW9uX2lkGAEgASgJSABSCXNlc3Npb25JZIgBAU'
    'INCgtfc2Vzc2lvbl9pZA==');

@$core.Deprecated('Use stateEventDescriptor instead')
const StateEvent$json = {
  '1': 'StateEvent',
  '2': [
    {'1': 'module_session_id', '3': 1, '4': 1, '5': 9, '10': 'moduleSessionId'},
    {
      '1': 'status',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.mind.ActivityStatus',
      '10': 'status'
    },
    {
      '1': 'is_paused',
      '3': 3,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'isPaused',
      '17': true
    },
    {
      '1': 'activity_type',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.mind.ActivityType',
      '10': 'activityType'
    },
  ],
  '8': [
    {'1': '_is_paused'},
  ],
};

/// Descriptor for `StateEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stateEventDescriptor = $convert.base64Decode(
    'CgpTdGF0ZUV2ZW50EioKEW1vZHVsZV9zZXNzaW9uX2lkGAEgASgJUg9tb2R1bGVTZXNzaW9uSW'
    'QSLAoGc3RhdHVzGAIgASgOMhQubWluZC5BY3Rpdml0eVN0YXR1c1IGc3RhdHVzEiAKCWlzX3Bh'
    'dXNlZBgDIAEoCEgAUghpc1BhdXNlZIgBARI3Cg1hY3Rpdml0eV90eXBlGAQgASgOMhIubWluZC'
    '5BY3Rpdml0eVR5cGVSDGFjdGl2aXR5VHlwZUIMCgpfaXNfcGF1c2Vk');

@$core.Deprecated('Use stateErrorEventDescriptor instead')
const StateErrorEvent$json = {
  '1': 'StateErrorEvent',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 9, '10': 'code'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'timestamp', '3': 3, '4': 1, '5': 3, '10': 'timestamp'},
  ],
};

/// Descriptor for `StateErrorEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stateErrorEventDescriptor = $convert.base64Decode(
    'Cg9TdGF0ZUVycm9yRXZlbnQSEgoEY29kZRgBIAEoCVIEY29kZRIYCgdtZXNzYWdlGAIgASgJUg'
    'dtZXNzYWdlEhwKCXRpbWVzdGFtcBgDIAEoA1IJdGltZXN0YW1w');

@$core.Deprecated('Use stateRequestDescriptor instead')
const StateRequest$json = {
  '1': 'StateRequest',
  '2': [
    {
      '1': 'activity_start',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.mind.ActivityStartCmd',
      '9': 0,
      '10': 'activityStart'
    },
    {
      '1': 'activity_end',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.mind.ActivityEndCmd',
      '9': 0,
      '10': 'activityEnd'
    },
    {
      '1': 'activity_stop',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.mind.ActivityStopCmd',
      '9': 0,
      '10': 'activityStop'
    },
    {
      '1': 'activity_pause',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.mind.ActivityPauseCmd',
      '9': 0,
      '10': 'activityPause'
    },
    {
      '1': 'activity_resume',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.mind.ActivityResumeCmd',
      '9': 0,
      '10': 'activityResume'
    },
  ],
  '8': [
    {'1': 'command'},
  ],
};

/// Descriptor for `StateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stateRequestDescriptor = $convert.base64Decode(
    'CgxTdGF0ZVJlcXVlc3QSPwoOYWN0aXZpdHlfc3RhcnQYASABKAsyFi5taW5kLkFjdGl2aXR5U3'
    'RhcnRDbWRIAFINYWN0aXZpdHlTdGFydBI5CgxhY3Rpdml0eV9lbmQYAiABKAsyFC5taW5kLkFj'
    'dGl2aXR5RW5kQ21kSABSC2FjdGl2aXR5RW5kEjwKDWFjdGl2aXR5X3N0b3AYAyABKAsyFS5taW'
    '5kLkFjdGl2aXR5U3RvcENtZEgAUgxhY3Rpdml0eVN0b3ASPwoOYWN0aXZpdHlfcGF1c2UYBCAB'
    'KAsyFi5taW5kLkFjdGl2aXR5UGF1c2VDbWRIAFINYWN0aXZpdHlQYXVzZRJCCg9hY3Rpdml0eV'
    '9yZXN1bWUYBSABKAsyFy5taW5kLkFjdGl2aXR5UmVzdW1lQ21kSABSDmFjdGl2aXR5UmVzdW1l'
    'QgkKB2NvbW1hbmQ=');

@$core.Deprecated('Use stateResponseDescriptor instead')
const StateResponse$json = {
  '1': 'StateResponse',
  '2': [
    {
      '1': 'session_state',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.mind.StateEvent',
      '9': 0,
      '10': 'sessionState'
    },
    {
      '1': 'session_error',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.mind.StateErrorEvent',
      '9': 0,
      '10': 'sessionError'
    },
  ],
  '8': [
    {'1': 'event'},
  ],
};

/// Descriptor for `StateResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stateResponseDescriptor = $convert.base64Decode(
    'Cg1TdGF0ZVJlc3BvbnNlEjcKDXNlc3Npb25fc3RhdGUYASABKAsyEC5taW5kLlN0YXRlRXZlbn'
    'RIAFIMc2Vzc2lvblN0YXRlEjwKDXNlc3Npb25fZXJyb3IYAiABKAsyFS5taW5kLlN0YXRlRXJy'
    'b3JFdmVudEgAUgxzZXNzaW9uRXJyb3JCBwoFZXZlbnQ=');
