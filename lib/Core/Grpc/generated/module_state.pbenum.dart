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

/// Maps to SessionStatus enum in src/realtime/enums/session-status.enum.ts.
/// ACTIVITY_STATUS_UNSPECIFIED = 0 is the sentinel — a silent default ACTIVE
/// could mask bugs where status was never set.
class ActivityStatus extends $pb.ProtobufEnum {
  static const ActivityStatus ACTIVITY_STATUS_UNSPECIFIED =
      ActivityStatus._(0, _omitEnumNames ? '' : 'ACTIVITY_STATUS_UNSPECIFIED');
  static const ActivityStatus ACTIVE =
      ActivityStatus._(1, _omitEnumNames ? '' : 'ACTIVE');
  static const ActivityStatus DISCONNECTED =
      ActivityStatus._(2, _omitEnumNames ? '' : 'DISCONNECTED');
  static const ActivityStatus COMPLETED =
      ActivityStatus._(3, _omitEnumNames ? '' : 'COMPLETED');
  static const ActivityStatus ABANDONED =
      ActivityStatus._(4, _omitEnumNames ? '' : 'ABANDONED');
  static const ActivityStatus INTERRUPTED =
      ActivityStatus._(5, _omitEnumNames ? '' : 'INTERRUPTED');
  static const ActivityStatus RESUMED =
      ActivityStatus._(6, _omitEnumNames ? '' : 'RESUMED');

  static const $core.List<ActivityStatus> values = <ActivityStatus>[
    ACTIVITY_STATUS_UNSPECIFIED,
    ACTIVE,
    DISCONNECTED,
    COMPLETED,
    ABANDONED,
    INTERRUPTED,
    RESUMED,
  ];

  static final $core.List<ActivityStatus?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static ActivityStatus? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ActivityStatus._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
