import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Models/ExerciseStep.dart';
import 'package:mind/BreathModule/Presentation/CommonModels/StepType.dart';
import 'package:mind/BreathModule/Presentation/CommonModels/TickSource.dart';

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
      tickSource: TickSource.timer,
    );
  }
}
