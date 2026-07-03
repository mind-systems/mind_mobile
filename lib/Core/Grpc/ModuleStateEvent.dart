sealed class ModuleStateEvent {}

class ModuleSessionStarted extends ModuleStateEvent {
  final String? moduleSessionId;
  ModuleSessionStarted({this.moduleSessionId});
}

class ModuleSessionResumed extends ModuleStateEvent {
  final String? moduleSessionId;
  ModuleSessionResumed({this.moduleSessionId});
}

class ModuleSessionPaused extends ModuleStateEvent {}

class ModuleSessionUnpaused extends ModuleStateEvent {}

class ModuleSessionEnded extends ModuleStateEvent {}

class ModuleSessionAbandoned extends ModuleStateEvent {}

/// Whole-tree termination reasons. Extensible — new whole-tree cases append here.
enum SessionTerminationReason { movedToAnotherDevice, abandoned, rootDeath }

class SessionTerminated extends ModuleStateEvent {
  final SessionTerminationReason reason;
  SessionTerminated(this.reason);
}
