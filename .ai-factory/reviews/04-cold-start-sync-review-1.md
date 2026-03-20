## Code Review Summary

**Files Reviewed:** 13 (source files, excluding `.g.dart`, plans, notes, roadmap)
**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md** — WARN: The plan notes mention "atomic with data updates" for `lastEventId` persistence, implying a Drift transaction wrapping both entity writes and cursor advancement. The implementation performs these as sequential awaits across two separate DAOs (`breathSessionDao`, `syncStateDao`). SyncEngine only has DAO references, not the `Database` itself, so a cross-DAO transaction isn't possible without a refactoring. This is safe in practice — operations are idempotent, so a crash between writes just causes harmless reprocessing on next sync. No action needed now, but worth noting the deviation from the stated design.
- **RULES.md** — file not present (WARN, non-blocking).
- **ROADMAP.md** — all four sync milestones are marked complete, matching the committed code.

### Critical Issues

None.

### Suggestions

1. **Concurrent `processEvents` calls are possible**
   `SyncEngine._isSyncing` guards `sync()` but not the public `processEvents()`. After login, the post-login subscription fires `syncEngine.sync()` (fire-and-forget, no timeout). If the server is slow and the socket connects and delivers a `sync:changed` event before `sync()` finishes, `SyncSocketListener` calls `processEvents()` while the in-flight `sync()` is suspended inside its own `processEvents()` at an `await` point. Both would concurrently call `syncApi.fetchSessionsBatch()`, write to Drift, and update `lastEventId`.
   This is **benign** because every operation is idempotent (upserts, cursor only advances), but it wastes a network request. A lightweight fix: reuse the `_isSyncing` flag (or a `Completer`) inside `processEvents` to serialize calls.

2. **`_handleFullResync` — verify server behaviour for `after=0`**
   After a full resync, `lastEventId` is reset to 0. The next `sync()` call sends `GET /sync/changes?after=0`. If the server also responds with `fullResync: true` for `after=0` (e.g. treating 0 as "too old"), this creates a silent infinite loop on each cold start. Worth confirming the API contract: `after=0` should return events normally (not `fullResync`).

### Positive Notes

- Clean separation: SyncEngine is pure Dart, no Flutter/Riverpod imports — follows the domain-layer convention.
- Two-input-path design (REST poll + socket push) converging on a single `processEvents` pipeline is well-architected and easy to extend to new entity types.
- Defensive coding throughout: `SyncSocketListener` guards against non-Map socket payloads and non-List `events` fields; `SyncResponse.fromJson` defaults `fullResync` to `false`; cold-start sync has a 5-second timeout safeguard.
- `ILiveSocketService` interface was updated cleanly — the test fake was also updated to satisfy the new contract.
- Schema migration (v2 → v3) is correct and consistent with the existing migration ladder.
- `SyncStateDao` uses `insertOnConflictUpdate` for cursor persistence — correct upsert semantics.
- App.dart wiring follows the established single-line initializer style and the `SocketConnectionCoordinator` subscription pattern.
