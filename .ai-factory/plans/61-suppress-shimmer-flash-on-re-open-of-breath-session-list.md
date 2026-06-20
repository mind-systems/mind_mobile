# Plan: Suppress shimmer flash on re-open of breath session list

## Context
On re-opening the breath session list, `BreathSessionListViewModel.build()` always returns a shimmer state because the `BehaviorSubject` replay fires one microtask too late. This milestone reads the already-cached entries from the long-lived `BreathSessionNotifier` synchronously in `build()`, so content renders immediately on re-open while a true cold start still shows the shimmer.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Implementation

- [x] **Task 1: Add `currentItems()` to the service interface**
  Files: `packages/breath_module/lib/src/BreathSessionsList/IBreathSessionListService.dart`
  Add a synchronous accessor to `IBreathSessionListService`:
  ```dart
  /// Returns the currently cached list items, or an empty list if none
  /// have been loaded yet. Synchronous — reads the in-memory notifier state,
  /// no DB/network round-trip. Used to suppress the shimmer flash on re-open.
  List<BreathSessionListItemDTO> currentItems();
  ```
  `BreathSessionListItemDTO` is already imported in this file. Place the method alongside the other abstract members.

- [x] **Task 2: Implement `currentItems()` in the concrete service** (depends on Task 1)
  Files: `lib/BreathModule/BreathSessionListService.dart`
  Implement the new interface method by mapping the notifier's current in-memory entries through the existing `_mapEntries` helper:
  ```dart
  @override
  List<BreathSessionListItemDTO> currentItems() =>
      _mapEntries(notifier.currentState.entries);
  ```
  Reuse the existing private `_mapEntries(List<BreathSessionListEntry>)` mapper — do not duplicate mapping logic. `notifier.currentState` is already used in `loadNext`, so the accessor is available.

- [x] **Task 3: Render cached content synchronously in `build()`** (depends on Task 2)
  Files: `packages/breath_module/lib/src/BreathSessionsList/BreathSessionListViewModel.dart`
  Update `build()` so it returns a content state immediately when cached items exist, falling through to the existing shimmer path only on a true cold start. Keep the existing subscription wiring and always fire `_loadInitialPage()` in the background:
  ```dart
  @override
  BreathSessionListState build() {
    final subscription = service.observeChanges().listen(_onEvent);
    ref.onDispose(() => subscription.cancel());

    _loadInitialPage(); // always refresh from server in background

    final cached = service.currentItems();
    if (cached.isNotEmpty) {
      return BreathSessionListState(
        items: _buildItemsWithSections(_transformDTOsToModels(cached)),
        mode: BreathSessionListMode.content,
        hasMore: true, // conservative — background load emits ListUpdatedEvent and corrects it
      );
    }

    return BreathSessionListState(
      items: [SkeletonCellModel(animated: true)],
      mode: BreathSessionListMode.initialLoading,
      hasMore: true,
    );
  }
  ```
  Reuse the existing `_buildItemsWithSections` and `_transformDTOsToModels` helpers already defined in this class. The background `_loadInitialPage()` continues to emit `ListUpdatedEvent` via `observeChanges()`, which silently reconciles `hasMore` and any server-side changes through the existing `_handleListUpdated` path. Do not alter `_handleSessionsInvalidated` or `_loadInitialPage` — invalidation should still reset to the shimmer.

## Notes
- Three files only, matching the spec in `.ai-factory/notes/128-suppress-breath-list-shimmer-flash-on-reopen.md`.
- Shimmer intentionally still shows on cold start (empty notifier → `currentItems()` returns `[]`).
- `hasMore: true` is deliberately conservative; the background refresh corrects it. No new event types or DAO/Drift changes are in scope.
