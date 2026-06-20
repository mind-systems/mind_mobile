# Suppress Breath Session List Shimmer Flash on Re-open

**Date:** 2026-06-20
**Source:** conversation context

## Key Findings

- `BreathSessionListViewModel.build()` unconditionally returns a shimmer state synchronously, even when `BreathSessionNotifier` already holds cached entries from a prior load.
- `service.observeChanges()` wraps a `BehaviorSubject` that replays its last value on subscribe — but Dart stream callbacks fire on the next microtask, so `build()` always returns shimmer before the replay arrives.
- The notifier (`BreathSessionNotifier`) is a long-lived domain object (`App.shared`), so its in-memory state survives navigation. Checking it synchronously in `build()` eliminates the flash without any DB or network round-trip.

## Details

### Current loading flow

```
build()
  → returns shimmer state (synchronous)
  → service.observeChanges().listen(_onEvent)  ← BehaviorSubject subscribe
  → _loadInitialPage()  ← async, goes to network
                                ↓ (next microtask)
  ← BehaviorSubject replay arrives → _handleListUpdated → content state
```

On re-open, the BehaviorSubject replays the last `PageLoaded` event immediately, but because Dart stream callbacks are async, the ViewModel has already returned the shimmer state to Riverpod and the user sees a flash.

### Fix: synchronous cache check in `build()`

**Step 1 — Add accessor to `IBreathSessionListService`**
(`packages/breath_module/lib/src/BreathSessionsList/IBreathSessionListService.dart`)

Add:
```dart
List<BreathSessionListItemDTO> currentItems();
```

**Step 2 — Implement in `BreathSessionListService`**
(`lib/BreathModule/BreathSessionListService.dart`)

```dart
@override
List<BreathSessionListItemDTO> currentItems() =>
    _mapEntries(notifier.currentState.entries);
```

**Step 3 — Use in `BreathSessionListViewModel.build()`**
(`packages/breath_module/lib/src/BreathSessionsList/BreathSessionListViewModel.dart`)

```dart
@override
BreathSessionListState build() {
  final subscription = service.observeChanges().listen(_onEvent);
  ref.onDispose(() => subscription.cancel());

  _loadInitialPage(); // always refresh in background

  final cached = service.currentItems();
  if (cached.isNotEmpty) {
    // Return content state immediately — no shimmer flash
    return BreathSessionListState(
      items: _buildItemsWithSections(_transformDTOsToModels(cached)),
      mode: BreathSessionListMode.content,
      hasMore: true, // conservative — server will correct
    );
  }

  return BreathSessionListState(
    items: [SkeletonCellModel(animated: true)],
    mode: BreathSessionListMode.initialLoading,
    hasMore: true,
  );
}
```

`_loadInitialPage()` still fires in the background in both cases — it refreshes from the server and emits `ListUpdatedEvent`, which updates the state silently when the user is looking at real content.

### Why not read from Drift DB?

The local `IBreathSessionDao.getSessions()` returns `List<BreathSession>` without `section` info (STARRED/MINE/SHARED comes from the server). Deriving section locally is possible but adds complexity and still requires an async call, blocking `build()`. The in-memory notifier state is simpler, already correctly sectioned, and non-empty for every re-open after the first load.

### Shimmer still appears on true cold start

On first launch (empty notifier), `currentItems()` returns `[]` and the shimmer shows as before. Caching to Drift for offline warmup is out of scope here.

### `hasMore: true` conservatism

When returning cached state, we don't know the true `hasMore` value from the last server response. Setting it to `true` is conservative: the background `_loadInitialPage()` will emit a `ListUpdatedEvent` shortly after, correcting `hasMore` to the actual value. The user may briefly see a paging skeleton on scroll-to-bottom, which disappears when the server response arrives.

## Open Questions

- None.
