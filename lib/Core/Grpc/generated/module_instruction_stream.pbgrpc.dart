// This is a generated file - do not edit.
//
// Generated from module_instruction_stream.proto.

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

import 'module_instruction_stream.pb.dart' as $0;

export 'module_instruction_stream.pb.dart';

@$pb.GrpcServiceName('mind.ModuleInstructionStreamService')
class ModuleInstructionStreamServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  ModuleInstructionStreamServiceClient(super.channel,
      {super.options, super.interceptors});

  $grpc.ResponseStream<$0.StreamResponse> streamData(
    $async.Stream<$0.StreamSample> request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$streamData, request, options: options);
  }

  // method descriptors

  static final _$streamData =
      $grpc.ClientMethod<$0.StreamSample, $0.StreamResponse>(
          '/mind.ModuleInstructionStreamService/StreamData',
          ($0.StreamSample value) => value.writeToBuffer(),
          $0.StreamResponse.fromBuffer);
}

@$pb.GrpcServiceName('mind.ModuleInstructionStreamService')
abstract class ModuleInstructionStreamServiceBase extends $grpc.Service {
  $core.String get $name => 'mind.ModuleInstructionStreamService';

  ModuleInstructionStreamServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.StreamSample, $0.StreamResponse>(
        'StreamData',
        streamData,
        true,
        true,
        ($core.List<$core.int> value) => $0.StreamSample.fromBuffer(value),
        ($0.StreamResponse value) => value.writeToBuffer()));
  }

  $async.Stream<$0.StreamResponse> streamData(
      $grpc.ServiceCall call, $async.Stream<$0.StreamSample> request);
}
