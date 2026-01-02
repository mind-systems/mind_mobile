import 'package:mind/BreathModule/Models/ExerciseSet.dart';

enum TickSource { heartbeat, timer }

class BreathSession {
  final List<ExerciseSet> exercises;
  final TickSource tickSource;

  BreathSession({required this.exercises, required this.tickSource});
}
