import 'package:rxdart/rxdart.dart';

import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Core/Grpc/ModuleSession.dart';

/// The routing layer that holds a `Map<String, ModuleSession>` keyed by
/// `module_session_id`, owned and driven by `ModuleStateChannel`.
///
/// Represents a root session plus N concurrent children, derived from the
/// live `ModuleSession` entries upserted/removed by the channel as
/// `StateEvent` frames arrive.
class SessionRegistry {
  final Map<String, ModuleSession> _sessions = {};

  final _changes = PublishSubject<void>();
  final _rootIdChanges = BehaviorSubject<String?>.seeded(null);

  bool _isDisposed = false;

  /// Upserts [session] by `id` — updates in place if an entry with the same
  /// `id` already exists, otherwise inserts a new entry.
  void upsert(ModuleSession session) {
    if (_isDisposed) return;
    _sessions[session.id] = session;
    _notify();
  }

  /// Unconditionally removes the entry with the given `id`, if present.
  ///
  /// The terminal-status decision (proto `COMPLETED`/`INTERRUPTED`/
  /// `ABANDONED`) lives in the caller (`ModuleStateChannel`, note 14) —
  /// this method does not branch on `ModuleSession.status`, which is only
  /// `{idle, active}` and cannot represent terminal states.
  void removeTerminal(String id) {
    if (_isDisposed) return;
    _sessions.remove(id);
    _notify();
  }

  /// Empties the registry and fires the change/rootId notifications.
  ///
  /// Used to reset the whole registry on logout / no-active-session, which
  /// per-id `removeTerminal` cannot do (the map is private and
  /// unenumerable from the caller). A no-op call (already empty) still
  /// notifies — `rootIdChanges` is a `.distinct()` stream, so a redundant
  /// `null` → `null` is absorbed there rather than special-cased here.
  void clear() {
    if (_isDisposed) return;
    _sessions.clear();
    _notify();
  }

  /// The `id` of the sole entry with `activityType == ActivityType.root`,
  /// or `null` if no root entry is present.
  ///
  /// Two roots is a server bug — return the first match (do not throw).
  String? get rootId => _rootIdChanges.value;

  /// The sole non-root entry of the given [type], or `null` if none exists.
  ///
  /// Never returns the root.
  ModuleSession? childOfType(ActivityType type) {
    if (type == ActivityType.root) return null;
    for (final session in _sessions.values) {
      if (session.activityType == type) return session;
    }
    return null;
  }

  /// Emits the current `rootId` whenever it changes, so adapters/bio can
  /// observe root session transitions. Late subscribers get the current
  /// `rootId`.
  Stream<String?> get rootIdChanges => _rootIdChanges.stream.distinct();

  /// Emits whenever the registry's contents change, so adapters/bio can
  /// observe any session transition.
  Stream<void> get changes => _changes.stream;

  String? _computeRootId() {
    for (final session in _sessions.values) {
      if (session.activityType == ActivityType.root) return session.id;
    }
    return null;
  }

  void _notify() {
    _rootIdChanges.add(_computeRootId());
    _changes.add(null);
  }

  /// Closes the change subjects. Guarded so a mutation after `dispose()`
  /// does not add to a closed subject.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _changes.close();
    _rootIdChanges.close();
  }
}
