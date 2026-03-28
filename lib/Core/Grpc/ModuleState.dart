enum ModuleStateStatus { idle, active }

class ModuleState {
  final String? liveSessionId;
  final ModuleStateStatus status;
  final bool isPaused;

  const ModuleState({required this.liveSessionId, required this.status, this.isPaused = false});

  factory ModuleState.initial() =>
      const ModuleState(liveSessionId: null, status: ModuleStateStatus.idle);
}
