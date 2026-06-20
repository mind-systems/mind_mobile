import 'Models/BreathSessionListItemDTO.dart';

/// Service adapting domain BreathSession models to presentation DTOs
/// for the session list.
///
/// - Unaware of UI concerns
/// - Works only with DTOs and events
///
/// All changes arrive via observeChanges().
/// refresh() performs a write-through full-mirror sync; loadNext() is a no-op.
abstract class IBreathSessionListService {
  /// Subscribe to all session list change events.
  ///
  /// Emits:
  /// - ListUpdatedEvent (full Drift-mirror snapshot after any domain change;
  ///   hasMore is always false — the mirror is always complete)
  /// - SessionsInvalidatedEvent (user change)
  Stream<BreathSessionListEvent> observeChanges();

  /// No-op stub — the full Drift mirror is always complete and hasMore is
  /// always false, so scroll pagination never triggers this path. Kept for
  /// interface compatibility with the ViewModel.
  Future<void> loadNext(int pageSize);

  /// Write-through full-mirror sync (pull-to-refresh).
  ///
  /// Pages through all server sessions into Drift, then the notifier re-reads
  /// Drift and emits a ListUpdatedEvent with the complete local mirror.
  ///
  /// [pageSize] — items per server page in the loop
  Future<void> refresh(int pageSize);

  /// Returns the currently cached list items, or an empty list if none
  /// have been loaded yet. Synchronous — reads the in-memory notifier state,
  /// no DB/network round-trip. Used to suppress the shimmer flash on re-open.
  List<BreathSessionListItemDTO> currentItems();
}

/// Base type for all session list events
sealed class BreathSessionListEvent {}

/// Full list snapshot — emitted after any domain change (refresh, create, update, delete, star)
class ListUpdatedEvent extends BreathSessionListEvent {
  final List<BreathSessionListItemDTO> items;
  final bool hasMore;

  ListUpdatedEvent({
    required this.items,
    required this.hasMore,
  });
}

/// List invalidated (user change)
class SessionsInvalidatedEvent extends BreathSessionListEvent {}
