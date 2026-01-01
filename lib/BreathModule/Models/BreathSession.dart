import 'package:mind/BreathModule/Models/BreathExercise.dart';

enum TickSource {
  heartbeat,
  timer
}

class BreathSession {
  final List<BreathExercise> exercises;
  final TickSource tickSource;

  BreathSession({
    required this.exercises,
    required this.tickSource,
  });
}
