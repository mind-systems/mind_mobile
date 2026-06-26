import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ITickService.dart';
import '../CommonModels/TickSource.dart';
import 'BreathSessionStateMachine.dart';
import 'IBreathSessionCoordinator.dart';
import 'IBreathSessionService.dart';
import 'Models/BreathSessionDTO.dart';
import 'Models/BreathSessionState.dart';
import 'Models/TimelineStep.dart';

enum BreathSessionUiEvent { starFailed, noCardioSource }

final breathViewModelProvider =
    NotifierProvider<BreathViewModel, BreathSessionState>(() {
  throw UnimplementedError(
    'BreathViewModel must be overridden via ProviderScope',
  );
});

class BreathViewModel extends Notifier<BreathSessionState> {
  final ITickService tickService;
  final IBreathSessionService service;
  final IBreathSessionCoordinator coordinator;
  final String sessionId;

  BreathSessionStateMachine? _stateMachine;
  StreamSubscription<BreathSessionStateMachineState>? _stateMachineSubscription;
  StreamSubscription<BreathSessionDTO>? _sessionUpdateSubscription;
  StreamSubscription<void>? _sessionDeletionSubscription;
  StreamSubscription<TickSource>? _sourceChangesSub;

  void Function(BreathSessionUiEvent event)? onUiEvent;

  void Function()? _onModuleDispose;
  void Function()? _onModuleReset;
  void Function(bool isLive)? _onIsLiveChanged;

  bool _lastIsLive = false;

  void attachModuleChannel({
    required void Function() onDispose,
    required void Function() onReset,
    void Function(bool isLive)? onIsLiveChanged,
  }) {
    _onModuleDispose = onDispose;
    _onModuleReset = onReset;
    _onIsLiveChanged = onIsLiveChanged;
  }

  BreathSessionDTO? _sessionDTO;

  final ValueNotifier<int> _remainingTicks = ValueNotifier<int>(0);

  /// Per-tick countdown channel for narrow-scope UI consumers (e.g. the active
  /// timeline row). Sibling to `BreathSessionState.remainingTicks` — both stay
  /// in sync but this notifier lets a single widget subscribe without
  /// triggering screen-wide rebuilds.
  ValueListenable<int> get remainingTicksNotifier => _remainingTicks;

  final _stateController = StreamController<BreathSessionState>.broadcast();

  /// Stream of state updates — consumed by BreathModuleStateChannel.
  Stream<BreathSessionState> get stream => _stateController.stream;

  /// Subscribe to state changes. Returns a cancel function (drop-in for the
  /// old StateNotifier.addListener API used by animation coordinators).
  void Function() listen(void Function(BreathSessionState) onData) {
    final sub = _stateController.stream.listen(onData);
    return sub.cancel;
  }

  BreathViewModel({
    required this.tickService,
    required this.service,
    required this.coordinator,
    required this.sessionId,
  });

  @override
  BreathSessionState build() {
    ref.onDispose(() {
      if (_lastIsLive) {
        _onIsLiveChanged?.call(false);
      }
      _onModuleDispose?.call();
      _sessionDeletionSubscription?.cancel();
      _sessionUpdateSubscription?.cancel();
      _stateMachineSubscription?.cancel();
      _sourceChangesSub?.cancel();
      _stateMachine?.dispose();
      _stateController.close();
      _remainingTicks.dispose();
      tickService.dispose();
    });
    return BreathSessionState.initial();
  }

  /// Dual-channel publication.
  ///
  /// The raw [_stateController] stream fires on **every** call — animation
  /// coordinators (`BreathAnimationCoordinator`, `OrbAnimationCoordinator`),
  /// `BreathSoundCoordinator`, and `BreathModuleStateChannel` all subscribe via
  /// this stream and depend on per-tick cadence.
  ///
  /// `super.state = value` (Riverpod publication) is **skipped** when the
  /// incoming value differs from the current state only in tick-cadence fields
  /// (`remainingTicks`, `currentIntervalMs`) — this is what prevents the
  /// screen from rebuilding on every tick.
  ///
  /// Note: `set state` is only invoked after `build()` completes (via
  /// `_setupEngine`, `_onEngineState`, `toggleStar`, and the error branch in
  /// `initState`), so `super.state` is safe to read inside the setter.
  @override
  set state(BreathSessionState value) {
    if (!value.equalsIgnoringTickFields(super.state)) {
      super.state = value;
    }
    if (!_stateController.isClosed) {
      _stateController.add(value);
    }
    final next = value.isLive;
    if (_onIsLiveChanged != null && next != _lastIsLive) {
      _lastIsLive = next;
      _onIsLiveChanged!(next);
    }
  }

  // ===== Lifecycle =====

  Future<void> initState() async {
    try {
      final dto = await service.getSession(sessionId);
      _sessionDTO = dto;
      _setupEngine(dto);
      _sourceChangesSub = tickService.sourceChanges.listen((src) {
        state = state.copyWith(tickSource: src);
      });
      _sessionUpdateSubscription = service.observeSession(sessionId).listen((dto) {
        _sessionDTO = dto;
        _setupEngine(dto);
      });
      _sessionDeletionSubscription = service.observeSessionDeletion(sessionId).listen((_) {
        coordinator.dismiss();
      });
    } catch (e) {
      state = state.copyWith(loadState: SessionLoadState.error);
    }
  }

  void _setupEngine(BreathSessionDTO dto) {
    _stateMachineSubscription?.cancel();
    _stateMachine?.dispose();

    _stateMachine = BreathSessionStateMachine(session: dto, tickService: tickService);

    _stateMachineSubscription = _stateMachine!.stateStream.listen(_onEngineState);

    final timelineSteps = _buildTimelineSteps(dto);

    final initialEngineState = _stateMachine!.currentState;
    _remainingTicks.value = initialEngineState.remainingTicks;
    // Full constructor — copyWith cannot clear nullable fields on restart
    state = BreathSessionState(
      loadState: SessionLoadState.ready,
      timelineSteps: timelineSteps,
      phase: initialEngineState.phase,
      exerciseIndex: initialEngineState.exerciseIndex,
      remainingTicks: initialEngineState.remainingTicks,
      activeStepId: initialEngineState.activeStepId,
      currentIntervalMs: initialEngineState.currentIntervalMs,
      isStarred: dto.isStarred,
      canStar: dto.canStar,
      resetReason: initialEngineState.resetReason,
      totalPhases: initialEngineState.totalPhases,
      currentPhaseIndex: initialEngineState.currentPhaseIndex,
      currentPhaseTotalDuration: initialEngineState.currentPhaseTotalDuration,
      currentExerciseShape: initialEngineState.currentExerciseShape,
      nextExerciseShape: initialEngineState.nextExerciseShape,
      tickSource: tickService.source,
      lifecycle: initialEngineState.lifecycle,
    );
  }

  void _onEngineState(BreathSessionStateMachineState engineState) {
    // Tick-cadence side channel. The active timeline row subscribes to this
    // notifier directly so only that one `Text` rebuilds each tick, instead of
    // pushing the new countdown through `state` and rebuilding the whole
    // screen. `BreathSessionState.remainingTicks` is updated in lockstep
    // below for raw-stream consumers (animation coordinators).
    _remainingTicks.value = engineState.remainingTicks;
    // Full constructor — copyWith cannot clear nullable fields (resetReason,
    // currentExerciseShape, nextExerciseShape) when the engine emits null.
    //
    // `timelineSteps` is carried by reference (`state.timelineSteps`), never
    // rebuilt per tick. Identity preservation is load-bearing for the
    // `identical(...)` check in `BreathSessionState.equalsIgnoringTickFields`,
    // which lets `set state` skip Riverpod publication on tick-only updates.
    // The active-row countdown lives on `_remainingTicks` (above), not on a
    // mutated `step.duration`.
    state = BreathSessionState(
      loadState: state.loadState,
      phase: engineState.phase,
      exerciseIndex: engineState.exerciseIndex,
      remainingTicks: engineState.remainingTicks,
      activeStepId: engineState.activeStepId,
      currentIntervalMs: engineState.currentIntervalMs,
      timelineSteps: state.timelineSteps,
      isStarred: state.isStarred,
      canStar: state.canStar,
      resetReason: engineState.resetReason,
      totalPhases: engineState.totalPhases,
      currentPhaseIndex: engineState.currentPhaseIndex,
      currentPhaseTotalDuration: engineState.currentPhaseTotalDuration,
      currentExerciseShape: engineState.currentExerciseShape,
      nextExerciseShape: engineState.nextExerciseShape,
      tickSource: state.tickSource,
      lifecycle: engineState.lifecycle,
    );
  }

  // ===== Timeline =====

  List<TimelineStep> _buildTimelineSteps(BreathSessionDTO dto) {
    final steps = <TimelineStep>[];

    for (var exerciseIndex = 0; exerciseIndex < dto.exercises.length; exerciseIndex++) {
      final exercise = dto.exercises[exerciseIndex];

      if (exerciseIndex > 0) {
        steps.add(const TimelineStep.separator());
      }

      if (exercise.isRestOnly) {
        steps.add(TimelineStep.fromPhase(
          phase: BreathPhase.rest,
          duration: exercise.restDuration,
          id: TimelineStep.generateId(
            exerciseIndex: exerciseIndex,
            repeatCounter: 0,
            stepIndex: 0,
            phase: BreathPhase.rest,
          ),
        ));
        continue;
      }

      for (var repeatCounter = 0; repeatCounter < exercise.repeatCount; repeatCounter++) {
        for (var stepIndex = 0; stepIndex < exercise.steps.length; stepIndex++) {
          final step = exercise.steps[stepIndex];
          steps.add(TimelineStep.fromPhase(
            phase: step.phase,
            duration: step.duration,
            id: TimelineStep.generateId(
              exerciseIndex: exerciseIndex,
              repeatCounter: repeatCounter,
              stepIndex: stepIndex,
              phase: step.phase,
            ),
          ));
        }

        final isLastRepeat = repeatCounter == exercise.repeatCount - 1;
        if (!isLastRepeat && exercise.restDuration > 0) {
          steps.add(TimelineStep.fromPhase(
            phase: BreathPhase.rest,
            duration: exercise.restDuration,
            id: TimelineStep.generateId(
              exerciseIndex: exerciseIndex,
              repeatCounter: repeatCounter + 1,
              stepIndex: 0,
              phase: BreathPhase.rest,
            ),
          ));
        }
      }
    }

    return steps;
  }

  // ===== Public controls =====

  BreathSessionState get currentState => state;

  Stream<void> get tickStream => tickService.tickStream.cast();

  void pause() => _stateMachine?.pause();

  void resume() => _stateMachine?.resume();

  void complete() => _stateMachine?.complete();

  void restartEngine() {
    if (_sessionDTO == null) return;
    _onModuleReset?.call();
    _setupEngine(_sessionDTO!);
  }

  void openEditor() {
    if (_sessionDTO == null) return;
    pause();
    coordinator.openConstructor(sessionId);
  }

  void shareSession() => coordinator.shareSession(sessionId);

  void toggleHeartTickSource() {
    final target = state.tickSource == TickSource.heartbeat
        ? TickSource.timer
        : TickSource.heartbeat;
    final ok = tickService.trySwitchTo(target);
    if (!ok) {
      onUiEvent?.call(BreathSessionUiEvent.noCardioSource);
    }
    // state.tickSource is updated by the _sourceChangesSub subscriber, not here —
    // single sync point for both manual toggle and auto-fallback.
  }

  Future<void> toggleStar() async {
    final newStarred = !state.isStarred;
    state = state.copyWith(isStarred: newStarred);
    try {
      final dto = await service.starSession(sessionId, starred: newStarred);
      _sessionDTO = dto;
      state = state.copyWith(isStarred: dto.isStarred);
    } catch (_) {
      state = state.copyWith(isStarred: !newStarred);
      onUiEvent?.call(BreathSessionUiEvent.starFailed);
    }
  }
}
