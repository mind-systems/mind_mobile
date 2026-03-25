// This is a generated file - do not edit.
//
// Generated from telemetry.proto.

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

import 'telemetry.pb.dart' as $0;

export 'telemetry.pb.dart';

@$pb.GrpcServiceName('mind.TelemetryService')
class TelemetryServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  TelemetryServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseStream<$0.TelemetryResponse> streamTelemetry(
    $async.Stream<$0.TelemetryData> request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$streamTelemetry, request, options: options);
  }

  // method descriptors

  static final _$streamTelemetry =
      $grpc.ClientMethod<$0.TelemetryData, $0.TelemetryResponse>(
          '/mind.TelemetryService/StreamTelemetry',
          ($0.TelemetryData value) => value.writeToBuffer(),
          $0.TelemetryResponse.fromBuffer);
}

@$pb.GrpcServiceName('mind.TelemetryService')
abstract class TelemetryServiceBase extends $grpc.Service {
  $core.String get $name => 'mind.TelemetryService';

  TelemetryServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.TelemetryData, $0.TelemetryResponse>(
        'StreamTelemetry',
        streamTelemetry,
        true,
        true,
        ($core.List<$core.int> value) => $0.TelemetryData.fromBuffer(value),
        ($0.TelemetryResponse value) => value.writeToBuffer()));
  }

  $async.Stream<$0.TelemetryResponse> streamTelemetry(
      $grpc.ServiceCall call, $async.Stream<$0.TelemetryData> request);
}
