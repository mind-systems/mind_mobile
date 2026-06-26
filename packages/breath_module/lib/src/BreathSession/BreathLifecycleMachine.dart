import 'Models/BreathSessionState.dart';

/// Owned sub-machine for the coarse session lifecycle.
///
/// Legal transitions:
///   notStarted → running  (via [run])
///   running    → paused   (via [pause])
///   paused     → running  (via [run])
///   any        → completed (via [complete])
///
/// There is no `completed → notStarted` transition — a restart is handled
/// by discarding the engine and re-instantiating it (which creates a fresh
/// [BreathLifecycleMachine] at [BreathLifecycle.notStarted]).
class BreathLifecycleMachine {
  BreathLifecycle _current = BreathLifecycle.notStarted;

  /// The current lifecycle value.
  BreathLifecycle get current => _current;

  /// `true` while the session is actively running (tick gate).
  bool get isRunning => _current == BreathLifecycle.running;

  /// `true` when the session has never been resumed.
  /// Used by [BreathSessionStateMachine.resume] to emit [ResetReason.start]
  /// on the very first activation.
  bool get isNotStarted => _current == BreathLifecycle.notStarted;

  /// Transitions [notStarted] or [paused] → [running].
  /// No-op when already [completed] (guards against re-running a finished session).
  void run() {
    if (_current == BreathLifecycle.notStarted ||
        _current == BreathLifecycle.paused) {
      _current = BreathLifecycle.running;
    }
    // No-op for running (already running) and completed (session finished).
  }

  /// Transitions [running] → [paused].
  /// No-op from [notStarted], [paused], or [completed] — preserves the
  /// "pre-resume pause stays notStarted" behavior.
  void pause() {
    if (_current == BreathLifecycle.running) {
      _current = BreathLifecycle.paused;
    }
  }

  /// Transitions to [completed] from any state.
  void complete() {
    _current = BreathLifecycle.completed;
  }
}
