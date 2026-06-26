import '../../CommonModels/SetShape.dart';
import '../../CommonModels/TickSource.dart';
import 'TimelineStep.dart';

enum BreathSessionStatus { pause, breath, rest, complete }
enum BreathPhase { inhale, hold, exhale, rest }
enum ResetReason { start, newCycle, rest, exerciseChange }
enum SessionLoadState { loading, ready, error }

/// Coarse lifecycle signal owned by [BreathLifecycleMachine] and stamped onto
/// each emission by the engine.
///
/// - [notStarted] — session created, never resumed.
/// - [running] — actively breathing.
/// - [paused] — manually paused after at least one resume.
/// - [completed] — session finished.
///
/// `isLive` is true for [running] and [paused] — the keep-alive window holds
/// through a manual pause so biometric/tracking channels stay open.
enum BreathLifecycle { notStarted, running, paused, completed }

class BreathSessionState {
  final SessionLoadState loadState;
  final BreathSessionStatus status;
  final BreathPhase phase;

  /// Индекс текущего упражнения в сессии
  final int exerciseIndex;

  /// Сколько тиков осталось до конца текущего шага
  final int remainingTicks;

  /// Интервал от предыдущего тика до текущего в миллисекундах
  final int currentIntervalMs;

  /// Список шагов в текущем упражнении
  final List<TimelineStep> timelineSteps;
  final String? activeStepId;

  final bool isStarred;
  final bool canStar;

  // Enriched fields (Phase 1)
  final ResetReason? resetReason;
  final int totalPhases;
  final int currentPhaseIndex;
  final int currentPhaseTotalDuration;
  final SetShape? currentExerciseShape;
  final SetShape? nextExerciseShape;
  final TickSource tickSource;

  // Lifecycle signal (Phase 2 — sourced from BreathLifecycleMachine at emit time)
  final BreathLifecycle lifecycle;

  /// `true` while the session is actively running or manually paused.
  /// `false` for [BreathLifecycle.notStarted] and [BreathLifecycle.completed].
  bool get isLive =>
      lifecycle == BreathLifecycle.running ||
      lifecycle == BreathLifecycle.paused;

  const BreathSessionState({
    required this.loadState,
    required this.status,
    required this.phase,
    required this.exerciseIndex,
    required this.remainingTicks,
    required this.currentIntervalMs,
    this.timelineSteps = const [],
    this.activeStepId,
    this.isStarred = false,
    this.canStar = false,
    this.resetReason,
    this.totalPhases = 0,
    this.currentPhaseIndex = 0,
    this.currentPhaseTotalDuration = 0,
    this.currentExerciseShape,
    this.nextExerciseShape,
    this.tickSource = TickSource.timer,
    this.lifecycle = BreathLifecycle.notStarted,
  });

  factory BreathSessionState.initial() => const BreathSessionState(
    loadState: SessionLoadState.loading,
    status: BreathSessionStatus.pause,
    phase: BreathPhase.inhale,
    exerciseIndex: 0,
    remainingTicks: 0,
    currentIntervalMs: -1,
    timelineSteps: [],
    activeStepId: null,
  );

  /// Returns `true` iff every field **except** the three transient fields
  /// (`remainingTicks`, `currentIntervalMs`, `resetReason`) is equal to [other].
  ///
  /// Excluded fields and why:
  /// - `remainingTicks` — advances once per second; read only by raw-stream
  ///   consumers and the `remainingTicksNotifier` channel, never via Riverpod.
  /// - `currentIntervalMs` — refreshed with the measured wall-clock delta on
  ///   every tick; varies by milliseconds (timer source) or tens-to-hundreds of
  ///   ms (heart-rate source), making it a cadence-only field. Only
  ///   `BreathAnimationCoordinator` and `BreathSoundCoordinator` read it, both
  ///   via the raw stream — no Riverpod consumer of `currentIntervalMs` exists.
  /// - `resetReason` — consumed only by raw-stream animation coordinators
  ///   (`BreathAnimationCoordinator`, `OrbAnimationCoordinator`) via
  ///   `viewModel.listen(...)`, never via Riverpod. A clear-emit
  ///   (`newCycle → null`) must not classify as a structural change.
  ///
  /// `timelineSteps` uses `identical(...)` rather than `listEquals`: the list
  /// is built once in `BreathViewModel._setupEngine` and carried forward by
  /// reference in `_onEngineState`, so reference equality is sufficient to
  /// detect structural change. A `listEquals` refactor would silently break
  /// the optimization by comparing elements on every tick — and any future
  /// change that rebuilds `timelineSteps` into a new list with identical
  /// content would also defeat it. Keep the carry-by-reference invariant
  /// intact on the producer side.
  bool equalsIgnoringTickFields(BreathSessionState other) {
    return loadState == other.loadState &&
        status == other.status &&
        phase == other.phase &&
        exerciseIndex == other.exerciseIndex &&
        activeStepId == other.activeStepId &&
        isStarred == other.isStarred &&
        canStar == other.canStar &&
        totalPhases == other.totalPhases &&
        currentPhaseIndex == other.currentPhaseIndex &&
        currentPhaseTotalDuration == other.currentPhaseTotalDuration &&
        currentExerciseShape == other.currentExerciseShape &&
        nextExerciseShape == other.nextExerciseShape &&
        tickSource == other.tickSource &&
        lifecycle == other.lifecycle &&
        identical(timelineSteps, other.timelineSteps);
  }

  BreathSessionState copyWith({
    SessionLoadState? loadState,
    BreathSessionStatus? status,
    BreathPhase? phase,
    int? exerciseIndex,
    int? remainingTicks,
    int? currentIntervalMs,
    List<TimelineStep>? timelineSteps,
    String? activeStepId,
    bool? isStarred,
    bool? canStar,
    // Note: resetReason uses ?? so copyWith cannot clear it to null.
    // Use explicit field assignment when clearing is needed.
    ResetReason? resetReason,
    int? totalPhases,
    int? currentPhaseIndex,
    int? currentPhaseTotalDuration,
    SetShape? currentExerciseShape,
    SetShape? nextExerciseShape,
    TickSource? tickSource,
    BreathLifecycle? lifecycle,
  }) {
    return BreathSessionState(
      loadState: loadState ?? this.loadState,
      status: status ?? this.status,
      phase: phase ?? this.phase,
      exerciseIndex: exerciseIndex ?? this.exerciseIndex,
      remainingTicks: remainingTicks ?? this.remainingTicks,
      currentIntervalMs: currentIntervalMs ?? this.currentIntervalMs,
      timelineSteps: timelineSteps ?? this.timelineSteps,
      activeStepId: activeStepId ?? this.activeStepId,
      isStarred: isStarred ?? this.isStarred,
      canStar: canStar ?? this.canStar,
      resetReason: resetReason ?? this.resetReason,
      totalPhases: totalPhases ?? this.totalPhases,
      currentPhaseIndex: currentPhaseIndex ?? this.currentPhaseIndex,
      currentPhaseTotalDuration: currentPhaseTotalDuration ?? this.currentPhaseTotalDuration,
      currentExerciseShape: currentExerciseShape ?? this.currentExerciseShape,
      nextExerciseShape: nextExerciseShape ?? this.nextExerciseShape,
      tickSource: tickSource ?? this.tickSource,
      lifecycle: lifecycle ?? this.lifecycle,
    );
  }
}
