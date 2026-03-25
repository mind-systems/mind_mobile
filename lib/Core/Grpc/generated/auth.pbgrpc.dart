// This is a generated file - do not edit.
//
// Generated from auth.proto.

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

import 'auth.pb.dart' as $0;

export 'auth.pb.dart';

@$pb.GrpcServiceName('mind.AuthService')
class AuthServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  AuthServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.SendCodeResponse> sendCode(
    $0.SendCodeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$sendCode, request, options: options);
  }

  $grpc.ResponseFuture<$0.AuthResponse> verifyCode(
    $0.VerifyCodeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$verifyCode, request, options: options);
  }

  $grpc.ResponseFuture<$0.AuthResponse> googleAuth(
    $0.GoogleAuthRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$googleAuth, request, options: options);
  }

  $grpc.ResponseFuture<$0.LogoutResponse> logout(
    $0.LogoutRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$logout, request, options: options);
  }

  $grpc.ResponseFuture<$0.CreateTokenResponse> createToken(
    $0.CreateTokenRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createToken, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListTokensResponse> listTokens(
    $0.ListTokensRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listTokens, request, options: options);
  }

  $grpc.ResponseFuture<$0.DeleteTokenResponse> deleteToken(
    $0.DeleteTokenRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteToken, request, options: options);
  }

  // method descriptors

  static final _$sendCode =
      $grpc.ClientMethod<$0.SendCodeRequest, $0.SendCodeResponse>(
          '/mind.AuthService/SendCode',
          ($0.SendCodeRequest value) => value.writeToBuffer(),
          $0.SendCodeResponse.fromBuffer);
  static final _$verifyCode =
      $grpc.ClientMethod<$0.VerifyCodeRequest, $0.AuthResponse>(
          '/mind.AuthService/VerifyCode',
          ($0.VerifyCodeRequest value) => value.writeToBuffer(),
          $0.AuthResponse.fromBuffer);
  static final _$googleAuth =
      $grpc.ClientMethod<$0.GoogleAuthRequest, $0.AuthResponse>(
          '/mind.AuthService/GoogleAuth',
          ($0.GoogleAuthRequest value) => value.writeToBuffer(),
          $0.AuthResponse.fromBuffer);
  static final _$logout =
      $grpc.ClientMethod<$0.LogoutRequest, $0.LogoutResponse>(
          '/mind.AuthService/Logout',
          ($0.LogoutRequest value) => value.writeToBuffer(),
          $0.LogoutResponse.fromBuffer);
  static final _$createToken =
      $grpc.ClientMethod<$0.CreateTokenRequest, $0.CreateTokenResponse>(
          '/mind.AuthService/CreateToken',
          ($0.CreateTokenRequest value) => value.writeToBuffer(),
          $0.CreateTokenResponse.fromBuffer);
  static final _$listTokens =
      $grpc.ClientMethod<$0.ListTokensRequest, $0.ListTokensResponse>(
          '/mind.AuthService/ListTokens',
          ($0.ListTokensRequest value) => value.writeToBuffer(),
          $0.ListTokensResponse.fromBuffer);
  static final _$deleteToken =
      $grpc.ClientMethod<$0.DeleteTokenRequest, $0.DeleteTokenResponse>(
          '/mind.AuthService/DeleteToken',
          ($0.DeleteTokenRequest value) => value.writeToBuffer(),
          $0.DeleteTokenResponse.fromBuffer);
}

@$pb.GrpcServiceName('mind.AuthService')
abstract class AuthServiceBase extends $grpc.Service {
  $core.String get $name => 'mind.AuthService';

  AuthServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.SendCodeRequest, $0.SendCodeResponse>(
        'SendCode',
        sendCode_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SendCodeRequest.fromBuffer(value),
        ($0.SendCodeResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.VerifyCodeRequest, $0.AuthResponse>(
        'VerifyCode',
        verifyCode_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.VerifyCodeRequest.fromBuffer(value),
        ($0.AuthResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GoogleAuthRequest, $0.AuthResponse>(
        'GoogleAuth',
        googleAuth_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GoogleAuthRequest.fromBuffer(value),
        ($0.AuthResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.LogoutRequest, $0.LogoutResponse>(
        'Logout',
        logout_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.LogoutRequest.fromBuffer(value),
        ($0.LogoutResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.CreateTokenRequest, $0.CreateTokenResponse>(
            'CreateToken',
            createToken_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.CreateTokenRequest.fromBuffer(value),
            ($0.CreateTokenResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListTokensRequest, $0.ListTokensResponse>(
        'ListTokens',
        listTokens_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListTokensRequest.fromBuffer(value),
        ($0.ListTokensResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.DeleteTokenRequest, $0.DeleteTokenResponse>(
            'DeleteToken',
            deleteToken_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.DeleteTokenRequest.fromBuffer(value),
            ($0.DeleteTokenResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.SendCodeResponse> sendCode_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SendCodeRequest> $request) async {
    return sendCode($call, await $request);
  }

  $async.Future<$0.SendCodeResponse> sendCode(
      $grpc.ServiceCall call, $0.SendCodeRequest request);

  $async.Future<$0.AuthResponse> verifyCode_Pre($grpc.ServiceCall $call,
      $async.Future<$0.VerifyCodeRequest> $request) async {
    return verifyCode($call, await $request);
  }

  $async.Future<$0.AuthResponse> verifyCode(
      $grpc.ServiceCall call, $0.VerifyCodeRequest request);

  $async.Future<$0.AuthResponse> googleAuth_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GoogleAuthRequest> $request) async {
    return googleAuth($call, await $request);
  }

  $async.Future<$0.AuthResponse> googleAuth(
      $grpc.ServiceCall call, $0.GoogleAuthRequest request);

  $async.Future<$0.LogoutResponse> logout_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.LogoutRequest> $request) async {
    return logout($call, await $request);
  }

  $async.Future<$0.LogoutResponse> logout(
      $grpc.ServiceCall call, $0.LogoutRequest request);

  $async.Future<$0.CreateTokenResponse> createToken_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateTokenRequest> $request) async {
    return createToken($call, await $request);
  }

  $async.Future<$0.CreateTokenResponse> createToken(
      $grpc.ServiceCall call, $0.CreateTokenRequest request);

  $async.Future<$0.ListTokensResponse> listTokens_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ListTokensRequest> $request) async {
    return listTokens($call, await $request);
  }

  $async.Future<$0.ListTokensResponse> listTokens(
      $grpc.ServiceCall call, $0.ListTokensRequest request);

  $async.Future<$0.DeleteTokenResponse> deleteToken_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DeleteTokenRequest> $request) async {
    return deleteToken($call, await $request);
  }

  $async.Future<$0.DeleteTokenResponse> deleteToken(
      $grpc.ServiceCall call, $0.DeleteTokenRequest request);
}
