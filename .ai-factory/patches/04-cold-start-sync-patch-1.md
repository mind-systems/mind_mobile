# Patch: Cold Start Sync — Review Round 1

Source review: `reviews/04-cold-start-sync-review-1.md`

---

## Fix 1: Serialize `processEvents` calls

**File:** `lib/Core/Sync/SyncEngine.dart`
**Problem:** `processEvents()` is public and called from two paths — `sync()` (REST poll) and `SyncSocketListener` (socket push). Only `sync()` is guarded by `_isSyncing`. If a socket event arrives while `sync()` is suspended inside `processEvents()` at an `await` point, two `processEvents` calls run concurrently — issuing duplicate batch-fetch requests and writing to the same Drift tables in interleaved order.

**Why it matters:** Operations are idempotent so no data corruption occurs, but it wastes a network round-trip and makes the event-ID cursor update non-deterministic (whichever `setLastEventId` call runs last wins — still correct since both only advance, but unnecessarily racy).

**Fix:** Replace the boolean `_isSyncing` flag with a `Future?`-based serialization lock so that both `sync()` and `processEvents()` are serialized through the same gate.

### Current code (lines 15–57)

```dart
bool _isSyncing = false;

Future<void> sync() async {
  if (_isSyncing) return;
  _isSyncing = true;
  try {
    final lastEventId = await syncStateDao.getLastEventId();
    final response = await syncApi.fetchChanges(lastEventId);
    if (response.fullResync) {
      await _handleFullResync();
      return;
    }
    if (response.events.isEmpty) return;
    await processEvents(response.events);
  } catch (e) {
    log('[SyncEngine] sync failed: $e', name: 'SyncEngine');
  } finally {
    _isSyncing = false;
  }
}

Future<void> processEvents(List<ChangeEvent> events) async {
  if (events.isEmpty) return;
  events.sort((a, b) => a.id.compareTo(b.id));
  final grouped = <String, List<ChangeEvent>>{};
  for (final event in events) {
    grouped.putIfAbsent(event.entity, () => []).add(event);
  }
  for (final entry in grouped.entries) {
    if (entry.key == 'breath_session') {
      await _handleBreathSessionEvents(entry.value);
    } else {
      log('[SyncEngine] unknown entity: ${entry.key}', name: 'SyncEngine');
    }
  }
  final maxEventId = events.map((e) => e.id).reduce((a, b) => a > b ? a : b);
  final currentId = await syncStateDao.getLastEventId();
  if (maxEventId > currentId) {
    await syncStateDao.setLastEventId(maxEventId);
  }
}
```

### Patched code

```dart
Future<void>? _activeSyncOp;

Future<void> sync() async {
  if (_activeSyncOp != null) return;
  try {
    _activeSyncOp = _doSync();
    await _activeSyncOp;
  } finally {
    _activeSyncOp = null;
  }
}

Future<void> _doSync() async {
  try {
    final lastEventId = await syncStateDao.getLastEventId();
    final response = await syncApi.fetchChanges(lastEventId);
    if (response.fullResync) {
      await _handleFullResync();
      return;
    }
    if (response.events.isEmpty) return;
    await _processEvents(response.events);
  } catch (e) {
    log('[SyncEngine] sync failed: $e', name: 'SyncEngine');
  }
}

Future<void> processEvents(List<ChangeEvent> events) async {
  // Wait for any in-flight sync() to finish before processing socket events,
  // so we don't interleave REST-poll writes with socket-push writes.
  if (_activeSyncOp != null) {
    await _activeSyncOp;
  }
  await _processEvents(events);
}

Future<void> _processEvents(List<ChangeEvent> events) async {
  if (events.isEmpty) return;
  events.sort((a, b) => a.id.compareTo(b.id));
  final grouped = <String, List<ChangeEvent>>{};
  for (final event in events) {
    grouped.putIfAbsent(event.entity, () => []).add(event);
  }
  for (final entry in grouped.entries) {
    if (entry.key == 'breath_session') {
      await _handleBreathSessionEvents(entry.value);
    } else {
      log('[SyncEngine] unknown entity: ${entry.key}', name: 'SyncEngine');
    }
  }
  final maxEventId = events.map((e) => e.id).reduce((a, b) => a > b ? a : b);
  final currentId = await syncStateDao.getLastEventId();
  if (maxEventId > currentId) {
    await syncStateDao.setLastEventId(maxEventId);
  }
}
```

### Behavior change

- `sync()` still drops concurrent callers (returns immediately if another `sync()` is in flight) — same as before.
- `processEvents()` now **waits** for an in-flight `sync()` to complete before processing socket-delivered events, preventing interleaved writes and duplicate batch-fetch requests.
- The `bool _isSyncing` field is removed. `_activeSyncOp` serves the same gate purpose and additionally lets `processEvents` await completion.

### Delete

Remove the `import 'dart:async';` line only if no other `dart:async` usage exists in the file. (Currently there is none — the file only imports `dart:developer`.)

---

## Fix 2: Guard `_handleFullResync` against infinite loop

**File:** `lib/Core/Sync/SyncEngine.dart`
**Problem:** `_handleFullResync()` resets `lastEventId` to 0. On the next `sync()` call, the client sends `GET /sync/changes?after=0`. If the server treats `after=0` the same as "gap too large" and responds with `fullResync: true` again, this creates a silent infinite loop — clearing the cache and re-invalidating on every sync without ever advancing.

**Why it matters:** Even if the current server doesn't exhibit this behaviour, it's a latent defect. A future server change or a misconfigured environment could trigger it, and the only symptom would be the home screen always loading from the API instead of the Drift cache, with no error logged.

**Fix:** Track whether a full resync was already performed within the current `sync()` invocation. If the server sends `fullResync: true` twice in a row (across consecutive `sync()` calls with `lastEventId == 0`), log a warning and bail out instead of looping.

### Current code (lines 19–36, inside `_doSync` after Fix 1)

```dart
Future<void> _doSync() async {
  try {
    final lastEventId = await syncStateDao.getLastEventId();
    final response = await syncApi.fetchChanges(lastEventId);
    if (response.fullResync) {
      await _handleFullResync();
      return;
    }
    if (response.events.isEmpty) return;
    await _processEvents(response.events);
  } catch (e) {
    log('[SyncEngine] sync failed: $e', name: 'SyncEngine');
  }
}
```

### Patched code

```dart
Future<void> _doSync() async {
  try {
    final lastEventId = await syncStateDao.getLastEventId();
    final response = await syncApi.fetchChanges(lastEventId);
    if (response.fullResync) {
      if (lastEventId == 0) {
        log('[SyncEngine] server sent fullResync for after=0, skipping to prevent loop', name: 'SyncEngine');
        return;
      }
      await _handleFullResync();
      return;
    }
    if (response.events.isEmpty) return;
    await _processEvents(response.events);
  } catch (e) {
    log('[SyncEngine] sync failed: $e', name: 'SyncEngine');
  }
}
```

### Behavior change

- First `fullResync` (when `lastEventId > 0`): handled normally — cache cleared, cursor reset to 0, notifier invalidated.
- Second `fullResync` (when `lastEventId == 0`, meaning a reset already happened or this is a fresh install): logged and skipped. The app proceeds with whatever data the normal pagination flow provides.
- No new fields or state introduced — the check is purely based on the current cursor value.
