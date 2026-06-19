// This is a generated file - do not edit.
//
// Generated from breath_sessions.proto.

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

import 'breath_sessions.pb.dart' as $0;

export 'breath_sessions.pb.dart';

@$pb.GrpcServiceName('mind.BreathSessionService')
class BreathSessionServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  BreathSessionServiceClient(super.channel,
      {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.BreathSessionDto> createSession(
    $0.CreateSessionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createSession, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListSessionsResponse> listSessions(
    $0.ListSessionsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listSessions, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetSuggestionsResponse> getSuggestions(
    $0.GetSuggestionsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getSuggestions, request, options: options);
  }

  $grpc.ResponseFuture<$0.BatchGetSessionsResponse> batchGetSessions(
    $0.BatchGetSessionsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$batchGetSessions, request, options: options);
  }

  $grpc.ResponseFuture<$0.BreathSessionWithStarredDto> getSession(
    $0.GetSessionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getSession, request, options: options);
  }

  $grpc.ResponseFuture<$0.BreathSessionDto> updateSession(
    $0.UpdateSessionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateSession, request, options: options);
  }

  $grpc.ResponseFuture<$0.UpdateSessionSettingsResponse> updateSessionSettings(
    $0.UpdateSessionSettingsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateSessionSettings, request, options: options);
  }

  $grpc.ResponseFuture<$0.DeleteSessionResponse> deleteSession(
    $0.DeleteSessionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteSession, request, options: options);
  }

  // method descriptors

  static final _$createSession =
      $grpc.ClientMethod<$0.CreateSessionRequest, $0.BreathSessionDto>(
          '/mind.BreathSessionService/CreateSession',
          ($0.CreateSessionRequest value) => value.writeToBuffer(),
          $0.BreathSessionDto.fromBuffer);
  static final _$listSessions =
      $grpc.ClientMethod<$0.ListSessionsRequest, $0.ListSessionsResponse>(
          '/mind.BreathSessionService/ListSessions',
          ($0.ListSessionsRequest value) => value.writeToBuffer(),
          $0.ListSessionsResponse.fromBuffer);
  static final _$getSuggestions =
      $grpc.ClientMethod<$0.GetSuggestionsRequest, $0.GetSuggestionsResponse>(
          '/mind.BreathSessionService/GetSuggestions',
          ($0.GetSuggestionsRequest value) => value.writeToBuffer(),
          $0.GetSuggestionsResponse.fromBuffer);
  static final _$batchGetSessions = $grpc.ClientMethod<
          $0.BatchGetSessionsRequest, $0.BatchGetSessionsResponse>(
      '/mind.BreathSessionService/BatchGetSessions',
      ($0.BatchGetSessionsRequest value) => value.writeToBuffer(),
      $0.BatchGetSessionsResponse.fromBuffer);
  static final _$getSession =
      $grpc.ClientMethod<$0.GetSessionRequest, $0.BreathSessionWithStarredDto>(
          '/mind.BreathSessionService/GetSession',
          ($0.GetSessionRequest value) => value.writeToBuffer(),
          $0.BreathSessionWithStarredDto.fromBuffer);
  static final _$updateSession =
      $grpc.ClientMethod<$0.UpdateSessionRequest, $0.BreathSessionDto>(
          '/mind.BreathSessionService/UpdateSession',
          ($0.UpdateSessionRequest value) => value.writeToBuffer(),
          $0.BreathSessionDto.fromBuffer);
  static final _$updateSessionSettings = $grpc.ClientMethod<
          $0.UpdateSessionSettingsRequest, $0.UpdateSessionSettingsResponse>(
      '/mind.BreathSessionService/UpdateSessionSettings',
      ($0.UpdateSessionSettingsRequest value) => value.writeToBuffer(),
      $0.UpdateSessionSettingsResponse.fromBuffer);
  static final _$deleteSession =
      $grpc.ClientMethod<$0.DeleteSessionRequest, $0.DeleteSessionResponse>(
          '/mind.BreathSessionService/DeleteSession',
          ($0.DeleteSessionRequest value) => value.writeToBuffer(),
          $0.DeleteSessionResponse.fromBuffer);
}

@$pb.GrpcServiceName('mind.BreathSessionService')
abstract class BreathSessionServiceBase extends $grpc.Service {
  $core.String get $name => 'mind.BreathSessionService';

  BreathSessionServiceBase() {
    $addMethod(
        $grpc.ServiceMethod<$0.CreateSessionRequest, $0.BreathSessionDto>(
            'CreateSession',
            createSession_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.CreateSessionRequest.fromBuffer(value),
            ($0.BreathSessionDto value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ListSessionsRequest, $0.ListSessionsResponse>(
            'ListSessions',
            listSessions_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ListSessionsRequest.fromBuffer(value),
            ($0.ListSessionsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetSuggestionsRequest,
            $0.GetSuggestionsResponse>(
        'GetSuggestions',
        getSuggestions_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetSuggestionsRequest.fromBuffer(value),
        ($0.GetSuggestionsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.BatchGetSessionsRequest,
            $0.BatchGetSessionsResponse>(
        'BatchGetSessions',
        batchGetSessions_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.BatchGetSessionsRequest.fromBuffer(value),
        ($0.BatchGetSessionsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetSessionRequest,
            $0.BreathSessionWithStarredDto>(
        'GetSession',
        getSession_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetSessionRequest.fromBuffer(value),
        ($0.BreathSessionWithStarredDto value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.UpdateSessionRequest, $0.BreathSessionDto>(
            'UpdateSession',
            updateSession_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.UpdateSessionRequest.fromBuffer(value),
            ($0.BreathSessionDto value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateSessionSettingsRequest,
            $0.UpdateSessionSettingsResponse>(
        'UpdateSessionSettings',
        updateSessionSettings_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdateSessionSettingsRequest.fromBuffer(value),
        ($0.UpdateSessionSettingsResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.DeleteSessionRequest, $0.DeleteSessionResponse>(
            'DeleteSession',
            deleteSession_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.DeleteSessionRequest.fromBuffer(value),
            ($0.DeleteSessionResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.BreathSessionDto> createSession_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateSessionRequest> $request) async {
    return createSession($call, await $request);
  }

  $async.Future<$0.BreathSessionDto> createSession(
      $grpc.ServiceCall call, $0.CreateSessionRequest request);

  $async.Future<$0.ListSessionsResponse> listSessions_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListSessionsRequest> $request) async {
    return listSessions($call, await $request);
  }

  $async.Future<$0.ListSessionsResponse> listSessions(
      $grpc.ServiceCall call, $0.ListSessionsRequest request);

  $async.Future<$0.GetSuggestionsResponse> getSuggestions_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetSuggestionsRequest> $request) async {
    return getSuggestions($call, await $request);
  }

  $async.Future<$0.GetSuggestionsResponse> getSuggestions(
      $grpc.ServiceCall call, $0.GetSuggestionsRequest request);

  $async.Future<$0.BatchGetSessionsResponse> batchGetSessions_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.BatchGetSessionsRequest> $request) async {
    return batchGetSessions($call, await $request);
  }

  $async.Future<$0.BatchGetSessionsResponse> batchGetSessions(
      $grpc.ServiceCall call, $0.BatchGetSessionsRequest request);

  $async.Future<$0.BreathSessionWithStarredDto> getSession_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetSessionRequest> $request) async {
    return getSession($call, await $request);
  }

  $async.Future<$0.BreathSessionWithStarredDto> getSession(
      $grpc.ServiceCall call, $0.GetSessionRequest request);

  $async.Future<$0.BreathSessionDto> updateSession_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdateSessionRequest> $request) async {
    return updateSession($call, await $request);
  }

  $async.Future<$0.BreathSessionDto> updateSession(
      $grpc.ServiceCall call, $0.UpdateSessionRequest request);

  $async.Future<$0.UpdateSessionSettingsResponse> updateSessionSettings_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdateSessionSettingsRequest> $request) async {
    return updateSessionSettings($call, await $request);
  }

  $async.Future<$0.UpdateSessionSettingsResponse> updateSessionSettings(
      $grpc.ServiceCall call, $0.UpdateSessionSettingsRequest request);

  $async.Future<$0.DeleteSessionResponse> deleteSession_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.DeleteSessionRequest> $request) async {
    return deleteSession($call, await $request);
  }

  $async.Future<$0.DeleteSessionResponse> deleteSession(
      $grpc.ServiceCall call, $0.DeleteSessionRequest request);
}
