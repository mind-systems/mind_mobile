import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Core/Grpc/ModuleSession.dart';

/// Skeleton per note 22; routing bodies + backing state filled by note 14.
///
/// The routing layer that will hold a `Map<String, ModuleSession>` keyed by
/// `module_session_id`, owned and driven by `ModuleStateChannel`. This
/// milestone declares the full surface with no routing bodies so downstream
/// tasks (RootStateChannel, addressing, bio) can import against it now.
class SessionRegistry {
  /// Upserts [session] by `id` — updates in place if an entry with the same
  /// `id` already exists, otherwise inserts a new entry.
  void upsert(ModuleSession session) => throw UnimplementedError();

  /// Unconditionally removes the entry with the given `id`, if present.
  ///
  /// The terminal-status decision (proto `COMPLETED`/`INTERRUPTED`/
  /// `ABANDONED`) lives in the caller (`ModuleStateChannel`, note 14) —
  /// this method does not branch on `ModuleSession.status`, which is only
  /// `{idle, active}` and cannot represent terminal states.
  void removeTerminal(String id) => throw UnimplementedError();

  /// The `id` of the sole entry with `activityType == ActivityType.root`,
  /// or `null` if no root entry is present.
  String? get rootId => throw UnimplementedError();

  /// The sole non-root entry of the given [type], or `null` if none exists.
  ModuleSession? childOfType(ActivityType type) => throw UnimplementedError();

  /// Emits the current `rootId` whenever it changes, so adapters/bio can
  /// observe root session transitions.
  Stream<String?> get rootIdChanges => throw UnimplementedError();

  /// Emits whenever the registry's contents change, so adapters/bio can
  /// observe any session transition.
  Stream<void> get changes => throw UnimplementedError();

  /// No-op — this milestone declares no stored state or subscriptions to
  /// tear down. Kept as an empty body (not `throw UnimplementedError()`) so
  /// a test `tearDown` calling `dispose()` does not error the suite.
  void dispose() {}
}
