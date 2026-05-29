// This is a generated file - do not edit.
//
// Generated from module_biometric_stream.proto.

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

import 'module_biometric_stream.pb.dart' as $0;

export 'module_biometric_stream.pb.dart';

@$pb.GrpcServiceName('mind.ModuleBiometricStreamService')
class ModuleBiometricStreamServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  ModuleBiometricStreamServiceClient(super.channel,
      {super.options, super.interceptors});

  $grpc.ResponseStream<$0.BioStreamResponse> streamData(
    $async.Stream<$0.BioSampleBatch> request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$streamData, request, options: options);
  }

  // method descriptors

  static final _$streamData =
      $grpc.ClientMethod<$0.BioSampleBatch, $0.BioStreamResponse>(
          '/mind.ModuleBiometricStreamService/StreamData',
          ($0.BioSampleBatch value) => value.writeToBuffer(),
          $0.BioStreamResponse.fromBuffer);
}

@$pb.GrpcServiceName('mind.ModuleBiometricStreamService')
abstract class ModuleBiometricStreamServiceBase extends $grpc.Service {
  $core.String get $name => 'mind.ModuleBiometricStreamService';

  ModuleBiometricStreamServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.BioSampleBatch, $0.BioStreamResponse>(
        'StreamData',
        streamData,
        true,
        true,
        ($core.List<$core.int> value) => $0.BioSampleBatch.fromBuffer(value),
        ($0.BioStreamResponse value) => value.writeToBuffer()));
  }

  $async.Stream<$0.BioStreamResponse> streamData(
      $grpc.ServiceCall call, $async.Stream<$0.BioSampleBatch> request);
}
