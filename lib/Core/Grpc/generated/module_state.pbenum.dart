// This is a generated file - do not edit.
//
// Generated from module_state.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Maps to ActivityType enum in src/realtime/enums/activity-type.enum.ts.
/// ACTIVITY_TYPE_UNSPECIFIED = 0 is the sentinel to prevent uninitialized fields
/// from silently matching a real value.
/// Only one real member for now; the enum is the extension point for future activity types.
class ActivityType extends $pb.ProtobufEnum {
  static const ActivityType ACTIVITY_TYPE_UNSPECIFIED =
      ActivityType._(0, _omitEnumNames ? '' : 'ACTIVITY_TYPE_UNSPECIFIED');
  static const ActivityType BREATH =
      ActivityType._(1, _omitEnumNames ? '' : 'BREATH');

  static const $core.List<ActivityType> values = <ActivityType>[
    ACTIVITY_TYPE_UNSPECIFIED,
    BREATH,
  ];

  static final $core.List<ActivityType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static ActivityType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ActivityType._(super.value, super.name);
}

/// Maps to PresenceState interface in src/realtime/interfaces/presence-state.interface.ts.
/// The existing code uses 'online' | 'background' strings; proto uses the canonical
/// FOREGROUND/BACKGROUND names from the roadmap.
class PresenceState extends $pb.ProtobufEnum {
  static const PresenceState PRESENCE_STATE_UNSPECIFIED =
      PresenceState._(0, _omitEnumNames ? '' : 'PRESENCE_STATE_UNSPECIFIED');
  static const PresenceState FOREGROUND =
      PresenceState._(1, _omitEnumNames ? '' : 'FOREGROUND');
  static const PresenceState BACKGROUND =
      PresenceState._(2, _omitEnumNames ? '' : 'BACKGROUND');

  static const $core.List<PresenceState> values = <PresenceState>[
    PRESENCE_STATE_UNSPECIFIED,
    FOREGROUND,
    BACKGROUND,
  ];

  static final $core.List<PresenceState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static PresenceState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PresenceState._(super.value, super.name);
}

/// Maps to SessionStatus enum in src/realtime/enums/session-status.enum.ts.
/// SESSION_STATUS_UNSPECIFIED = 0 is the sentinel — a silent default ACTIVE
/// could mask bugs where status was never set.
class SessionStatus extends $pb.ProtobufEnum {
  static const SessionStatus SESSION_STATUS_UNSPECIFIED =
      SessionStatus._(0, _omitEnumNames ? '' : 'SESSION_STATUS_UNSPECIFIED');
  static const SessionStatus ACTIVE =
      SessionStatus._(1, _omitEnumNames ? '' : 'ACTIVE');
  static const SessionStatus DISCONNECTED =
      SessionStatus._(2, _omitEnumNames ? '' : 'DISCONNECTED');
  static const SessionStatus COMPLETED =
      SessionStatus._(3, _omitEnumNames ? '' : 'COMPLETED');
  static const SessionStatus ABANDONED =
      SessionStatus._(4, _omitEnumNames ? '' : 'ABANDONED');
  static const SessionStatus INTERRUPTED =
      SessionStatus._(5, _omitEnumNames ? '' : 'INTERRUPTED');
  static const SessionStatus RESUMED =
      SessionStatus._(6, _omitEnumNames ? '' : 'RESUMED');

  static const $core.List<SessionStatus> values = <SessionStatus>[
    SESSION_STATUS_UNSPECIFIED,
    ACTIVE,
    DISCONNECTED,
    COMPLETED,
    ABANDONED,
    INTERRUPTED,
    RESUMED,
  ];

  static final $core.List<SessionStatus?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static SessionStatus? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SessionStatus._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
