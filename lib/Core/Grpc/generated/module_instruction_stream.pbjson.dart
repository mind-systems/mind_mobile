// This is a generated file - do not edit.
//
// Generated from module_instruction_stream.proto.

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

@$core.Deprecated('Use streamSampleDescriptor instead')
const StreamSample$json = {
  '1': 'StreamSample',
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

/// Descriptor for `StreamSample`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List streamSampleDescriptor = $convert.base64Decode(
    'CgxTdHJlYW1TYW1wbGUSHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEhwKCXRpbWVzdG'
    'FtcBgCIAEoA1IJdGltZXN0YW1wEhsKCW1vZHVsZV9pZBgDIAEoCVIIbW9kdWxlSWQSKQoQaW5z'
    'dHJ1Y3Rpb25fdHlwZRgEIAEoCVIPaW5zdHJ1Y3Rpb25UeXBlEisKBGRhdGEYBSABKAsyFy5nb2'
    '9nbGUucHJvdG9idWYuU3RydWN0UgRkYXRh');

@$core.Deprecated('Use streamAckDescriptor instead')
const StreamAck$json = {
  '1': 'StreamAck',
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

/// Descriptor for `StreamAck`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List streamAckDescriptor = $convert.base64Decode(
    'CglTdHJlYW1BY2sSHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEiUKDnJlY2VpdmVkX2'
    'NvdW50GAIgASgDUg1yZWNlaXZlZENvdW50EiMKDWRyb3BwZWRfY291bnQYAyABKANSDGRyb3Bw'
    'ZWRDb3VudBIzChZtYXhfc2FtcGxlc19wZXJfc2Vjb25kGAQgASgFUhNtYXhTYW1wbGVzUGVyU2'
    'Vjb25kEhwKCXRpbWVzdGFtcBgFIAEoA1IJdGltZXN0YW1w');

@$core.Deprecated('Use streamResponseDescriptor instead')
const StreamResponse$json = {
  '1': 'StreamResponse',
  '2': [
    {
      '1': 'ack',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.mind.StreamAck',
      '9': 0,
      '10': 'ack'
    },
    {
      '1': 'error',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.mind.StateErrorEvent',
      '9': 0,
      '10': 'error'
    },
  ],
  '8': [
    {'1': 'event'},
  ],
};

/// Descriptor for `StreamResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List streamResponseDescriptor = $convert.base64Decode(
    'Cg5TdHJlYW1SZXNwb25zZRIjCgNhY2sYASABKAsyDy5taW5kLlN0cmVhbUFja0gAUgNhY2sSLQ'
    'oFZXJyb3IYAiABKAsyFS5taW5kLlN0YXRlRXJyb3JFdmVudEgAUgVlcnJvckIHCgVldmVudA==');
