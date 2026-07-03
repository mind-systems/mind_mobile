import 'package:mind/Core/Grpc/ActivityType.dart';

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

/// A start for [type] never confirmed (no ACTIVE/RESUMED frame) within the
/// bounded retry budget (note 19 §Pinned constants: 3 total attempts) — the
/// pending start is given up. No session was ever created for [type], so
/// neither the biometric pipeline nor keep-alive react to it.
class SessionStartFailed extends ModuleStateEvent {
  final ActivityType type;
  SessionStartFailed(this.type);
}
