// This is a generated file - do not edit.
//
// Generated from module_state.proto.

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

import 'module_state.pb.dart' as $0;

export 'module_state.pb.dart';

@$pb.GrpcServiceName('mind.ModuleStateService')
class ModuleStateServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  ModuleStateServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseStream<$0.StateResponse> trackActivity(
    $async.Stream<$0.StateRequest> request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$trackActivity, request, options: options);
  }

  // method descriptors

  static final _$trackActivity =
      $grpc.ClientMethod<$0.StateRequest, $0.StateResponse>(
          '/mind.ModuleStateService/TrackActivity',
          ($0.StateRequest value) => value.writeToBuffer(),
          $0.StateResponse.fromBuffer);
}

@$pb.GrpcServiceName('mind.ModuleStateService')
abstract class ModuleStateServiceBase extends $grpc.Service {
  $core.String get $name => 'mind.ModuleStateService';

  ModuleStateServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.StateRequest, $0.StateResponse>(
        'TrackActivity',
        trackActivity,
        true,
        true,
        ($core.List<$core.int> value) => $0.StateRequest.fromBuffer(value),
        ($0.StateResponse value) => value.writeToBuffer()));
  }

  $async.Stream<$0.StateResponse> trackActivity(
      $grpc.ServiceCall call, $async.Stream<$0.StateRequest> request);
}
