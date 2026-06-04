// This is a generated file - do not edit.
//
// Generated from breath_sessions.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Maps to BreathStep interface in src/breath-sessions/entities/breath-session.entity.ts
class StepType extends $pb.ProtobufEnum {
  static const StepType INHALE = StepType._(0, _omitEnumNames ? '' : 'INHALE');
  static const StepType EXHALE = StepType._(1, _omitEnumNames ? '' : 'EXHALE');
  static const StepType HOLD = StepType._(2, _omitEnumNames ? '' : 'HOLD');

  static const $core.List<StepType> values = <StepType>[
    INHALE,
    EXHALE,
    HOLD,
  ];

  static final $core.List<StepType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static StepType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const StepType._(super.value, super.name);
}

/// Maps to TimeOfDay enum in src/breath-sessions/enums/time-of-day.enum.ts
class TimeOfDay extends $pb.ProtobufEnum {
  static const TimeOfDay MORNING =
      TimeOfDay._(0, _omitEnumNames ? '' : 'MORNING');
  static const TimeOfDay MIDDAY =
      TimeOfDay._(1, _omitEnumNames ? '' : 'MIDDAY');
  static const TimeOfDay EVENING =
      TimeOfDay._(2, _omitEnumNames ? '' : 'EVENING');

  static const $core.List<TimeOfDay> values = <TimeOfDay>[
    MORNING,
    MIDDAY,
    EVENING,
  ];

  static final $core.List<TimeOfDay?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static TimeOfDay? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TimeOfDay._(super.value, super.name);
}

/// Section grouping for ListSessions items. A session may legitimately appear
/// in more than one section (e.g. starred AND mine) — duplication is intentional
/// so the client can render each section independently.
class SessionSection extends $pb.ProtobufEnum {
  static const SessionSection STARRED =
      SessionSection._(0, _omitEnumNames ? '' : 'STARRED');
  static const SessionSection MINE =
      SessionSection._(1, _omitEnumNames ? '' : 'MINE');
  static const SessionSection SHARED =
      SessionSection._(2, _omitEnumNames ? '' : 'SHARED');

  static const $core.List<SessionSection> values = <SessionSection>[
    STARRED,
    MINE,
    SHARED,
  ];

  static final $core.List<SessionSection?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static SessionSection? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SessionSection._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
