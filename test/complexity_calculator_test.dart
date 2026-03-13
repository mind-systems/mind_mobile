import 'package:flutter_test/flutter_test.dart';
import 'package:mind/BreathModule/Core/ComplexityCalculator.dart';

void main() {
  group('calculateComplexity', () {
    test('empty exercises returns 0', () {
      expect(calculateComplexity([]), 0.0);
    });

    test('single exercise no rest returns cycleDuration * repeatCount', () {
      final ex = ExerciseComplexityInput(
        cycleDuration: 8,
        restDuration: 0,
        repeatCount: 5,
      );
      // contribution = 8 * 5 = 40, penalty = 0
      expect(calculateComplexity([ex]), 40.0);
    });

    test('rest separator at index 0 has no penalty', () {
      final restSep = ExerciseComplexityInput(
        cycleDuration: 0,
        restDuration: 30,
        repeatCount: 0,
      );
      // i == 0, so no penalty; contribution = 0
      expect(calculateComplexity([restSep]), 0.0);
    });

    test('rest separator between exercises applies penalty = restDuration * 3', () {
      final ex1 = ExerciseComplexityInput(
        cycleDuration: 8,
        restDuration: 0,
        repeatCount: 10,
      );
      final restSep = ExerciseComplexityInput(
        cycleDuration: 0,
        restDuration: 30,
        repeatCount: 0,
      );
      final ex2 = ExerciseComplexityInput(
        cycleDuration: 8,
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
      final ex = ExerciseComplexityInput(
        cycleDuration: 16,
        restDuration: 2,
        repeatCount: 10,
      );
      // contribution = 16*10 = 160
      // penalty = 2 * 10 * 5 = 100
      // result = 60
      expect(calculateComplexity([ex]), 60.0);
    });

    test('high-intensity with set rest where contribution dominates', () {
      final ex = ExerciseComplexityInput(
        cycleDuration: 16,
        restDuration: 1,
        repeatCount: 20,
      );
      // contribution = 16*20 = 320
      // penalty = 1 * 20 * 5 = 100
      // result = 220
      expect(calculateComplexity([ex]), 220.0);
    });

    test('penalty exceeds contribution and is clamped to 0', () {
      final ex = ExerciseComplexityInput(
        cycleDuration: 4,
        restDuration: 10,
        repeatCount: 3,
      );
      // contribution = 4*3 = 12
      // penalty = 10 * 3 * 5 = 150
      // 12 - 150 = -138 → clamped to 0
      expect(calculateComplexity([ex]), 0.0);
    });

    test('mixed: opening rest + inter-exercise rest + set rest', () {
      final openingRest = ExerciseComplexityInput(
        cycleDuration: 0,
        restDuration: 30,
        repeatCount: 0,
      );
      final ex1 = ExerciseComplexityInput(
        cycleDuration: 16,
        restDuration: 0,
        repeatCount: 10,
      );
      final midRest = ExerciseComplexityInput(
        cycleDuration: 0,
        restDuration: 20,
        repeatCount: 0,
      );
      final ex2 = ExerciseComplexityInput(
        cycleDuration: 6,
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
