## Code Review — Patch Round 1

**Scope:** `lib/Core/Sync/SyncEngine.dart` (only code change; `.ai-factory/` files are documentation)

### Changes reviewed

1. **Serialization lock** — `bool _isSyncing` replaced with `Future<void>? _activeSyncOp`. `sync()` stores the `_doSync()` future; `processEvents()` awaits it before proceeding.
2. **Full-resync loop guard** — `_doSync()` checks `lastEventId == 0` before executing `_handleFullResync()`. If the server sends `fullResync` when the cursor is already at zero, the engine logs and skips instead of looping.

### Verification

- **Caller compatibility:** `SyncSocketListener` calls `processEvents()` (unchanged signature). `App.dart` calls `sync()` (unchanged signature). No other callers exist. No breakage.
- **Timeout interaction:** `App.dart` line 135 wraps `sync()` with `.timeout(5s)`. If the timeout fires, the caller proceeds but `sync()` internally still awaits `_activeSyncOp`. The `finally` block runs only when `_doSync()` actually completes, so `_activeSyncOp` stays non-null during the window — any `processEvents()` call arriving in that gap correctly waits. No zombie state.
- **Error propagation:** `_doSync()` has a catch-all, so `_activeSyncOp` never rejects. `processEvents()` → `_processEvents()` propagates errors to `SyncSocketListener.catchError()`, same as before.
- **No schema changes.** No `build_runner` or migration update needed.

### Issues

None.

REVIEW_PASS
