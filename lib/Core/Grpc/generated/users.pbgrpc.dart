// This is a generated file - do not edit.
//
// Generated from users.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'auth.pb.dart' as $1;
import 'users.pb.dart' as $0;

export 'users.pb.dart';

@$pb.GrpcServiceName('mind.UserService')
class UserServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  UserServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$1.UserDto> updateProfile(
    $0.UpdateProfileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateProfile, request, options: options);
  }

  // method descriptors

  static final _$updateProfile =
      $grpc.ClientMethod<$0.UpdateProfileRequest, $1.UserDto>(
          '/mind.UserService/UpdateProfile',
          ($0.UpdateProfileRequest value) => value.writeToBuffer(),
          $1.UserDto.fromBuffer);
}

@$pb.GrpcServiceName('mind.UserService')
abstract class UserServiceBase extends $grpc.Service {
  $core.String get $name => 'mind.UserService';

  UserServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.UpdateProfileRequest, $1.UserDto>(
        'UpdateProfile',
        updateProfile_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdateProfileRequest.fromBuffer(value),
        ($1.UserDto value) => value.writeToBuffer()));
  }

  $async.Future<$1.UserDto> updateProfile_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdateProfileRequest> $request) async {
    return updateProfile($call, await $request);
  }

  $async.Future<$1.UserDto> updateProfile(
      $grpc.ServiceCall call, $0.UpdateProfileRequest request);
}
