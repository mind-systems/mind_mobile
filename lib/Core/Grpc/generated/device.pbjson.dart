// This is a generated file - do not edit.
//
// Generated from device.proto.

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

@$core.Deprecated('Use pingRequestDescriptor instead')
const PingRequest$json = {
  '1': 'PingRequest',
  '2': [
    {'1': 'installation_id', '3': 1, '4': 1, '5': 9, '10': 'installationId'},
    {'1': 'platform', '3': 2, '4': 1, '5': 9, '10': 'platform'},
    {'1': 'os_version', '3': 3, '4': 1, '5': 9, '10': 'osVersion'},
    {'1': 'locale', '3': 4, '4': 1, '5': 9, '10': 'locale'},
    {'1': 'timezone', '3': 5, '4': 1, '5': 9, '10': 'timezone'},
    {'1': 'screen_width', '3': 6, '4': 1, '5': 5, '10': 'screenWidth'},
    {'1': 'screen_height', '3': 7, '4': 1, '5': 5, '10': 'screenHeight'},
    {'1': 'app_version', '3': 8, '4': 1, '5': 9, '10': 'appVersion'},
    {'1': 'build_number', '3': 9, '4': 1, '5': 9, '10': 'buildNumber'},
    {'1': 'model', '3': 10, '4': 1, '5': 9, '9': 0, '10': 'model', '17': true},
    {
      '1': 'manufacturer',
      '3': 11,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'manufacturer',
      '17': true
    },
  ],
  '8': [
    {'1': '_model'},
    {'1': '_manufacturer'},
  ],
};

/// Descriptor for `PingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingRequestDescriptor = $convert.base64Decode(
    'CgtQaW5nUmVxdWVzdBInCg9pbnN0YWxsYXRpb25faWQYASABKAlSDmluc3RhbGxhdGlvbklkEh'
    'oKCHBsYXRmb3JtGAIgASgJUghwbGF0Zm9ybRIdCgpvc192ZXJzaW9uGAMgASgJUglvc1ZlcnNp'
    'b24SFgoGbG9jYWxlGAQgASgJUgZsb2NhbGUSGgoIdGltZXpvbmUYBSABKAlSCHRpbWV6b25lEi'
    'EKDHNjcmVlbl93aWR0aBgGIAEoBVILc2NyZWVuV2lkdGgSIwoNc2NyZWVuX2hlaWdodBgHIAEo'
    'BVIMc2NyZWVuSGVpZ2h0Eh8KC2FwcF92ZXJzaW9uGAggASgJUgphcHBWZXJzaW9uEiEKDGJ1aW'
    'xkX251bWJlchgJIAEoCVILYnVpbGROdW1iZXISGQoFbW9kZWwYCiABKAlIAFIFbW9kZWyIAQES'
    'JwoMbWFudWZhY3R1cmVyGAsgASgJSAFSDG1hbnVmYWN0dXJlcogBAUIICgZfbW9kZWxCDwoNX2'
    '1hbnVmYWN0dXJlcg==');

@$core.Deprecated('Use pingResponseDescriptor instead')
const PingResponse$json = {
  '1': 'PingResponse',
};

/// Descriptor for `PingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingResponseDescriptor =
    $convert.base64Decode('CgxQaW5nUmVzcG9uc2U=');
