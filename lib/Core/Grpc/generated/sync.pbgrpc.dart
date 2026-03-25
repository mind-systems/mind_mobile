// This is a generated file - do not edit.
//
// Generated from sync.proto.

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

import 'sync.pb.dart' as $0;

export 'sync.pb.dart';

@$pb.GrpcServiceName('mind.SyncService')
class SyncServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  SyncServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.GetChangesResponse> getChanges(
    $0.GetChangesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getChanges, request, options: options);
  }

  $grpc.ResponseStream<$0.ChangeEvent> watchChanges(
    $0.WatchChangesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$watchChanges, $async.Stream.fromIterable([request]),
        options: options);
  }

  // method descriptors

  static final _$getChanges =
      $grpc.ClientMethod<$0.GetChangesRequest, $0.GetChangesResponse>(
          '/mind.SyncService/GetChanges',
          ($0.GetChangesRequest value) => value.writeToBuffer(),
          $0.GetChangesResponse.fromBuffer);
  static final _$watchChanges =
      $grpc.ClientMethod<$0.WatchChangesRequest, $0.ChangeEvent>(
          '/mind.SyncService/WatchChanges',
          ($0.WatchChangesRequest value) => value.writeToBuffer(),
          $0.ChangeEvent.fromBuffer);
}

@$pb.GrpcServiceName('mind.SyncService')
abstract class SyncServiceBase extends $grpc.Service {
  $core.String get $name => 'mind.SyncService';

  SyncServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.GetChangesRequest, $0.GetChangesResponse>(
        'GetChanges',
        getChanges_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetChangesRequest.fromBuffer(value),
        ($0.GetChangesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.WatchChangesRequest, $0.ChangeEvent>(
        'WatchChanges',
        watchChanges_Pre,
        false,
        true,
        ($core.List<$core.int> value) =>
            $0.WatchChangesRequest.fromBuffer(value),
        ($0.ChangeEvent value) => value.writeToBuffer()));
  }

  $async.Future<$0.GetChangesResponse> getChanges_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetChangesRequest> $request) async {
    return getChanges($call, await $request);
  }

  $async.Future<$0.GetChangesResponse> getChanges(
      $grpc.ServiceCall call, $0.GetChangesRequest request);

  $async.Stream<$0.ChangeEvent> watchChanges_Pre($grpc.ServiceCall $call,
      $async.Future<$0.WatchChangesRequest> $request) async* {
    yield* watchChanges($call, await $request);
  }

  $async.Stream<$0.ChangeEvent> watchChanges(
      $grpc.ServiceCall call, $0.WatchChangesRequest request);
}
