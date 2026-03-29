// This is a generated file - do not edit.
//
// Generated from module_instruction_stream.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart' as $1;

import 'module_state.pb.dart' as $2;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// StreamSample is one instrumentation sample sent by the client.
/// session_id ties the sample to an active module session.
/// timestamp is int64 Unix millis — same convention as SessionErrorEvent.timestamp.
/// module_id identifies the producer module (e.g. "breath").
/// instruction_type is module-defined and names the specific measurement
/// (e.g. "breath_phase").
/// data carries the untyped payload so individual modules can evolve their
/// schemas independently without a proto change.
class StreamSample extends $pb.GeneratedMessage {
  factory StreamSample({
    $core.String? sessionId,
    $fixnum.Int64? timestamp,
    $core.String? moduleId,
    $core.String? instructionType,
    $1.Struct? data,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (timestamp != null) result.timestamp = timestamp;
    if (moduleId != null) result.moduleId = moduleId;
    if (instructionType != null) result.instructionType = instructionType;
    if (data != null) result.data = data;
    return result;
  }

  StreamSample._();

  factory StreamSample.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StreamSample.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamSample',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aInt64(2, _omitFieldNames ? '' : 'timestamp')
    ..aOS(3, _omitFieldNames ? '' : 'moduleId')
    ..aOS(4, _omitFieldNames ? '' : 'instructionType')
    ..aOM<$1.Struct>(5, _omitFieldNames ? '' : 'data',
        subBuilder: $1.Struct.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamSample clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamSample copyWith(void Function(StreamSample) updates) =>
      super.copyWith((message) => updates(message as StreamSample))
          as StreamSample;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StreamSample create() => StreamSample._();
  @$core.override
  StreamSample createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StreamSample getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamSample>(create);
  static StreamSample? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get timestamp => $_getI64(1);
  @$pb.TagNumber(2)
  set timestamp($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTimestamp() => $_has(1);
  @$pb.TagNumber(2)
  void clearTimestamp() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get moduleId => $_getSZ(2);
  @$pb.TagNumber(3)
  set moduleId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasModuleId() => $_has(2);
  @$pb.TagNumber(3)
  void clearModuleId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get instructionType => $_getSZ(3);
  @$pb.TagNumber(4)
  set instructionType($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasInstructionType() => $_has(3);
  @$pb.TagNumber(4)
  void clearInstructionType() => $_clearField(4);

  @$pb.TagNumber(5)
  $1.Struct get data => $_getN(4);
  @$pb.TagNumber(5)
  set data($1.Struct value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasData() => $_has(4);
  @$pb.TagNumber(5)
  void clearData() => $_clearField(5);
  @$pb.TagNumber(5)
  $1.Struct ensureData() => $_ensure(4);
}

/// StreamAck is the server acknowledgement for a batch of received samples.
/// received_count is the cumulative number of samples accepted in this stream.
/// dropped_count is the cumulative number of samples discarded (e.g. rate-limited).
/// max_samples_per_second is the server-side rate limit hint the client should
/// respect to avoid further drops.
/// timestamp is int64 Unix millis when the ack was produced.
class StreamAck extends $pb.GeneratedMessage {
  factory StreamAck({
    $core.String? sessionId,
    $fixnum.Int64? receivedCount,
    $fixnum.Int64? droppedCount,
    $core.int? maxSamplesPerSecond,
    $fixnum.Int64? timestamp,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (receivedCount != null) result.receivedCount = receivedCount;
    if (droppedCount != null) result.droppedCount = droppedCount;
    if (maxSamplesPerSecond != null)
      result.maxSamplesPerSecond = maxSamplesPerSecond;
    if (timestamp != null) result.timestamp = timestamp;
    return result;
  }

  StreamAck._();

  factory StreamAck.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StreamAck.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamAck',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aInt64(2, _omitFieldNames ? '' : 'receivedCount')
    ..aInt64(3, _omitFieldNames ? '' : 'droppedCount')
    ..aI(4, _omitFieldNames ? '' : 'maxSamplesPerSecond')
    ..aInt64(5, _omitFieldNames ? '' : 'timestamp')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamAck clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamAck copyWith(void Function(StreamAck) updates) =>
      super.copyWith((message) => updates(message as StreamAck)) as StreamAck;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StreamAck create() => StreamAck._();
  @$core.override
  StreamAck createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StreamAck getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StreamAck>(create);
  static StreamAck? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get receivedCount => $_getI64(1);
  @$pb.TagNumber(2)
  set receivedCount($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReceivedCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearReceivedCount() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get droppedCount => $_getI64(2);
  @$pb.TagNumber(3)
  set droppedCount($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDroppedCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearDroppedCount() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get maxSamplesPerSecond => $_getIZ(3);
  @$pb.TagNumber(4)
  set maxSamplesPerSecond($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMaxSamplesPerSecond() => $_has(3);
  @$pb.TagNumber(4)
  void clearMaxSamplesPerSecond() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get timestamp => $_getI64(4);
  @$pb.TagNumber(5)
  set timestamp($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTimestamp() => $_has(4);
  @$pb.TagNumber(5)
  void clearTimestamp() => $_clearField(5);
}

enum StreamResponse_Event { ack, error, notSet }

/// StreamResponse is the server-to-client stream envelope.
/// Each message carries exactly one event via the oneof.
/// SessionErrorEvent is imported from module_state.proto and reused for error reporting.
class StreamResponse extends $pb.GeneratedMessage {
  factory StreamResponse({
    StreamAck? ack,
    $2.SessionErrorEvent? error,
  }) {
    final result = create();
    if (ack != null) result.ack = ack;
    if (error != null) result.error = error;
    return result;
  }

  StreamResponse._();

  factory StreamResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StreamResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, StreamResponse_Event>
      _StreamResponse_EventByTag = {
    1: StreamResponse_Event.ack,
    2: StreamResponse_Event.error,
    0: StreamResponse_Event.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aOM<StreamAck>(1, _omitFieldNames ? '' : 'ack',
        subBuilder: StreamAck.create)
    ..aOM<$2.SessionErrorEvent>(2, _omitFieldNames ? '' : 'error',
        subBuilder: $2.SessionErrorEvent.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamResponse copyWith(void Function(StreamResponse) updates) =>
      super.copyWith((message) => updates(message as StreamResponse))
          as StreamResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StreamResponse create() => StreamResponse._();
  @$core.override
  StreamResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StreamResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamResponse>(create);
  static StreamResponse? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  StreamResponse_Event whichEvent() =>
      _StreamResponse_EventByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearEvent() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  StreamAck get ack => $_getN(0);
  @$pb.TagNumber(1)
  set ack(StreamAck value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasAck() => $_has(0);
  @$pb.TagNumber(1)
  void clearAck() => $_clearField(1);
  @$pb.TagNumber(1)
  StreamAck ensureAck() => $_ensure(0);

  @$pb.TagNumber(2)
  $2.SessionErrorEvent get error => $_getN(1);
  @$pb.TagNumber(2)
  set error($2.SessionErrorEvent value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(2)
  void clearError() => $_clearField(2);
  @$pb.TagNumber(2)
  $2.SessionErrorEvent ensureError() => $_ensure(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
