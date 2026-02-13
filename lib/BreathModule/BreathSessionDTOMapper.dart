import 'package:mind/BreathModule/Models/StepType.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Models/ExerciseStep.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionState.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathExerciseDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathStepDTO.dart';

class BreathSessionDTOMapper {
  static BreathSessionDTO map(BreathSession session) {
    return BreathSessionDTO(
      id: session.id,
      description: session.description,
      exercises: session.exercises.map(_mapExercise).toList(),
    );
  }

  static BreathExerciseDTO _mapExercise(ExerciseSet exercise) {
    return BreathExerciseDTO(
      steps: exercise.steps.map(_mapStep).toList(),
      restDuration: exercise.restDuration,
      repeatCount: exercise.repeatCount,
      shape: exercise.shape,
    );
  }

  static BreathStepDTO _mapStep(ExerciseStep step) {
    return BreathStepDTO(
      phase: _mapStepType(step.type),
      duration: step.duration,
    );
  }

  static BreathPhase _mapStepType(StepType type) {
    switch (type) {
      case StepType.inhale: return BreathPhase.inhale;
      case StepType.hold: return BreathPhase.hold;
      case StepType.exhale: return BreathPhase.exhale;
    }
  }
}
