// This is a generated file - do not edit.
//
// Generated from meditation_poses.proto.

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

import 'meditation_poses.pb.dart' as $1;

export 'meditation_poses.pb.dart';

@$pb.GrpcServiceName('mind.MeditationPosesService')
class MeditationPosesServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  MeditationPosesServiceClient(super.channel,
      {super.options, super.interceptors});

  $grpc.ResponseFuture<$1.ListMeditationPosesResponse> listPoses(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listPoses, request, options: options);
  }

  // method descriptors

  static final _$listPoses =
      $grpc.ClientMethod<$0.Empty, $1.ListMeditationPosesResponse>(
          '/mind.MeditationPosesService/ListPoses',
          ($0.Empty value) => value.writeToBuffer(),
          $1.ListMeditationPosesResponse.fromBuffer);
}

@$pb.GrpcServiceName('mind.MeditationPosesService')
abstract class MeditationPosesServiceBase extends $grpc.Service {
  $core.String get $name => 'mind.MeditationPosesService';

  MeditationPosesServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.Empty, $1.ListMeditationPosesResponse>(
        'ListPoses',
        listPoses_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($1.ListMeditationPosesResponse value) => value.writeToBuffer()));
  }

  $async.Future<$1.ListMeditationPosesResponse> listPoses_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return listPoses($call, await $request);
  }

  $async.Future<$1.ListMeditationPosesResponse> listPoses(
      $grpc.ServiceCall call, $0.Empty request);
}
