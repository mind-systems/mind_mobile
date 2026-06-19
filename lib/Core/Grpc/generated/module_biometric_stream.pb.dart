// This is a generated file - do not edit.
//
// Generated from module_biometric_stream.proto.

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

/// BioSample is one biometric data point sent by the client.
/// session_id ties the sample to an active module session.
/// timestamp is int64 Unix millis — same convention as StateErrorEvent.timestamp.
/// sample_type is a free-string discriminator identifying the biometric kind
/// (e.g. "cardio", "emotions", "nfb"). There is intentionally no module_id:
/// biometric data is not module-shaped; the producing module is implied by
/// the module_sessions.activityType of the associated session.
/// data carries the untyped payload so individual sample types can evolve their
/// schemas independently without a proto change.
class BioSample extends $pb.GeneratedMessage {
  factory BioSample({
    $core.String? sessionId,
    $fixnum.Int64? timestamp,
    $core.String? sampleType,
    $1.Struct? data,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (timestamp != null) result.timestamp = timestamp;
    if (sampleType != null) result.sampleType = sampleType;
    if (data != null) result.data = data;
    return result;
  }

  BioSample._();

  factory BioSample.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BioSample.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BioSample',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aInt64(2, _omitFieldNames ? '' : 'timestamp')
    ..aOS(3, _omitFieldNames ? '' : 'sampleType')
    ..aOM<$1.Struct>(4, _omitFieldNames ? '' : 'data',
        subBuilder: $1.Struct.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BioSample clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BioSample copyWith(void Function(BioSample) updates) =>
      super.copyWith((message) => updates(message as BioSample)) as BioSample;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BioSample create() => BioSample._();
  @$core.override
  BioSample createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BioSample getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BioSample>(create);
  static BioSample? _defaultInstance;

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
  $core.String get sampleType => $_getSZ(2);
  @$pb.TagNumber(3)
  set sampleType($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSampleType() => $_has(2);
  @$pb.TagNumber(3)
  void clearSampleType() => $_clearField(3);

  @$pb.TagNumber(4)
  $1.Struct get data => $_getN(3);
  @$pb.TagNumber(4)
  set data($1.Struct value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasData() => $_has(3);
  @$pb.TagNumber(4)
  void clearData() => $_clearField(4);
  @$pb.TagNumber(4)
  $1.Struct ensureData() => $_ensure(3);
}

/// BioSampleBatch groups multiple BioSample messages into one stream frame to
/// reduce per-message overhead over the bidi connection.
class BioSampleBatch extends $pb.GeneratedMessage {
  factory BioSampleBatch({
    $core.Iterable<BioSample>? samples,
  }) {
    final result = create();
    if (samples != null) result.samples.addAll(samples);
    return result;
  }

  BioSampleBatch._();

  factory BioSampleBatch.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BioSampleBatch.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BioSampleBatch',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..pPM<BioSample>(1, _omitFieldNames ? '' : 'samples',
        subBuilder: BioSample.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BioSampleBatch clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BioSampleBatch copyWith(void Function(BioSampleBatch) updates) =>
      super.copyWith((message) => updates(message as BioSampleBatch))
          as BioSampleBatch;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BioSampleBatch create() => BioSampleBatch._();
  @$core.override
  BioSampleBatch createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BioSampleBatch getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BioSampleBatch>(create);
  static BioSampleBatch? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<BioSample> get samples => $_getList(0);
}

/// BioStreamAck is the server acknowledgement for a batch of received bio samples.
/// received_count is the cumulative number of samples accepted since this bidi
/// connection was opened.
/// dropped_count is the cumulative number of samples discarded (e.g. rate-limited)
/// since this bidi connection was opened. Cumulative semantics allow the client to
/// detect any drops that occurred between two consecutive acks without the server
/// having to send an ack for every batch.
/// max_samples_per_second is the server-side rate limit hint the client should
/// respect to avoid further drops.
/// timestamp is int64 Unix millis when the ack was produced.
/// Auth identity comes from metadata/interceptor, not the message.
class BioStreamAck extends $pb.GeneratedMessage {
  factory BioStreamAck({
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

  BioStreamAck._();

  factory BioStreamAck.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BioStreamAck.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BioStreamAck',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aInt64(2, _omitFieldNames ? '' : 'receivedCount')
    ..aInt64(3, _omitFieldNames ? '' : 'droppedCount')
    ..aI(4, _omitFieldNames ? '' : 'maxSamplesPerSecond')
    ..aInt64(5, _omitFieldNames ? '' : 'timestamp')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BioStreamAck clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BioStreamAck copyWith(void Function(BioStreamAck) updates) =>
      super.copyWith((message) => updates(message as BioStreamAck))
          as BioStreamAck;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BioStreamAck create() => BioStreamAck._();
  @$core.override
  BioStreamAck createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BioStreamAck getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BioStreamAck>(create);
  static BioStreamAck? _defaultInstance;

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

/// BioStreamReady is the server's first outbound frame, emitted the instant the
/// controller subscribes — before any client batch is read. Mirrors StreamReady
/// from module_instruction_stream.proto.
class BioStreamReady extends $pb.GeneratedMessage {
  factory BioStreamReady({
    $core.int? maxSamplesPerSecond,
    $fixnum.Int64? timestamp,
  }) {
    final result = create();
    if (maxSamplesPerSecond != null)
      result.maxSamplesPerSecond = maxSamplesPerSecond;
    if (timestamp != null) result.timestamp = timestamp;
    return result;
  }

  BioStreamReady._();

  factory BioStreamReady.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BioStreamReady.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BioStreamReady',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'maxSamplesPerSecond')
    ..aInt64(2, _omitFieldNames ? '' : 'timestamp')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BioStreamReady clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BioStreamReady copyWith(void Function(BioStreamReady) updates) =>
      super.copyWith((message) => updates(message as BioStreamReady))
          as BioStreamReady;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BioStreamReady create() => BioStreamReady._();
  @$core.override
  BioStreamReady createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BioStreamReady getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BioStreamReady>(create);
  static BioStreamReady? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get maxSamplesPerSecond => $_getIZ(0);
  @$pb.TagNumber(1)
  set maxSamplesPerSecond($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMaxSamplesPerSecond() => $_has(0);
  @$pb.TagNumber(1)
  void clearMaxSamplesPerSecond() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get timestamp => $_getI64(1);
  @$pb.TagNumber(2)
  set timestamp($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTimestamp() => $_has(1);
  @$pb.TagNumber(2)
  void clearTimestamp() => $_clearField(2);
}

enum BioStreamResponse_Event { ack, error, ready, notSet }

/// BioStreamResponse is the server-to-client stream envelope.
/// Each message carries exactly one event via the oneof.
/// StateErrorEvent is imported from module_state.proto and reused for error reporting.
class BioStreamResponse extends $pb.GeneratedMessage {
  factory BioStreamResponse({
    BioStreamAck? ack,
    $2.StateErrorEvent? error,
    BioStreamReady? ready,
  }) {
    final result = create();
    if (ack != null) result.ack = ack;
    if (error != null) result.error = error;
    if (ready != null) result.ready = ready;
    return result;
  }

  BioStreamResponse._();

  factory BioStreamResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BioStreamResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, BioStreamResponse_Event>
      _BioStreamResponse_EventByTag = {
    1: BioStreamResponse_Event.ack,
    2: BioStreamResponse_Event.error,
    3: BioStreamResponse_Event.ready,
    0: BioStreamResponse_Event.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BioStreamResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mind'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3])
    ..aOM<BioStreamAck>(1, _omitFieldNames ? '' : 'ack',
        subBuilder: BioStreamAck.create)
    ..aOM<$2.StateErrorEvent>(2, _omitFieldNames ? '' : 'error',
        subBuilder: $2.StateErrorEvent.create)
    ..aOM<BioStreamReady>(3, _omitFieldNames ? '' : 'ready',
        subBuilder: BioStreamReady.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BioStreamResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BioStreamResponse copyWith(void Function(BioStreamResponse) updates) =>
      super.copyWith((message) => updates(message as BioStreamResponse))
          as BioStreamResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BioStreamResponse create() => BioStreamResponse._();
  @$core.override
  BioStreamResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BioStreamResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BioStreamResponse>(create);
  static BioStreamResponse? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  BioStreamResponse_Event whichEvent() =>
      _BioStreamResponse_EventByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  void clearEvent() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  BioStreamAck get ack => $_getN(0);
  @$pb.TagNumber(1)
  set ack(BioStreamAck value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasAck() => $_has(0);
  @$pb.TagNumber(1)
  void clearAck() => $_clearField(1);
  @$pb.TagNumber(1)
  BioStreamAck ensureAck() => $_ensure(0);

  @$pb.TagNumber(2)
  $2.StateErrorEvent get error => $_getN(1);
  @$pb.TagNumber(2)
  set error($2.StateErrorEvent value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(2)
  void clearError() => $_clearField(2);
  @$pb.TagNumber(2)
  $2.StateErrorEvent ensureError() => $_ensure(1);

  @$pb.TagNumber(3)
  BioStreamReady get ready => $_getN(2);
  @$pb.TagNumber(3)
  set ready(BioStreamReady value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasReady() => $_has(2);
  @$pb.TagNumber(3)
  void clearReady() => $_clearField(3);
  @$pb.TagNumber(3)
  BioStreamReady ensureReady() => $_ensure(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
