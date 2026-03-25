// This is a generated file - do not edit.
//
// Generated from sync.proto.

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

@$core.Deprecated('Use syncEventDtoDescriptor instead')
const SyncEventDto$json = {
  '1': 'SyncEventDto',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'entity', '3': 2, '4': 1, '5': 9, '10': 'entity'},
    {'1': 'ref_id', '3': 3, '4': 1, '5': 9, '10': 'refId'},
    {'1': 'action', '3': 4, '4': 1, '5': 9, '10': 'action'},
    {'1': 'created_at', '3': 5, '4': 1, '5': 9, '10': 'createdAt'},
  ],
};

/// Descriptor for `SyncEventDto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncEventDtoDescriptor = $convert.base64Decode(
    'CgxTeW5jRXZlbnREdG8SDgoCaWQYASABKANSAmlkEhYKBmVudGl0eRgCIAEoCVIGZW50aXR5Eh'
    'UKBnJlZl9pZBgDIAEoCVIFcmVmSWQSFgoGYWN0aW9uGAQgASgJUgZhY3Rpb24SHQoKY3JlYXRl'
    'ZF9hdBgFIAEoCVIJY3JlYXRlZEF0');

@$core.Deprecated('Use syncChangesPayloadDescriptor instead')
const SyncChangesPayload$json = {
  '1': 'SyncChangesPayload',
  '2': [
    {
      '1': 'events',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.mind.SyncEventDto',
      '10': 'events'
    },
    {'1': 'cursor', '3': 2, '4': 1, '5': 3, '10': 'cursor'},
    {'1': 'has_more', '3': 3, '4': 1, '5': 8, '10': 'hasMore'},
  ],
};

/// Descriptor for `SyncChangesPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncChangesPayloadDescriptor = $convert.base64Decode(
    'ChJTeW5jQ2hhbmdlc1BheWxvYWQSKgoGZXZlbnRzGAEgAygLMhIubWluZC5TeW5jRXZlbnREdG'
    '9SBmV2ZW50cxIWCgZjdXJzb3IYAiABKANSBmN1cnNvchIZCghoYXNfbW9yZRgDIAEoCFIHaGFz'
    'TW9yZQ==');

@$core.Deprecated('Use getChangesRequestDescriptor instead')
const GetChangesRequest$json = {
  '1': 'GetChangesRequest',
  '2': [
    {'1': 'after', '3': 1, '4': 1, '5': 3, '10': 'after'},
    {'1': 'limit', '3': 2, '4': 1, '5': 5, '10': 'limit'},
  ],
};

/// Descriptor for `GetChangesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getChangesRequestDescriptor = $convert.base64Decode(
    'ChFHZXRDaGFuZ2VzUmVxdWVzdBIUCgVhZnRlchgBIAEoA1IFYWZ0ZXISFAoFbGltaXQYAiABKA'
    'VSBWxpbWl0');

@$core.Deprecated('Use getChangesResponseDescriptor instead')
const GetChangesResponse$json = {
  '1': 'GetChangesResponse',
  '2': [
    {
      '1': 'payload',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.mind.SyncChangesPayload',
      '9': 0,
      '10': 'payload'
    },
    {'1': 'full_resync', '3': 2, '4': 1, '5': 8, '9': 0, '10': 'fullResync'},
  ],
  '8': [
    {'1': 'result'},
  ],
};

/// Descriptor for `GetChangesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getChangesResponseDescriptor = $convert.base64Decode(
    'ChJHZXRDaGFuZ2VzUmVzcG9uc2USNAoHcGF5bG9hZBgBIAEoCzIYLm1pbmQuU3luY0NoYW5nZX'
    'NQYXlsb2FkSABSB3BheWxvYWQSIQoLZnVsbF9yZXN5bmMYAiABKAhIAFIKZnVsbFJlc3luY0II'
    'CgZyZXN1bHQ=');

@$core.Deprecated('Use watchChangesRequestDescriptor instead')
const WatchChangesRequest$json = {
  '1': 'WatchChangesRequest',
  '2': [
    {
      '1': 'after_id',
      '3': 1,
      '4': 1,
      '5': 3,
      '9': 0,
      '10': 'afterId',
      '17': true
    },
  ],
  '8': [
    {'1': '_after_id'},
  ],
};

/// Descriptor for `WatchChangesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List watchChangesRequestDescriptor = $convert.base64Decode(
    'ChNXYXRjaENoYW5nZXNSZXF1ZXN0Eh4KCGFmdGVyX2lkGAEgASgDSABSB2FmdGVySWSIAQFCCw'
    'oJX2FmdGVyX2lk');

@$core.Deprecated('Use changeEventDescriptor instead')
const ChangeEvent$json = {
  '1': 'ChangeEvent',
  '2': [
    {
      '1': 'events',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.mind.SyncEventDto',
      '10': 'events'
    },
  ],
};

/// Descriptor for `ChangeEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List changeEventDescriptor = $convert.base64Decode(
    'CgtDaGFuZ2VFdmVudBIqCgZldmVudHMYASADKAsyEi5taW5kLlN5bmNFdmVudER0b1IGZXZlbn'
    'Rz');
