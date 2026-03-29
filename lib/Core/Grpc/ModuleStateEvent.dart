sealed class ModuleStateEvent {}

class ModuleSessionStarted extends ModuleStateEvent {
  final String? moduleSessionId;
  ModuleSessionStarted({this.moduleSessionId});
}

class ModuleSessionPaused extends ModuleStateEvent {}

class ModuleSessionUnpaused extends ModuleStateEvent {}

class ModuleSessionEnded extends ModuleStateEvent {}

class ModuleSessionAbandoned extends ModuleStateEvent {}
