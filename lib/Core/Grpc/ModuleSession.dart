import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Core/Grpc/ModuleState.dart';

/// Immutable value type for one entry tracked by `SessionRegistry`.
///
/// Pure Dart — no Flutter/Riverpod imports. Shared between the registry and
/// downstream consumers (RootStateChannel, addressing, bio routing).
class ModuleSession {
  final String id;
  final ActivityType activityType;
  final ModuleStateStatus status;
  final bool isPaused;

  const ModuleSession({
    required this.id,
    required this.activityType,
    required this.status,
    this.isPaused = false,
  });

  ModuleSession copyWith({
    String? id,
    ActivityType? activityType,
    ModuleStateStatus? status,
    bool? isPaused,
  }) {
    return ModuleSession(
      id: id ?? this.id,
      activityType: activityType ?? this.activityType,
      status: status ?? this.status,
      isPaused: isPaused ?? this.isPaused,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModuleSession &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          activityType == other.activityType &&
          status == other.status &&
          isPaused == other.isPaused;

  @override
  int get hashCode => Object.hash(id, activityType, status, isPaused);
}
