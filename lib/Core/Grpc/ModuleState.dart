enum ModuleStateStatus { idle, active }

class ModuleState {
  final String? moduleSessionId;
  final ModuleStateStatus status;
  final bool isPaused;

  const ModuleState({required this.moduleSessionId, required this.status, this.isPaused = false});

  factory ModuleState.initial() =>
      const ModuleState(moduleSessionId: null, status: ModuleStateStatus.idle);
}
