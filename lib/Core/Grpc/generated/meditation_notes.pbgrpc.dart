// This is a generated file - do not edit.
//
// Generated from meditation_notes.proto.

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

import 'meditation_notes.pb.dart' as $0;

export 'meditation_notes.pb.dart';

@$pb.GrpcServiceName('mind.MeditationNotesService')
class MeditationNotesServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  MeditationNotesServiceClient(super.channel,
      {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.MeditationNote> createNote(
    $0.CreateNoteRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createNote, request, options: options);
  }

  $grpc.ResponseFuture<$0.MeditationNote> updateNote(
    $0.UpdateNoteRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateNote, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListNotesResponse> listNotes(
    $0.ListNotesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listNotes, request, options: options);
  }

  // method descriptors

  static final _$createNote =
      $grpc.ClientMethod<$0.CreateNoteRequest, $0.MeditationNote>(
          '/mind.MeditationNotesService/CreateNote',
          ($0.CreateNoteRequest value) => value.writeToBuffer(),
          $0.MeditationNote.fromBuffer);
  static final _$updateNote =
      $grpc.ClientMethod<$0.UpdateNoteRequest, $0.MeditationNote>(
          '/mind.MeditationNotesService/UpdateNote',
          ($0.UpdateNoteRequest value) => value.writeToBuffer(),
          $0.MeditationNote.fromBuffer);
  static final _$listNotes =
      $grpc.ClientMethod<$0.ListNotesRequest, $0.ListNotesResponse>(
          '/mind.MeditationNotesService/ListNotes',
          ($0.ListNotesRequest value) => value.writeToBuffer(),
          $0.ListNotesResponse.fromBuffer);
}

@$pb.GrpcServiceName('mind.MeditationNotesService')
abstract class MeditationNotesServiceBase extends $grpc.Service {
  $core.String get $name => 'mind.MeditationNotesService';

  MeditationNotesServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CreateNoteRequest, $0.MeditationNote>(
        'CreateNote',
        createNote_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CreateNoteRequest.fromBuffer(value),
        ($0.MeditationNote value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateNoteRequest, $0.MeditationNote>(
        'UpdateNote',
        updateNote_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.UpdateNoteRequest.fromBuffer(value),
        ($0.MeditationNote value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListNotesRequest, $0.ListNotesResponse>(
        'ListNotes',
        listNotes_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListNotesRequest.fromBuffer(value),
        ($0.ListNotesResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.MeditationNote> createNote_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateNoteRequest> $request) async {
    return createNote($call, await $request);
  }

  $async.Future<$0.MeditationNote> createNote(
      $grpc.ServiceCall call, $0.CreateNoteRequest request);

  $async.Future<$0.MeditationNote> updateNote_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdateNoteRequest> $request) async {
    return updateNote($call, await $request);
  }

  $async.Future<$0.MeditationNote> updateNote(
      $grpc.ServiceCall call, $0.UpdateNoteRequest request);

  $async.Future<$0.ListNotesResponse> listNotes_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ListNotesRequest> $request) async {
    return listNotes($call, await $request);
  }

  $async.Future<$0.ListNotesResponse> listNotes(
      $grpc.ServiceCall call, $0.ListNotesRequest request);
}
