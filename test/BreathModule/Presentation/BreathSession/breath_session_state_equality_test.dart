import 'package:flutter_test/flutter_test.dart';
import 'package:breath_module/breath_module.dart'
    show
        BreathSessionState,
        BreathLifecycle,
        BreathPhase,
        ResetReason,
        SessionLoadState,
        SetShape,
        TickSource,
        TimelineStep;

// ---------------------------------------------------------------------------
// Shared timeline list
//
// All scalar-comparison tests must share the SAME list reference.
// equalsIgnoringTickFields uses identical(...) for timelineSteps, so two
// states with different list objects would always compare unequal — hiding
// whether any scalar field was actually responsible.
// ---------------------------------------------------------------------------

final _sharedTimeline = <TimelineStep>[
  TimelineStep.fromPhase(phase: BreathPhase.inhale, duration: 2, id: 'step-0'),
];

/// Builds a fully-populated [BreathSessionState] with every field set to a
/// non-default value so that flipping any single field is observable.
BreathSessionState _state({List<TimelineStep>? timelineSteps}) {
  return BreathSessionState(
    loadState: SessionLoadState.ready,
    lifecycle: BreathLifecycle.running,
    phase: BreathPhase.exhale,
    exerciseIndex: 3,
    remainingTicks: 9,
    currentIntervalMs: 1000,
    timelineSteps: timelineSteps ?? _sharedTimeline,
    activeStepId: 'step-x',
    isStarred: true,
    canStar: true,
    resetReason: ResetReason.newCycle,
    totalPhases: 5,
    currentPhaseIndex: 2,
    currentPhaseTotalDuration: 7,
    currentExerciseShape: SetShape.circle,
    nextExerciseShape: SetShape.square,
    tickSource: TickSource.heartbeat,
  );
}

void main() {
  // =========================================================================
  // Task 1 — Excluded fields are ignored (equalsIgnoringTickFields → true)
  // =========================================================================

  group('equalsIgnoringTickFields — excluded fields are ignored', () {
    test('should return true when only remainingTicks differs', () {
      final a = _state();
      final b = a.copyWith(remainingTicks: 1);
      expect(a.equalsIgnoringTickFields(b), isTrue);
    });

    test('should return true when only currentIntervalMs differs', () {
      final a = _state();
      final b = a.copyWith(currentIntervalMs: 500);
      expect(a.equalsIgnoringTickFields(b), isTrue);
    });

    test('should return true when only resetReason differs', () {
      // copyWith cannot clear resetReason to null (uses ??) and cannot vary
      // it freely — build the variant via the full constructor instead.
      final a = _state();
      final b = BreathSessionState(
        loadState: a.loadState,
        lifecycle: a.lifecycle,
        phase: a.phase,
        exerciseIndex: a.exerciseIndex,
        remainingTicks: a.remainingTicks,
        currentIntervalMs: a.currentIntervalMs,
        timelineSteps: _sharedTimeline,
        activeStepId: a.activeStepId,
        isStarred: a.isStarred,
        canStar: a.canStar,
        resetReason: ResetReason.rest, // differs from newCycle
        totalPhases: a.totalPhases,
        currentPhaseIndex: a.currentPhaseIndex,
        currentPhaseTotalDuration: a.currentPhaseTotalDuration,
        currentExerciseShape: a.currentExerciseShape,
        nextExerciseShape: a.nextExerciseShape,
        tickSource: a.tickSource,
      );
      expect(a.equalsIgnoringTickFields(b), isTrue);
    });

    test(
        'should return true when remainingTicks, currentIntervalMs and resetReason all differ together',
        () {
      final a = _state();
      final b = BreathSessionState(
        loadState: a.loadState,
        lifecycle: a.lifecycle,
        phase: a.phase,
        exerciseIndex: a.exerciseIndex,
        remainingTicks: 1,
        currentIntervalMs: 500,
        timelineSteps: _sharedTimeline,
        activeStepId: a.activeStepId,
        isStarred: a.isStarred,
        canStar: a.canStar,
        resetReason: ResetReason.exerciseChange,
        totalPhases: a.totalPhases,
        currentPhaseIndex: a.currentPhaseIndex,
        currentPhaseTotalDuration: a.currentPhaseTotalDuration,
        currentExerciseShape: a.currentExerciseShape,
        nextExerciseShape: a.nextExerciseShape,
        tickSource: a.tickSource,
      );
      expect(a.equalsIgnoringTickFields(b), isTrue);
    });

    test(
        'should return true when comparing a state to an otherwise-identical copy',
        () {
      final a = _state();
      final b = a.copyWith(); // same scalars, same timelineSteps reference
      expect(a.equalsIgnoringTickFields(b), isTrue);
    });
  });

  // =========================================================================
  // Task 2 — Included scalar fields are structural (equalsIgnoringTickFields → false)
  // =========================================================================

  group('equalsIgnoringTickFields — included scalar fields are structural', () {
    test('should return false when only loadState differs', () {
      final a = _state();
      final b = a.copyWith(loadState: SessionLoadState.loading);
      expect(a.equalsIgnoringTickFields(b), isFalse);
    });

    test('should return false when only lifecycle differs', () {
      final a = _state();
      final b = a.copyWith(lifecycle: BreathLifecycle.paused);
      expect(a.equalsIgnoringTickFields(b), isFalse);
    });

    test('should return false when only phase differs', () {
      final a = _state();
      final b = a.copyWith(phase: BreathPhase.inhale);
      expect(a.equalsIgnoringTickFields(b), isFalse);
    });

    test('should return false when only exerciseIndex differs', () {
      final a = _state();
      final b = a.copyWith(exerciseIndex: 0);
      expect(a.equalsIgnoringTickFields(b), isFalse);
    });

    test('should return false when only activeStepId differs', () {
      final a = _state();
      final b = a.copyWith(activeStepId: 'step-y');
      expect(a.equalsIgnoringTickFields(b), isFalse);
    });

    test('should return false when only isStarred differs', () {
      final a = _state();
      final b = a.copyWith(isStarred: false);
      expect(a.equalsIgnoringTickFields(b), isFalse);
    });

    test('should return false when only canStar differs', () {
      final a = _state();
      final b = a.copyWith(canStar: false);
      expect(a.equalsIgnoringTickFields(b), isFalse);
    });

    test('should return false when only totalPhases differs', () {
      final a = _state();
      final b = a.copyWith(totalPhases: 3);
      expect(a.equalsIgnoringTickFields(b), isFalse);
    });

    test('should return false when only currentPhaseIndex differs', () {
      final a = _state();
      final b = a.copyWith(currentPhaseIndex: 0);
      expect(a.equalsIgnoringTickFields(b), isFalse);
    });

    test('should return false when only currentPhaseTotalDuration differs', () {
      final a = _state();
      final b = a.copyWith(currentPhaseTotalDuration: 3);
      expect(a.equalsIgnoringTickFields(b), isFalse);
    });

    test('should return false when only currentExerciseShape differs', () {
      final a = _state();
      final b = a.copyWith(currentExerciseShape: SetShape.square);
      expect(a.equalsIgnoringTickFields(b), isFalse);
    });

    test('should return false when only nextExerciseShape differs', () {
      final a = _state();
      final b = a.copyWith(nextExerciseShape: SetShape.circle);
      expect(a.equalsIgnoringTickFields(b), isFalse);
    });

    test('should return false when only tickSource differs', () {
      final a = _state();
      final b = a.copyWith(tickSource: TickSource.timer);
      expect(a.equalsIgnoringTickFields(b), isFalse);
    });
  });

  // =========================================================================
  // Task 3 — timelineSteps identity semantics
  // =========================================================================

  group('equalsIgnoringTickFields — timelineSteps identity semantics', () {
    test('should return true when timelineSteps is the same list reference',
        () {
      // Both _state() calls default to _sharedTimeline — same reference.
      final a = _state();
      final b = _state();
      expect(a.equalsIgnoringTickFields(b), isTrue);
    });

    test(
        'should return false when timelineSteps are two separate lists with identical content',
        () {
      // Same element instance, but two distinct list objects.
      // identical(listA, listB) must be false → equalsIgnoringTickFields false.
      final step = TimelineStep.fromPhase(
        phase: BreathPhase.inhale,
        duration: 2,
        id: 'step-0',
      );
      final listA = <TimelineStep>[step];
      final listB = <TimelineStep>[step];
      final a = _state(timelineSteps: listA);
      final b = _state(timelineSteps: listB);
      expect(identical(listA, listB), isFalse); // precondition
      expect(a.equalsIgnoringTickFields(b), isFalse);
    });
  });
}
