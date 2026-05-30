// This is a generated file - do not edit.
//
// Generated from nfb_calibration.proto.

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

import 'nfb_calibration.pb.dart' as $0;

export 'nfb_calibration.pb.dart';

@$pb.GrpcServiceName('mind.NfbCalibrationService')
class NfbCalibrationServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  NfbCalibrationServiceClient(super.channel,
      {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.NfbCalibrationRecord> record(
    $0.RecordNfbCalibrationRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$record, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListNfbCalibrationsResponse> list(
    $0.ListNfbCalibrationsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$list, request, options: options);
  }

  // method descriptors

  static final _$record = $grpc.ClientMethod<$0.RecordNfbCalibrationRequest,
          $0.NfbCalibrationRecord>(
      '/mind.NfbCalibrationService/Record',
      ($0.RecordNfbCalibrationRequest value) => value.writeToBuffer(),
      $0.NfbCalibrationRecord.fromBuffer);
  static final _$list = $grpc.ClientMethod<$0.ListNfbCalibrationsRequest,
          $0.ListNfbCalibrationsResponse>(
      '/mind.NfbCalibrationService/List',
      ($0.ListNfbCalibrationsRequest value) => value.writeToBuffer(),
      $0.ListNfbCalibrationsResponse.fromBuffer);
}

@$pb.GrpcServiceName('mind.NfbCalibrationService')
abstract class NfbCalibrationServiceBase extends $grpc.Service {
  $core.String get $name => 'mind.NfbCalibrationService';

  NfbCalibrationServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.RecordNfbCalibrationRequest,
            $0.NfbCalibrationRecord>(
        'Record',
        record_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RecordNfbCalibrationRequest.fromBuffer(value),
        ($0.NfbCalibrationRecord value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListNfbCalibrationsRequest,
            $0.ListNfbCalibrationsResponse>(
        'List',
        list_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ListNfbCalibrationsRequest.fromBuffer(value),
        ($0.ListNfbCalibrationsResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.NfbCalibrationRecord> record_Pre($grpc.ServiceCall $call,
      $async.Future<$0.RecordNfbCalibrationRequest> $request) async {
    return record($call, await $request);
  }

  $async.Future<$0.NfbCalibrationRecord> record(
      $grpc.ServiceCall call, $0.RecordNfbCalibrationRequest request);

  $async.Future<$0.ListNfbCalibrationsResponse> list_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListNfbCalibrationsRequest> $request) async {
    return list($call, await $request);
  }

  $async.Future<$0.ListNfbCalibrationsResponse> list(
      $grpc.ServiceCall call, $0.ListNfbCalibrationsRequest request);
}
