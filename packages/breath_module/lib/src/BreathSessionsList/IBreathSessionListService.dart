import 'Models/BreathSessionListItemDTO.dart';

/// Service adapting domain BreathSession models to presentation DTOs
/// for the session list.
///
/// - Unaware of UI concerns
/// - Works only with DTOs and events
///
/// All changes arrive via observeChanges().
/// loadNext/refresh complete after the request finishes (for error handling);
/// data is emitted through the stream.
abstract class IBreathSessionListService {
  /// Subscribe to all session list change events.
  ///
  /// Emits:
  /// - ListUpdatedEvent (full list snapshot after any domain change)
  /// - SessionsInvalidatedEvent (user change)
  Stream<BreathSessionListEvent> observeChanges();

  /// Load the next page using the cursor stored in the notifier.
  /// First call (cursor==null) loads the first page.
  ///
  /// Result arrives via observeChanges() as ListUpdatedEvent.
  ///
  /// [pageSize] — number of items per page
  Future<void> loadNext(int pageSize);

  /// Full sync (pull-to-refresh).
  ///
  /// Resets to the first page.
  ///
  /// Result arrives via observeChanges() as ListUpdatedEvent.
  ///
  /// [pageSize] — number of items for the first page
  Future<void> refresh(int pageSize);
}

/// Base type for all session list events
sealed class BreathSessionListEvent {}

/// Full list snapshot — emitted after any domain change (load, refresh, create, update, delete, star)
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
