// This is a generated file - do not edit.
//
// Generated from module_biometric_stream.proto.

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

@$core.Deprecated('Use bioSampleDescriptor instead')
const BioSample$json = {
  '1': 'BioSample',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'timestamp', '3': 2, '4': 1, '5': 3, '10': 'timestamp'},
    {'1': 'sample_type', '3': 3, '4': 1, '5': 9, '10': 'sampleType'},
    {
      '1': 'data',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Struct',
      '10': 'data'
    },
  ],
};

/// Descriptor for `BioSample`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bioSampleDescriptor = $convert.base64Decode(
    'CglCaW9TYW1wbGUSHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEhwKCXRpbWVzdGFtcB'
    'gCIAEoA1IJdGltZXN0YW1wEh8KC3NhbXBsZV90eXBlGAMgASgJUgpzYW1wbGVUeXBlEisKBGRh'
    'dGEYBCABKAsyFy5nb29nbGUucHJvdG9idWYuU3RydWN0UgRkYXRh');

@$core.Deprecated('Use bioSampleBatchDescriptor instead')
const BioSampleBatch$json = {
  '1': 'BioSampleBatch',
  '2': [
    {
      '1': 'samples',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.mind.BioSample',
      '10': 'samples'
    },
  ],
};

/// Descriptor for `BioSampleBatch`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bioSampleBatchDescriptor = $convert.base64Decode(
    'Cg5CaW9TYW1wbGVCYXRjaBIpCgdzYW1wbGVzGAEgAygLMg8ubWluZC5CaW9TYW1wbGVSB3NhbX'
    'BsZXM=');

@$core.Deprecated('Use bioStreamAckDescriptor instead')
const BioStreamAck$json = {
  '1': 'BioStreamAck',
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

/// Descriptor for `BioStreamAck`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bioStreamAckDescriptor = $convert.base64Decode(
    'CgxCaW9TdHJlYW1BY2sSHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEiUKDnJlY2Vpdm'
    'VkX2NvdW50GAIgASgDUg1yZWNlaXZlZENvdW50EiMKDWRyb3BwZWRfY291bnQYAyABKANSDGRy'
    'b3BwZWRDb3VudBIzChZtYXhfc2FtcGxlc19wZXJfc2Vjb25kGAQgASgFUhNtYXhTYW1wbGVzUG'
    'VyU2Vjb25kEhwKCXRpbWVzdGFtcBgFIAEoA1IJdGltZXN0YW1w');

@$core.Deprecated('Use bioStreamReadyDescriptor instead')
const BioStreamReady$json = {
  '1': 'BioStreamReady',
  '2': [
    {
      '1': 'max_samples_per_second',
      '3': 1,
      '4': 1,
      '5': 5,
      '10': 'maxSamplesPerSecond'
    },
    {'1': 'timestamp', '3': 2, '4': 1, '5': 3, '10': 'timestamp'},
  ],
};

/// Descriptor for `BioStreamReady`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bioStreamReadyDescriptor = $convert.base64Decode(
    'Cg5CaW9TdHJlYW1SZWFkeRIzChZtYXhfc2FtcGxlc19wZXJfc2Vjb25kGAEgASgFUhNtYXhTYW'
    '1wbGVzUGVyU2Vjb25kEhwKCXRpbWVzdGFtcBgCIAEoA1IJdGltZXN0YW1w');

@$core.Deprecated('Use bioStreamResponseDescriptor instead')
const BioStreamResponse$json = {
  '1': 'BioStreamResponse',
  '2': [
    {
      '1': 'ack',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.mind.BioStreamAck',
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
    {
      '1': 'ready',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.mind.BioStreamReady',
      '9': 0,
      '10': 'ready'
    },
  ],
  '8': [
    {'1': 'event'},
  ],
};

/// Descriptor for `BioStreamResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bioStreamResponseDescriptor = $convert.base64Decode(
    'ChFCaW9TdHJlYW1SZXNwb25zZRImCgNhY2sYASABKAsyEi5taW5kLkJpb1N0cmVhbUFja0gAUg'
    'NhY2sSLQoFZXJyb3IYAiABKAsyFS5taW5kLlN0YXRlRXJyb3JFdmVudEgAUgVlcnJvchIsCgVy'
    'ZWFkeRgDIAEoCzIULm1pbmQuQmlvU3RyZWFtUmVhZHlIAFIFcmVhZHlCBwoFZXZlbnQ=');
