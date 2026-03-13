import 'package:flutter_test/flutter_test.dart';
import 'package:mind/BreathModule/Core/ComplexityCalculator.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Models/ExerciseStep.dart';
import 'package:mind/BreathModule/Models/StepType.dart';

void main() {
  group('calculateComplexity', () {
    test('empty exercises returns 0', () {
      expect(calculateComplexity([]), 0.0);
    });

    test('single exercise no rest returns cycleDuration * repeatCount', () {
      final ex = ExerciseSet(
        steps: [
          ExerciseStep(type: StepType.inhale, duration: 4),
          ExerciseStep(type: StepType.exhale, duration: 4),
        ],
        restDuration: 0,
        repeatCount: 5,
      );
      // contribution = (4+4) * 5 = 40, penalty = 0
      expect(calculateComplexity([ex]), 40.0);
    });

    test('rest separator at index 0 has no penalty', () {
      final restSep = ExerciseSet(steps: [], restDuration: 30, repeatCount: 0);
      // i == 0, so no penalty; contribution = 0
      expect(calculateComplexity([restSep]), 0.0);
    });

    test('rest separator between exercises applies penalty = restDuration * 3', () {
      final ex1 = ExerciseSet(
        steps: [
          ExerciseStep(type: StepType.inhale, duration: 4),
          ExerciseStep(type: StepType.exhale, duration: 4),
        ],
        restDuration: 0,
        repeatCount: 10,
      );
      final restSep = ExerciseSet(steps: [], restDuration: 30, repeatCount: 0);
      final ex2 = ExerciseSet(
        steps: [
          ExerciseStep(type: StepType.inhale, duration: 4),
          ExerciseStep(type: StepType.exhale, duration: 4),
        ],
        restDuration: 0,
        repeatCount: 10,
      );
      // ex1: contribution = 8*10 = 80
      // restSep: penalty = 30*3 = 90
      // ex2: contribution = 8*10 = 80
      // total: 160 - 90 = 70
      expect(calculateComplexity([ex1, restSep, ex2]), 70.0);
    });

    test('between-set rest applies penalty = restDuration * repeatCount * 5', () {
      final ex = ExerciseSet(
        steps: [
          ExerciseStep(type: StepType.inhale, duration: 4),
          ExerciseStep(type: StepType.hold, duration: 4),
          ExerciseStep(type: StepType.exhale, duration: 4),
          ExerciseStep(type: StepType.hold, duration: 4),
        ],
        restDuration: 2,
        repeatCount: 10,
      );
      // cycleDuration = 16, contribution = 16*10 = 160
      // penalty = 2 * 10 * 5 = 100
      // result = 60
      expect(calculateComplexity([ex]), 60.0);
    });

    test('high-intensity with set rest where contribution dominates', () {
      final ex = ExerciseSet(
        steps: [
          ExerciseStep(type: StepType.inhale, duration: 4),
          ExerciseStep(type: StepType.hold, duration: 4),
          ExerciseStep(type: StepType.exhale, duration: 4),
          ExerciseStep(type: StepType.hold, duration: 4),
        ],
        restDuration: 1,
        repeatCount: 20,
      );
      // cycleDuration = 16, contribution = 16*20 = 320
      // penalty = 1 * 20 * 5 = 100
      // result = 220
      expect(calculateComplexity([ex]), 220.0);
    });

    test('penalty exceeds contribution and is clamped to 0', () {
      final ex = ExerciseSet(
        steps: [
          ExerciseStep(type: StepType.inhale, duration: 2),
          ExerciseStep(type: StepType.exhale, duration: 2),
        ],
        restDuration: 10,
        repeatCount: 3,
      );
      // cycleDuration = 4, contribution = 4*3 = 12
      // penalty = 10 * 3 * 5 = 150
      // 12 - 150 = -138 → clamped to 0
      expect(calculateComplexity([ex]), 0.0);
    });

    test('mixed: opening rest + inter-exercise rest + set rest', () {
      final openingRest = ExerciseSet(steps: [], restDuration: 30, repeatCount: 0);
      final ex1 = ExerciseSet(
        steps: [
          ExerciseStep(type: StepType.inhale, duration: 4),
          ExerciseStep(type: StepType.hold, duration: 4),
          ExerciseStep(type: StepType.exhale, duration: 4),
          ExerciseStep(type: StepType.hold, duration: 4),
        ],
        restDuration: 0,
        repeatCount: 10,
      );
      final midRest = ExerciseSet(steps: [], restDuration: 20, repeatCount: 0);
      final ex2 = ExerciseSet(
        steps: [
          ExerciseStep(type: StepType.inhale, duration: 3),
          ExerciseStep(type: StepType.exhale, duration: 3),
        ],
        restDuration: 2,
        repeatCount: 5,
      );

      // openingRest: i==0, no penalty
      // ex1: contribution += 16*10 = 160, no set rest penalty
      // midRest: i>0, penalty += 20*3 = 60
      // ex2: contribution += 6*5 = 30, set rest penalty += 2*5*5 = 50
      // total contribution = 190, total penalty = 110
      // result = 80
      expect(calculateComplexity([openingRest, ex1, midRest, ex2]), 80.0);
    });
  });
}
