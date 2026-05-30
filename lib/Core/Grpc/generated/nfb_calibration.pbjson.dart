// This is a generated file - do not edit.
//
// Generated from nfb_calibration.proto.

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

@$core.Deprecated('Use nfbCalibrationRecordDescriptor instead')
const NfbCalibrationRecord$json = {
  '1': 'NfbCalibrationRecord',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'device_serial', '3': 2, '4': 1, '5': 9, '10': 'deviceSerial'},
    {'1': 'calibrated_at', '3': 3, '4': 1, '5': 9, '10': 'calibratedAt'},
    {'1': 'is_valid', '3': 4, '4': 1, '5': 8, '10': 'isValid'},
    {'1': 'fail_reason', '3': 5, '4': 1, '5': 9, '10': 'failReason'},
    {
      '1': 'individual_frequency',
      '3': 6,
      '4': 1,
      '5': 2,
      '10': 'individualFrequency'
    },
    {
      '1': 'individual_peak_frequency_power',
      '3': 7,
      '4': 1,
      '5': 2,
      '10': 'individualPeakFrequencyPower'
    },
    {
      '1': 'individual_peak_frequency_suppression',
      '3': 8,
      '4': 1,
      '5': 2,
      '10': 'individualPeakFrequencySuppression'
    },
    {
      '1': 'individual_bandwidth',
      '3': 9,
      '4': 1,
      '5': 2,
      '10': 'individualBandwidth'
    },
    {
      '1': 'individual_normalized_power',
      '3': 10,
      '4': 1,
      '5': 2,
      '10': 'individualNormalizedPower'
    },
    {'1': 'lower_frequency', '3': 11, '4': 1, '5': 2, '10': 'lowerFrequency'},
    {'1': 'upper_frequency', '3': 12, '4': 1, '5': 2, '10': 'upperFrequency'},
    {'1': 'created_at', '3': 13, '4': 1, '5': 9, '10': 'createdAt'},
  ],
};

/// Descriptor for `NfbCalibrationRecord`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nfbCalibrationRecordDescriptor = $convert.base64Decode(
    'ChROZmJDYWxpYnJhdGlvblJlY29yZBIOCgJpZBgBIAEoCVICaWQSIwoNZGV2aWNlX3NlcmlhbB'
    'gCIAEoCVIMZGV2aWNlU2VyaWFsEiMKDWNhbGlicmF0ZWRfYXQYAyABKAlSDGNhbGlicmF0ZWRB'
    'dBIZCghpc192YWxpZBgEIAEoCFIHaXNWYWxpZBIfCgtmYWlsX3JlYXNvbhgFIAEoCVIKZmFpbF'
    'JlYXNvbhIxChRpbmRpdmlkdWFsX2ZyZXF1ZW5jeRgGIAEoAlITaW5kaXZpZHVhbEZyZXF1ZW5j'
    'eRJFCh9pbmRpdmlkdWFsX3BlYWtfZnJlcXVlbmN5X3Bvd2VyGAcgASgCUhxpbmRpdmlkdWFsUG'
    'Vha0ZyZXF1ZW5jeVBvd2VyElEKJWluZGl2aWR1YWxfcGVha19mcmVxdWVuY3lfc3VwcHJlc3Np'
    'b24YCCABKAJSImluZGl2aWR1YWxQZWFrRnJlcXVlbmN5U3VwcHJlc3Npb24SMQoUaW5kaXZpZH'
    'VhbF9iYW5kd2lkdGgYCSABKAJSE2luZGl2aWR1YWxCYW5kd2lkdGgSPgobaW5kaXZpZHVhbF9u'
    'b3JtYWxpemVkX3Bvd2VyGAogASgCUhlpbmRpdmlkdWFsTm9ybWFsaXplZFBvd2VyEicKD2xvd2'
    'VyX2ZyZXF1ZW5jeRgLIAEoAlIObG93ZXJGcmVxdWVuY3kSJwoPdXBwZXJfZnJlcXVlbmN5GAwg'
    'ASgCUg51cHBlckZyZXF1ZW5jeRIdCgpjcmVhdGVkX2F0GA0gASgJUgljcmVhdGVkQXQ=');

@$core.Deprecated('Use recordNfbCalibrationRequestDescriptor instead')
const RecordNfbCalibrationRequest$json = {
  '1': 'RecordNfbCalibrationRequest',
  '2': [
    {'1': 'device_serial', '3': 1, '4': 1, '5': 9, '10': 'deviceSerial'},
    {'1': 'calibrated_at', '3': 2, '4': 1, '5': 9, '10': 'calibratedAt'},
    {'1': 'is_valid', '3': 3, '4': 1, '5': 8, '10': 'isValid'},
    {'1': 'fail_reason', '3': 4, '4': 1, '5': 9, '10': 'failReason'},
    {
      '1': 'individual_frequency',
      '3': 5,
      '4': 1,
      '5': 2,
      '10': 'individualFrequency'
    },
    {
      '1': 'individual_peak_frequency_power',
      '3': 6,
      '4': 1,
      '5': 2,
      '10': 'individualPeakFrequencyPower'
    },
    {
      '1': 'individual_peak_frequency_suppression',
      '3': 7,
      '4': 1,
      '5': 2,
      '10': 'individualPeakFrequencySuppression'
    },
    {
      '1': 'individual_bandwidth',
      '3': 8,
      '4': 1,
      '5': 2,
      '10': 'individualBandwidth'
    },
    {
      '1': 'individual_normalized_power',
      '3': 9,
      '4': 1,
      '5': 2,
      '10': 'individualNormalizedPower'
    },
    {'1': 'lower_frequency', '3': 10, '4': 1, '5': 2, '10': 'lowerFrequency'},
    {'1': 'upper_frequency', '3': 11, '4': 1, '5': 2, '10': 'upperFrequency'},
  ],
};

/// Descriptor for `RecordNfbCalibrationRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recordNfbCalibrationRequestDescriptor = $convert.base64Decode(
    'ChtSZWNvcmROZmJDYWxpYnJhdGlvblJlcXVlc3QSIwoNZGV2aWNlX3NlcmlhbBgBIAEoCVIMZG'
    'V2aWNlU2VyaWFsEiMKDWNhbGlicmF0ZWRfYXQYAiABKAlSDGNhbGlicmF0ZWRBdBIZCghpc192'
    'YWxpZBgDIAEoCFIHaXNWYWxpZBIfCgtmYWlsX3JlYXNvbhgEIAEoCVIKZmFpbFJlYXNvbhIxCh'
    'RpbmRpdmlkdWFsX2ZyZXF1ZW5jeRgFIAEoAlITaW5kaXZpZHVhbEZyZXF1ZW5jeRJFCh9pbmRp'
    'dmlkdWFsX3BlYWtfZnJlcXVlbmN5X3Bvd2VyGAYgASgCUhxpbmRpdmlkdWFsUGVha0ZyZXF1ZW'
    '5jeVBvd2VyElEKJWluZGl2aWR1YWxfcGVha19mcmVxdWVuY3lfc3VwcHJlc3Npb24YByABKAJS'
    'ImluZGl2aWR1YWxQZWFrRnJlcXVlbmN5U3VwcHJlc3Npb24SMQoUaW5kaXZpZHVhbF9iYW5kd2'
    'lkdGgYCCABKAJSE2luZGl2aWR1YWxCYW5kd2lkdGgSPgobaW5kaXZpZHVhbF9ub3JtYWxpemVk'
    'X3Bvd2VyGAkgASgCUhlpbmRpdmlkdWFsTm9ybWFsaXplZFBvd2VyEicKD2xvd2VyX2ZyZXF1ZW'
    '5jeRgKIAEoAlIObG93ZXJGcmVxdWVuY3kSJwoPdXBwZXJfZnJlcXVlbmN5GAsgASgCUg51cHBl'
    'ckZyZXF1ZW5jeQ==');

@$core.Deprecated('Use listNfbCalibrationsRequestDescriptor instead')
const ListNfbCalibrationsRequest$json = {
  '1': 'ListNfbCalibrationsRequest',
  '2': [
    {'1': 'device_serial', '3': 1, '4': 1, '5': 9, '10': 'deviceSerial'},
    {'1': 'limit', '3': 2, '4': 1, '5': 5, '10': 'limit'},
  ],
};

/// Descriptor for `ListNfbCalibrationsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listNfbCalibrationsRequestDescriptor =
    $convert.base64Decode(
        'ChpMaXN0TmZiQ2FsaWJyYXRpb25zUmVxdWVzdBIjCg1kZXZpY2Vfc2VyaWFsGAEgASgJUgxkZX'
        'ZpY2VTZXJpYWwSFAoFbGltaXQYAiABKAVSBWxpbWl0');

@$core.Deprecated('Use listNfbCalibrationsResponseDescriptor instead')
const ListNfbCalibrationsResponse$json = {
  '1': 'ListNfbCalibrationsResponse',
  '2': [
    {
      '1': 'records',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.mind.NfbCalibrationRecord',
      '10': 'records'
    },
  ],
};

/// Descriptor for `ListNfbCalibrationsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listNfbCalibrationsResponseDescriptor =
    $convert.base64Decode(
        'ChtMaXN0TmZiQ2FsaWJyYXRpb25zUmVzcG9uc2USNAoHcmVjb3JkcxgBIAMoCzIaLm1pbmQuTm'
        'ZiQ2FsaWJyYXRpb25SZWNvcmRSB3JlY29yZHM=');
