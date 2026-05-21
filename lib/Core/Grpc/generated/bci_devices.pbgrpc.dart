// This is a generated file - do not edit.
//
// Generated from bci_devices.proto.

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
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $0;

import 'bci_devices.pb.dart' as $1;

export 'bci_devices.pb.dart';

@$pb.GrpcServiceName('mind.BciDevicesService')
class BciDevicesServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  BciDevicesServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$1.ListBciDevicesResponse> list(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$list, request, options: options);
  }

  $grpc.ResponseFuture<$1.BciDevice> register(
    $1.RegisterBciDeviceRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$register, request, options: options);
  }

  $grpc.ResponseFuture<$0.Empty> delete(
    $1.DeleteBciDeviceRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$delete, request, options: options);
  }

  // method descriptors

  static final _$list = $grpc.ClientMethod<$0.Empty, $1.ListBciDevicesResponse>(
      '/mind.BciDevicesService/List',
      ($0.Empty value) => value.writeToBuffer(),
      $1.ListBciDevicesResponse.fromBuffer);
  static final _$register =
      $grpc.ClientMethod<$1.RegisterBciDeviceRequest, $1.BciDevice>(
          '/mind.BciDevicesService/Register',
          ($1.RegisterBciDeviceRequest value) => value.writeToBuffer(),
          $1.BciDevice.fromBuffer);
  static final _$delete =
      $grpc.ClientMethod<$1.DeleteBciDeviceRequest, $0.Empty>(
          '/mind.BciDevicesService/Delete',
          ($1.DeleteBciDeviceRequest value) => value.writeToBuffer(),
          $0.Empty.fromBuffer);
}

@$pb.GrpcServiceName('mind.BciDevicesService')
abstract class BciDevicesServiceBase extends $grpc.Service {
  $core.String get $name => 'mind.BciDevicesService';

  BciDevicesServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.Empty, $1.ListBciDevicesResponse>(
        'List',
        list_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($1.ListBciDevicesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.RegisterBciDeviceRequest, $1.BciDevice>(
        'Register',
        register_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $1.RegisterBciDeviceRequest.fromBuffer(value),
        ($1.BciDevice value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.DeleteBciDeviceRequest, $0.Empty>(
        'Delete',
        delete_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $1.DeleteBciDeviceRequest.fromBuffer(value),
        ($0.Empty value) => value.writeToBuffer()));
  }

  $async.Future<$1.ListBciDevicesResponse> list_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return list($call, await $request);
  }

  $async.Future<$1.ListBciDevicesResponse> list(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$1.BciDevice> register_Pre($grpc.ServiceCall $call,
      $async.Future<$1.RegisterBciDeviceRequest> $request) async {
    return register($call, await $request);
  }

  $async.Future<$1.BciDevice> register(
      $grpc.ServiceCall call, $1.RegisterBciDeviceRequest request);

  $async.Future<$0.Empty> delete_Pre($grpc.ServiceCall $call,
      $async.Future<$1.DeleteBciDeviceRequest> $request) async {
    return delete($call, await $request);
  }

  $async.Future<$0.Empty> delete(
      $grpc.ServiceCall call, $1.DeleteBciDeviceRequest request);
}
