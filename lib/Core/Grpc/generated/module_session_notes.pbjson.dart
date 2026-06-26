// This is a generated file - do not edit.
//
// Generated from module_session_notes.proto.

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

@$core.Deprecated('Use moduleSessionNoteDescriptor instead')
const ModuleSessionNote$json = {
  '1': 'ModuleSessionNote',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'note_text', '3': 4, '4': 1, '5': 9, '10': 'noteText'},
    {'1': 'created_at', '3': 5, '4': 1, '5': 9, '10': 'createdAt'},
    {'1': 'updated_at', '3': 6, '4': 1, '5': 9, '10': 'updatedAt'},
  ],
  '9': [
    {'1': 3, '2': 4},
  ],
  '10': ['pose_id'],
};

/// Descriptor for `ModuleSessionNote`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List moduleSessionNoteDescriptor = $convert.base64Decode(
    'ChFNb2R1bGVTZXNzaW9uTm90ZRIOCgJpZBgBIAEoCVICaWQSHQoKc2Vzc2lvbl9pZBgCIAEoCV'
    'IJc2Vzc2lvbklkEhsKCW5vdGVfdGV4dBgEIAEoCVIIbm90ZVRleHQSHQoKY3JlYXRlZF9hdBgF'
    'IAEoCVIJY3JlYXRlZEF0Eh0KCnVwZGF0ZWRfYXQYBiABKAlSCXVwZGF0ZWRBdEoECAMQBFIHcG'
    '9zZV9pZA==');

@$core.Deprecated('Use createNoteRequestDescriptor instead')
const CreateNoteRequest$json = {
  '1': 'CreateNoteRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'note_text', '3': 3, '4': 1, '5': 9, '10': 'noteText'},
  ],
  '9': [
    {'1': 2, '2': 3},
  ],
  '10': ['pose_id'],
};

/// Descriptor for `CreateNoteRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createNoteRequestDescriptor = $convert.base64Decode(
    'ChFDcmVhdGVOb3RlUmVxdWVzdBIdCgpzZXNzaW9uX2lkGAEgASgJUglzZXNzaW9uSWQSGwoJbm'
    '90ZV90ZXh0GAMgASgJUghub3RlVGV4dEoECAIQA1IHcG9zZV9pZA==');

@$core.Deprecated('Use updateNoteRequestDescriptor instead')
const UpdateNoteRequest$json = {
  '1': 'UpdateNoteRequest',
  '2': [
    {'1': 'note_id', '3': 1, '4': 1, '5': 9, '10': 'noteId'},
    {'1': 'note_text', '3': 2, '4': 1, '5': 9, '10': 'noteText'},
  ],
};

/// Descriptor for `UpdateNoteRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateNoteRequestDescriptor = $convert.base64Decode(
    'ChFVcGRhdGVOb3RlUmVxdWVzdBIXCgdub3RlX2lkGAEgASgJUgZub3RlSWQSGwoJbm90ZV90ZX'
    'h0GAIgASgJUghub3RlVGV4dA==');

@$core.Deprecated('Use listNotesRequestDescriptor instead')
const ListNotesRequest$json = {
  '1': 'ListNotesRequest',
  '2': [
    {'1': 'page_size', '3': 1, '4': 1, '5': 5, '10': 'pageSize'},
    {'1': 'page_token', '3': 2, '4': 1, '5': 9, '10': 'pageToken'},
  ],
};

/// Descriptor for `ListNotesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listNotesRequestDescriptor = $convert.base64Decode(
    'ChBMaXN0Tm90ZXNSZXF1ZXN0EhsKCXBhZ2Vfc2l6ZRgBIAEoBVIIcGFnZVNpemUSHQoKcGFnZV'
    '90b2tlbhgCIAEoCVIJcGFnZVRva2Vu');

@$core.Deprecated('Use listNotesResponseDescriptor instead')
const ListNotesResponse$json = {
  '1': 'ListNotesResponse',
  '2': [
    {
      '1': 'notes',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.mind.ModuleSessionNote',
      '10': 'notes'
    },
    {'1': 'next_page_token', '3': 2, '4': 1, '5': 9, '10': 'nextPageToken'},
  ],
};

/// Descriptor for `ListNotesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listNotesResponseDescriptor = $convert.base64Decode(
    'ChFMaXN0Tm90ZXNSZXNwb25zZRItCgVub3RlcxgBIAMoCzIXLm1pbmQuTW9kdWxlU2Vzc2lvbk'
    '5vdGVSBW5vdGVzEiYKD25leHRfcGFnZV90b2tlbhgCIAEoCVINbmV4dFBhZ2VUb2tlbg==');
