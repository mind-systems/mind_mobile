// This is a generated file - do not edit.
//
// Generated from bci_devices.proto.

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

@$core.Deprecated('Use bciDeviceDescriptor instead')
const BciDevice$json = {
  '1': 'BciDevice',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'serial', '3': 2, '4': 1, '5': 9, '10': 'serial'},
    {'1': 'created_at', '3': 3, '4': 1, '5': 9, '10': 'createdAt'},
    {'1': 'updated_at', '3': 4, '4': 1, '5': 9, '10': 'updatedAt'},
  ],
};

/// Descriptor for `BciDevice`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bciDeviceDescriptor = $convert.base64Decode(
    'CglCY2lEZXZpY2USDgoCaWQYASABKAlSAmlkEhYKBnNlcmlhbBgCIAEoCVIGc2VyaWFsEh0KCm'
    'NyZWF0ZWRfYXQYAyABKAlSCWNyZWF0ZWRBdBIdCgp1cGRhdGVkX2F0GAQgASgJUgl1cGRhdGVk'
    'QXQ=');

@$core.Deprecated('Use listBciDevicesResponseDescriptor instead')
const ListBciDevicesResponse$json = {
  '1': 'ListBciDevicesResponse',
  '2': [
    {
      '1': 'devices',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.mind.BciDevice',
      '10': 'devices'
    },
  ],
};

/// Descriptor for `ListBciDevicesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listBciDevicesResponseDescriptor =
    $convert.base64Decode(
        'ChZMaXN0QmNpRGV2aWNlc1Jlc3BvbnNlEikKB2RldmljZXMYASADKAsyDy5taW5kLkJjaURldm'
        'ljZVIHZGV2aWNlcw==');

@$core.Deprecated('Use registerBciDeviceRequestDescriptor instead')
const RegisterBciDeviceRequest$json = {
  '1': 'RegisterBciDeviceRequest',
  '2': [
    {'1': 'serial', '3': 1, '4': 1, '5': 9, '10': 'serial'},
  ],
};

/// Descriptor for `RegisterBciDeviceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerBciDeviceRequestDescriptor =
    $convert.base64Decode(
        'ChhSZWdpc3RlckJjaURldmljZVJlcXVlc3QSFgoGc2VyaWFsGAEgASgJUgZzZXJpYWw=');

@$core.Deprecated('Use deleteBciDeviceRequestDescriptor instead')
const DeleteBciDeviceRequest$json = {
  '1': 'DeleteBciDeviceRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteBciDeviceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteBciDeviceRequestDescriptor = $convert
    .base64Decode('ChZEZWxldGVCY2lEZXZpY2VSZXF1ZXN0Eg4KAmlkGAEgASgJUgJpZA==');
