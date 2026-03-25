// This is a generated file - do not edit.
//
// Generated from auth.proto.

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

@$core.Deprecated('Use userRoleDescriptor instead')
const UserRole$json = {
  '1': 'UserRole',
  '2': [
    {'1': 'USER', '2': 0},
    {'1': 'ADMIN', '2': 1},
  ],
};

/// Descriptor for `UserRole`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List userRoleDescriptor =
    $convert.base64Decode('CghVc2VyUm9sZRIICgRVU0VSEAASCQoFQURNSU4QAQ==');

@$core.Deprecated('Use userDtoDescriptor instead')
const UserDto$json = {
  '1': 'UserDto',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'email', '3': 2, '4': 1, '5': 9, '10': 'email'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'role', '3': 4, '4': 1, '5': 14, '6': '.mind.UserRole', '10': 'role'},
    {'1': 'language', '3': 5, '4': 1, '5': 9, '10': 'language'},
  ],
};

/// Descriptor for `UserDto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userDtoDescriptor = $convert.base64Decode(
    'CgdVc2VyRHRvEg4KAmlkGAEgASgJUgJpZBIUCgVlbWFpbBgCIAEoCVIFZW1haWwSEgoEbmFtZR'
    'gDIAEoCVIEbmFtZRIiCgRyb2xlGAQgASgOMg4ubWluZC5Vc2VyUm9sZVIEcm9sZRIaCghsYW5n'
    'dWFnZRgFIAEoCVIIbGFuZ3VhZ2U=');

@$core.Deprecated('Use authResponseDescriptor instead')
const AuthResponse$json = {
  '1': 'AuthResponse',
  '2': [
    {'1': 'user', '3': 1, '4': 1, '5': 11, '6': '.mind.UserDto', '10': 'user'},
    {'1': 'access_token', '3': 2, '4': 1, '5': 9, '10': 'accessToken'},
  ],
};

/// Descriptor for `AuthResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List authResponseDescriptor = $convert.base64Decode(
    'CgxBdXRoUmVzcG9uc2USIQoEdXNlchgBIAEoCzINLm1pbmQuVXNlckR0b1IEdXNlchIhCgxhY2'
    'Nlc3NfdG9rZW4YAiABKAlSC2FjY2Vzc1Rva2Vu');

@$core.Deprecated('Use tokenDtoDescriptor instead')
const TokenDto$json = {
  '1': 'TokenDto',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'created_at', '3': 3, '4': 1, '5': 9, '10': 'createdAt'},
    {
      '1': 'last_used_at',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'lastUsedAt',
      '17': true
    },
  ],
  '8': [
    {'1': '_last_used_at'},
  ],
};

/// Descriptor for `TokenDto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tokenDtoDescriptor = $convert.base64Decode(
    'CghUb2tlbkR0bxIOCgJpZBgBIAEoCVICaWQSEgoEbmFtZRgCIAEoCVIEbmFtZRIdCgpjcmVhdG'
    'VkX2F0GAMgASgJUgljcmVhdGVkQXQSJQoMbGFzdF91c2VkX2F0GAQgASgJSABSCmxhc3RVc2Vk'
    'QXSIAQFCDwoNX2xhc3RfdXNlZF9hdA==');

@$core.Deprecated('Use sendCodeRequestDescriptor instead')
const SendCodeRequest$json = {
  '1': 'SendCodeRequest',
  '2': [
    {'1': 'email', '3': 1, '4': 1, '5': 9, '10': 'email'},
    {'1': 'locale', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'locale', '17': true},
  ],
  '8': [
    {'1': '_locale'},
  ],
};

/// Descriptor for `SendCodeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendCodeRequestDescriptor = $convert.base64Decode(
    'Cg9TZW5kQ29kZVJlcXVlc3QSFAoFZW1haWwYASABKAlSBWVtYWlsEhsKBmxvY2FsZRgCIAEoCU'
    'gAUgZsb2NhbGWIAQFCCQoHX2xvY2FsZQ==');

@$core.Deprecated('Use sendCodeResponseDescriptor instead')
const SendCodeResponse$json = {
  '1': 'SendCodeResponse',
  '2': [
    {'1': 'message', '3': 1, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `SendCodeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendCodeResponseDescriptor = $convert.base64Decode(
    'ChBTZW5kQ29kZVJlc3BvbnNlEhgKB21lc3NhZ2UYASABKAlSB21lc3NhZ2U=');

@$core.Deprecated('Use verifyCodeRequestDescriptor instead')
const VerifyCodeRequest$json = {
  '1': 'VerifyCodeRequest',
  '2': [
    {'1': 'email', '3': 1, '4': 1, '5': 9, '10': 'email'},
    {'1': 'code', '3': 2, '4': 1, '5': 9, '10': 'code'},
    {
      '1': 'language',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'language',
      '17': true
    },
  ],
  '8': [
    {'1': '_language'},
  ],
};

/// Descriptor for `VerifyCodeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List verifyCodeRequestDescriptor = $convert.base64Decode(
    'ChFWZXJpZnlDb2RlUmVxdWVzdBIUCgVlbWFpbBgBIAEoCVIFZW1haWwSEgoEY29kZRgCIAEoCV'
    'IEY29kZRIfCghsYW5ndWFnZRgDIAEoCUgAUghsYW5ndWFnZYgBAUILCglfbGFuZ3VhZ2U=');

@$core.Deprecated('Use googleAuthRequestDescriptor instead')
const GoogleAuthRequest$json = {
  '1': 'GoogleAuthRequest',
  '2': [
    {'1': 'server_auth_code', '3': 1, '4': 1, '5': 9, '10': 'serverAuthCode'},
    {
      '1': 'language',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'language',
      '17': true
    },
    {
      '1': 'redirect_uri',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'redirectUri',
      '17': true
    },
  ],
  '8': [
    {'1': '_language'},
    {'1': '_redirect_uri'},
  ],
};

/// Descriptor for `GoogleAuthRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List googleAuthRequestDescriptor = $convert.base64Decode(
    'ChFHb29nbGVBdXRoUmVxdWVzdBIoChBzZXJ2ZXJfYXV0aF9jb2RlGAEgASgJUg5zZXJ2ZXJBdX'
    'RoQ29kZRIfCghsYW5ndWFnZRgCIAEoCUgAUghsYW5ndWFnZYgBARImCgxyZWRpcmVjdF91cmkY'
    'AyABKAlIAVILcmVkaXJlY3RVcmmIAQFCCwoJX2xhbmd1YWdlQg8KDV9yZWRpcmVjdF91cmk=');

@$core.Deprecated('Use logoutRequestDescriptor instead')
const LogoutRequest$json = {
  '1': 'LogoutRequest',
};

/// Descriptor for `LogoutRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logoutRequestDescriptor =
    $convert.base64Decode('Cg1Mb2dvdXRSZXF1ZXN0');

@$core.Deprecated('Use logoutResponseDescriptor instead')
const LogoutResponse$json = {
  '1': 'LogoutResponse',
  '2': [
    {'1': 'message', '3': 1, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `LogoutResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logoutResponseDescriptor = $convert
    .base64Decode('Cg5Mb2dvdXRSZXNwb25zZRIYCgdtZXNzYWdlGAEgASgJUgdtZXNzYWdl');

@$core.Deprecated('Use createTokenRequestDescriptor instead')
const CreateTokenRequest$json = {
  '1': 'CreateTokenRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `CreateTokenRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createTokenRequestDescriptor = $convert
    .base64Decode('ChJDcmVhdGVUb2tlblJlcXVlc3QSEgoEbmFtZRgBIAEoCVIEbmFtZQ==');

@$core.Deprecated('Use createTokenResponseDescriptor instead')
const CreateTokenResponse$json = {
  '1': 'CreateTokenResponse',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
    {'1': 'id', '3': 2, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'created_at', '3': 4, '4': 1, '5': 9, '10': 'createdAt'},
  ],
};

/// Descriptor for `CreateTokenResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createTokenResponseDescriptor = $convert.base64Decode(
    'ChNDcmVhdGVUb2tlblJlc3BvbnNlEhQKBXRva2VuGAEgASgJUgV0b2tlbhIOCgJpZBgCIAEoCV'
    'ICaWQSEgoEbmFtZRgDIAEoCVIEbmFtZRIdCgpjcmVhdGVkX2F0GAQgASgJUgljcmVhdGVkQXQ=');

@$core.Deprecated('Use listTokensRequestDescriptor instead')
const ListTokensRequest$json = {
  '1': 'ListTokensRequest',
};

/// Descriptor for `ListTokensRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTokensRequestDescriptor =
    $convert.base64Decode('ChFMaXN0VG9rZW5zUmVxdWVzdA==');

@$core.Deprecated('Use listTokensResponseDescriptor instead')
const ListTokensResponse$json = {
  '1': 'ListTokensResponse',
  '2': [
    {
      '1': 'tokens',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.mind.TokenDto',
      '10': 'tokens'
    },
  ],
};

/// Descriptor for `ListTokensResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTokensResponseDescriptor = $convert.base64Decode(
    'ChJMaXN0VG9rZW5zUmVzcG9uc2USJgoGdG9rZW5zGAEgAygLMg4ubWluZC5Ub2tlbkR0b1IGdG'
    '9rZW5z');

@$core.Deprecated('Use deleteTokenRequestDescriptor instead')
const DeleteTokenRequest$json = {
  '1': 'DeleteTokenRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteTokenRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteTokenRequestDescriptor =
    $convert.base64Decode('ChJEZWxldGVUb2tlblJlcXVlc3QSDgoCaWQYASABKAlSAmlk');

@$core.Deprecated('Use deleteTokenResponseDescriptor instead')
const DeleteTokenResponse$json = {
  '1': 'DeleteTokenResponse',
  '2': [
    {'1': 'message', '3': 1, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `DeleteTokenResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteTokenResponseDescriptor =
    $convert.base64Decode(
        'ChNEZWxldGVUb2tlblJlc3BvbnNlEhgKB21lc3NhZ2UYASABKAlSB21lc3NhZ2U=');
