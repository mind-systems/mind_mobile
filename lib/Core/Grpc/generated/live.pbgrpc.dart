// This is a generated file - do not edit.
//
// Generated from live.proto.

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

import 'live.pb.dart' as $0;

export 'live.pb.dart';

@$pb.GrpcServiceName('mind.LiveService')
class LiveServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  LiveServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseStream<$0.LiveResponse> liveSession(
    $async.Stream<$0.LiveRequest> request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$liveSession, request, options: options);
  }

  // method descriptors

  static final _$liveSession =
      $grpc.ClientMethod<$0.LiveRequest, $0.LiveResponse>(
          '/mind.LiveService/LiveSession',
          ($0.LiveRequest value) => value.writeToBuffer(),
          $0.LiveResponse.fromBuffer);
}

@$pb.GrpcServiceName('mind.LiveService')
abstract class LiveServiceBase extends $grpc.Service {
  $core.String get $name => 'mind.LiveService';

  LiveServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.LiveRequest, $0.LiveResponse>(
        'LiveSession',
        liveSession,
        true,
        true,
        ($core.List<$core.int> value) => $0.LiveRequest.fromBuffer(value),
        ($0.LiveResponse value) => value.writeToBuffer()));
  }

  $async.Stream<$0.LiveResponse> liveSession(
      $grpc.ServiceCall call, $async.Stream<$0.LiveRequest> request);
}
