import 'package:mind/BreathModule/Models/ExerciseSet.dart';

enum TickSource { heartbeat, timer }

class BreathSession {
  final String id;
  final String userId;
  final String description;
  final bool shared;

  final List<ExerciseSet> exercises;
  final TickSource tickSource;

  BreathSession({
    required this.id,
    required this.userId,
    required this.description,
    required this.shared,
    required this.exercises,
    required this.tickSource,
  });

  BreathSession copyWith({
    String? id,
    String? userId,
    String? description,
    bool? shared,
    List<ExerciseSet>? exercises,
    TickSource? tickSource,
  }) {
    return BreathSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      description: description ?? this.description,
      shared: shared ?? this.shared,
      exercises: exercises ?? this.exercises,
      tickSource: tickSource ?? this.tickSource,
    );
  }
}
