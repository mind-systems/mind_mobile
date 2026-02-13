import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionState.dart';

class BreathStepDTO {
  final BreathPhase phase;
  final int duration;

  const BreathStepDTO({required this.phase, required this.duration});
}
