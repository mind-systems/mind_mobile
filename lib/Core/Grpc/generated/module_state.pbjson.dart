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
  ],
};

/// Descriptor for `ActivityType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List activityTypeDescriptor = $convert.base64Decode(
    'CgxBY3Rpdml0eVR5cGUSHQoZQUNUSVZJVFlfVFlQRV9VTlNQRUNJRklFRBAAEgoKBkJSRUFUSB'
    'AB');

@$core.Deprecated('Use presenceStateDescriptor instead')
const PresenceState$json = {
  '1': 'PresenceState',
  '2': [
    {'1': 'PRESENCE_STATE_UNSPECIFIED', '2': 0},
    {'1': 'FOREGROUND', '2': 1},
    {'1': 'BACKGROUND', '2': 2},
  ],
};

/// Descriptor for `PresenceState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List presenceStateDescriptor = $convert.base64Decode(
    'Cg1QcmVzZW5jZVN0YXRlEh4KGlBSRVNFTkNFX1NUQVRFX1VOU1BFQ0lGSUVEEAASDgoKRk9SRU'
    'dST1VORBABEg4KCkJBQ0tHUk9VTkQQAg==');

@$core.Deprecated('Use sessionStatusDescriptor instead')
const SessionStatus$json = {
  '1': 'SessionStatus',
  '2': [
    {'1': 'SESSION_STATUS_UNSPECIFIED', '2': 0},
    {'1': 'ACTIVE', '2': 1},
    {'1': 'DISCONNECTED', '2': 2},
    {'1': 'COMPLETED', '2': 3},
    {'1': 'ABANDONED', '2': 4},
    {'1': 'INTERRUPTED', '2': 5},
    {'1': 'RESUMED', '2': 6},
  ],
};

/// Descriptor for `SessionStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List sessionStatusDescriptor = $convert.base64Decode(
    'Cg1TZXNzaW9uU3RhdHVzEh4KGlNFU1NJT05fU1RBVFVTX1VOU1BFQ0lGSUVEEAASCgoGQUNUSV'
    'ZFEAESEAoMRElTQ09OTkVDVEVEEAISDQoJQ09NUExFVEVEEAMSDQoJQUJBTkRPTkVEEAQSDwoL'
    'SU5URVJSVVBURUQQBRILCgdSRVNVTUVEEAY=');

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
  ],
  '8': [
    {'1': '_ref_id'},
  ],
  '9': [
    {'1': 3, '2': 4},
  ],
};

/// Descriptor for `ActivityStartCmd`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List activityStartCmdDescriptor = $convert.base64Decode(
    'ChBBY3Rpdml0eVN0YXJ0Q21kEjcKDWFjdGl2aXR5X3R5cGUYASABKA4yEi5taW5kLkFjdGl2aX'
    'R5VHlwZVIMYWN0aXZpdHlUeXBlEhoKBnJlZl9pZBgCIAEoCUgAUgVyZWZJZIgBAUIJCgdfcmVm'
    'X2lkSgQIAxAE');

@$core.Deprecated('Use activityEndCmdDescriptor instead')
const ActivityEndCmd$json = {
  '1': 'ActivityEndCmd',
};

/// Descriptor for `ActivityEndCmd`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List activityEndCmdDescriptor =
    $convert.base64Decode('Cg5BY3Rpdml0eUVuZENtZA==');

@$core.Deprecated('Use activityStopCmdDescriptor instead')
const ActivityStopCmd$json = {
  '1': 'ActivityStopCmd',
};

/// Descriptor for `ActivityStopCmd`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List activityStopCmdDescriptor =
    $convert.base64Decode('Cg9BY3Rpdml0eVN0b3BDbWQ=');

@$core.Deprecated('Use activityPauseCmdDescriptor instead')
const ActivityPauseCmd$json = {
  '1': 'ActivityPauseCmd',
};

/// Descriptor for `ActivityPauseCmd`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List activityPauseCmdDescriptor =
    $convert.base64Decode('ChBBY3Rpdml0eVBhdXNlQ21k');

@$core.Deprecated('Use activityResumeCmdDescriptor instead')
const ActivityResumeCmd$json = {
  '1': 'ActivityResumeCmd',
};

/// Descriptor for `ActivityResumeCmd`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List activityResumeCmdDescriptor =
    $convert.base64Decode('ChFBY3Rpdml0eVJlc3VtZUNtZA==');

@$core.Deprecated('Use presenceCmdDescriptor instead')
const PresenceCmd$json = {
  '1': 'PresenceCmd',
  '2': [
    {
      '1': 'state',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.mind.PresenceState',
      '10': 'state'
    },
  ],
};

/// Descriptor for `PresenceCmd`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List presenceCmdDescriptor = $convert.base64Decode(
    'CgtQcmVzZW5jZUNtZBIpCgVzdGF0ZRgBIAEoDjITLm1pbmQuUHJlc2VuY2VTdGF0ZVIFc3RhdG'
    'U=');

@$core.Deprecated('Use sessionStateEventDescriptor instead')
const SessionStateEvent$json = {
  '1': 'SessionStateEvent',
  '2': [
    {'1': 'module_session_id', '3': 1, '4': 1, '5': 9, '10': 'moduleSessionId'},
    {
      '1': 'status',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.mind.SessionStatus',
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
  ],
  '8': [
    {'1': '_is_paused'},
  ],
};

/// Descriptor for `SessionStateEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionStateEventDescriptor = $convert.base64Decode(
    'ChFTZXNzaW9uU3RhdGVFdmVudBIqChFtb2R1bGVfc2Vzc2lvbl9pZBgBIAEoCVIPbW9kdWxlU2'
    'Vzc2lvbklkEisKBnN0YXR1cxgCIAEoDjITLm1pbmQuU2Vzc2lvblN0YXR1c1IGc3RhdHVzEiAK'
    'CWlzX3BhdXNlZBgDIAEoCEgAUghpc1BhdXNlZIgBAUIMCgpfaXNfcGF1c2Vk');

@$core.Deprecated('Use sessionErrorEventDescriptor instead')
const SessionErrorEvent$json = {
  '1': 'SessionErrorEvent',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 9, '10': 'code'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'timestamp', '3': 3, '4': 1, '5': 3, '10': 'timestamp'},
  ],
};

/// Descriptor for `SessionErrorEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionErrorEventDescriptor = $convert.base64Decode(
    'ChFTZXNzaW9uRXJyb3JFdmVudBISCgRjb2RlGAEgASgJUgRjb2RlEhgKB21lc3NhZ2UYAiABKA'
    'lSB21lc3NhZ2USHAoJdGltZXN0YW1wGAMgASgDUgl0aW1lc3RhbXA=');

@$core.Deprecated('Use sessionRequestDescriptor instead')
const SessionRequest$json = {
  '1': 'SessionRequest',
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
    {
      '1': 'presence',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.mind.PresenceCmd',
      '9': 0,
      '10': 'presence'
    },
  ],
  '8': [
    {'1': 'command'},
  ],
};

/// Descriptor for `SessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionRequestDescriptor = $convert.base64Decode(
    'Cg5TZXNzaW9uUmVxdWVzdBI/Cg5hY3Rpdml0eV9zdGFydBgBIAEoCzIWLm1pbmQuQWN0aXZpdH'
    'lTdGFydENtZEgAUg1hY3Rpdml0eVN0YXJ0EjkKDGFjdGl2aXR5X2VuZBgCIAEoCzIULm1pbmQu'
    'QWN0aXZpdHlFbmRDbWRIAFILYWN0aXZpdHlFbmQSPAoNYWN0aXZpdHlfc3RvcBgDIAEoCzIVLm'
    '1pbmQuQWN0aXZpdHlTdG9wQ21kSABSDGFjdGl2aXR5U3RvcBI/Cg5hY3Rpdml0eV9wYXVzZRgE'
    'IAEoCzIWLm1pbmQuQWN0aXZpdHlQYXVzZUNtZEgAUg1hY3Rpdml0eVBhdXNlEkIKD2FjdGl2aX'
    'R5X3Jlc3VtZRgFIAEoCzIXLm1pbmQuQWN0aXZpdHlSZXN1bWVDbWRIAFIOYWN0aXZpdHlSZXN1'
    'bWUSLwoIcHJlc2VuY2UYBiABKAsyES5taW5kLlByZXNlbmNlQ21kSABSCHByZXNlbmNlQgkKB2'
    'NvbW1hbmQ=');

@$core.Deprecated('Use sessionResponseDescriptor instead')
const SessionResponse$json = {
  '1': 'SessionResponse',
  '2': [
    {
      '1': 'session_state',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.mind.SessionStateEvent',
      '9': 0,
      '10': 'sessionState'
    },
    {
      '1': 'session_error',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.mind.SessionErrorEvent',
      '9': 0,
      '10': 'sessionError'
    },
  ],
  '8': [
    {'1': 'event'},
  ],
};

/// Descriptor for `SessionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionResponseDescriptor = $convert.base64Decode(
    'Cg9TZXNzaW9uUmVzcG9uc2USPgoNc2Vzc2lvbl9zdGF0ZRgBIAEoCzIXLm1pbmQuU2Vzc2lvbl'
    'N0YXRlRXZlbnRIAFIMc2Vzc2lvblN0YXRlEj4KDXNlc3Npb25fZXJyb3IYAiABKAsyFy5taW5k'
    'LlNlc3Npb25FcnJvckV2ZW50SABSDHNlc3Npb25FcnJvckIHCgVldmVudA==');
