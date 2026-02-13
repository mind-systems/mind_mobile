import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Models/ExerciseStep.dart';
import 'package:mind/BreathModule/Models/StepType.dart';

class BreathSession {
  final String id;
  final String userId;
  final String description;
  final bool shared;

  final List<ExerciseSet> exercises;

  BreathSession({
    required this.id,
    required this.userId,
    required this.description,
    required this.shared,
    required this.exercises,
  });

  BreathSession copyWith({
    String? id,
    String? userId,
    String? description,
    bool? shared,
    List<ExerciseSet>? exercises,
  }) {
    return BreathSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      description: description ?? this.description,
      shared: shared ?? this.shared,
      exercises: exercises ?? this.exercises,
    );
  }

  factory BreathSession.defaultSession() {
    final now = DateTime.now();
    final defaultName = 'Session ${now.day}.${now.month}.${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    final rest = ExerciseSet(steps: [], restDuration: 30, repeatCount: 0);
    final squareBreathing = ExerciseSet(steps: [ExerciseStep(type: StepType.inhale, duration: 4), ExerciseStep(type: StepType.hold, duration: 4), ExerciseStep(type: StepType.exhale, duration: 4), ExerciseStep(type: StepType.hold, duration: 4)], restDuration: 0, repeatCount: 10);
    return BreathSession(
      id: '',
      userId: '',
      description: defaultName,
      shared: false,
      exercises: [rest, squareBreathing],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'description': description,
      'shared': shared,
      'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
    };
  }

  factory BreathSession.fromJson(Map<String, dynamic> json) {
    return BreathSession(
      id: json['id'] as String,
      userId: json['userId'] as String,
      description: json['description'] as String,
      shared: json['shared'] as bool,
      exercises: (json['exercises'] as List).map((exercise) => ExerciseSet.fromJson(exercise as Map<String, dynamic>)).toList(),
    );
  }
}
