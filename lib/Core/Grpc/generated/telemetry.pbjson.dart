// This is a generated file - do not edit.
//
// Generated from telemetry.proto.

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

@$core.Deprecated('Use telemetryDataDescriptor instead')
const TelemetryData$json = {
  '1': 'TelemetryData',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'timestamp', '3': 2, '4': 1, '5': 3, '10': 'timestamp'},
    {'1': 'module_id', '3': 3, '4': 1, '5': 9, '10': 'moduleId'},
    {'1': 'instruction_type', '3': 4, '4': 1, '5': 9, '10': 'instructionType'},
    {
      '1': 'data',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Struct',
      '10': 'data'
    },
  ],
};

/// Descriptor for `TelemetryData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List telemetryDataDescriptor = $convert.base64Decode(
    'Cg1UZWxlbWV0cnlEYXRhEh0KCnNlc3Npb25faWQYASABKAlSCXNlc3Npb25JZBIcCgl0aW1lc3'
    'RhbXAYAiABKANSCXRpbWVzdGFtcBIbCgltb2R1bGVfaWQYAyABKAlSCG1vZHVsZUlkEikKEGlu'
    'c3RydWN0aW9uX3R5cGUYBCABKAlSD2luc3RydWN0aW9uVHlwZRIrCgRkYXRhGAUgASgLMhcuZ2'
    '9vZ2xlLnByb3RvYnVmLlN0cnVjdFIEZGF0YQ==');

@$core.Deprecated('Use telemetryAckDescriptor instead')
const TelemetryAck$json = {
  '1': 'TelemetryAck',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'received_count', '3': 2, '4': 1, '5': 3, '10': 'receivedCount'},
    {'1': 'dropped_count', '3': 3, '4': 1, '5': 3, '10': 'droppedCount'},
    {
      '1': 'max_samples_per_second',
      '3': 4,
      '4': 1,
      '5': 5,
      '10': 'maxSamplesPerSecond'
    },
    {'1': 'timestamp', '3': 5, '4': 1, '5': 3, '10': 'timestamp'},
  ],
};

/// Descriptor for `TelemetryAck`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List telemetryAckDescriptor = $convert.base64Decode(
    'CgxUZWxlbWV0cnlBY2sSHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEiUKDnJlY2Vpdm'
    'VkX2NvdW50GAIgASgDUg1yZWNlaXZlZENvdW50EiMKDWRyb3BwZWRfY291bnQYAyABKANSDGRy'
    'b3BwZWRDb3VudBIzChZtYXhfc2FtcGxlc19wZXJfc2Vjb25kGAQgASgFUhNtYXhTYW1wbGVzUG'
    'VyU2Vjb25kEhwKCXRpbWVzdGFtcBgFIAEoA1IJdGltZXN0YW1w');

@$core.Deprecated('Use telemetryResponseDescriptor instead')
const TelemetryResponse$json = {
  '1': 'TelemetryResponse',
  '2': [
    {
      '1': 'ack',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.mind.TelemetryAck',
      '9': 0,
      '10': 'ack'
    },
    {
      '1': 'error',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.mind.SessionErrorEvent',
      '9': 0,
      '10': 'error'
    },
  ],
  '8': [
    {'1': 'event'},
  ],
};

/// Descriptor for `TelemetryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List telemetryResponseDescriptor = $convert.base64Decode(
    'ChFUZWxlbWV0cnlSZXNwb25zZRImCgNhY2sYASABKAsyEi5taW5kLlRlbGVtZXRyeUFja0gAUg'
    'NhY2sSLwoFZXJyb3IYAiABKAsyFy5taW5kLlNlc3Npb25FcnJvckV2ZW50SABSBWVycm9yQgcK'
    'BWV2ZW50');
