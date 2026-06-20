# Breath list — render from Drift (offline-first cold start; invalidate re-reads Drift)

**Date:** 2026-06-20
**Source:** conversation context

## Key Findings

- Today on a cold restart the **first** open of the breath list waits on the network: `BreathSessionNotifier` is seeded empty, so `BreathSessionListService.currentItems()` (reads `notifier.currentState.entries`) is empty → the ViewModel shows the shimmer until `ListSessions` returns. The **second** open is instant only because the in-memory notifier still holds entries (note 128). The list never reads Drift.
- Drift already holds the data: write-through (`saveSessions` on every fetch/refresh/detail) persists every **seen** session (own AND shared), and for authenticated users the `SyncEngine` keeps it fresh via deltas and calls `breathSessionNotifier.invalidate()`. `BreathSessionDao.getSessions()` (orders `createdAt` DESC) is the ready render source.
- Fix: **seed the notifier from Drift at construction**, and make `invalidate()` **re-read Drift and emit the sectioned list** (instead of emitting an empty `SessionsInvalidated` that triggers a network reload). Then `currentItems()` is non-empty on first open for anyone with cached rows → instant, offline. Uniform for guest and authenticated: guests have no sync but write-through fills Drift the same way; authenticated additionally get sync deltas flowing through the same `invalidate()` → re-read path.
- Depends on note 131 (sections built from columns) — Drift rows carry no server `section` tag, so the sectioned list must be derived via `buildSectionedEntries`.

## Details

### Current state

- `BreathSessionNotifier` seeds `BehaviorSubject` with `entries: []`. `invalidate()` emits `entries: [], lastEvent: SessionsInvalidated()`. `BreathSessionListService.observeChanges()` maps `SessionsInvalidated` → `SessionsInvalidatedEvent`, and the ViewModel's `_handleSessionsInvalidated` resets to shimmer + calls `_loadInitialPage()` (network).
- `SyncEngine` (cold start + realtime deltas) writes sessions into Drift then calls `breathSessionNotifier.invalidate()`.

### Target

1. **Seed from Drift during `App.initialize()` with an awaited read (settled — not lazy).** The notifier is an App-level singleton built in `App.initialize()`, where the `BreathSessionDao` is already available. Expose `Future<void> loadLocal()` on the notifier (reads `repository.localSessions()` → `buildSectionedEntries` → seeds the `BehaviorSubject`) and **`await` it in `App.initialize()` right after the notifier is constructed**, before the first screen can build. Because `ViewModel.build()` reads `currentItems()` synchronously and the seed has already completed, `currentState.entries` is warm — no shimmer flash, no separate App-level snapshot cache. Sequencing: seed-from-Drift (await) → then the cold-start `SyncEngine.sync()` runs and refines via `invalidate()` (note: seed must precede or run independently of the 5 s sync timeout so an offline launch still shows cached rows immediately).
2. **`invalidate()` re-reads Drift.** Change `invalidate()` (and the SyncEngine-driven path) to: read `dao.getSessions()` → `buildSectionedEntries` → emit `ListUpdatedEvent`-bearing state, instead of emitting an empty invalidated state. So a sync delta (authenticated) refreshes the visible list straight from Drift, no network round-trip in the UI path.
3. **Expose a Drift list read on the repository.** `IBreathSessionRepository` gains `Future<List<BreathSession>> localSessions()` delegating to `_dao.getSessions()` (the orphaned method). The notifier uses it for seed + invalidate re-read.

### Files

- `lib/BreathModule/Core/BreathSessionNotifier.dart` — seed from Drift at init; `invalidate()` re-reads Drift + emits a populated state (keep a `SessionsRefreshed`/`PageLoaded`-style event so `BreathSessionListService.observeChanges` emits a `ListUpdatedEvent`, not `SessionsInvalidatedEvent`).
- `lib/BreathModule/Core/IBreathSessionRepository.dart` + `BreathSessionRepository.dart` — add `localSessions()` → `_dao.getSessions()`.
- `lib/BreathModule/BreathSessionListService.dart` — `currentItems()` already reads `notifier.currentState.entries`; ensure it reflects the Drift seed.
- (verify) `packages/breath_module/.../BreathSessionListViewModel.dart` — `build()` cold-start path now finds non-empty `currentItems()`; confirm no shimmer flash and that the background `_loadInitialPage()` (note 133) still corrects.

### Guards

- Keep `_onUserIdChanged → repository.deleteAll() + invalidate()` (privacy: never show user A's cached sessions to user B). "Everything seen persists" is **within** a user identity; guest↔user transitions still wipe.
- Do NOT remove the background online refresh yet — note 133 reworks it. This task only adds the Drift **read** path; the network path keeps running so a fresh/empty Drift (new guest) still populates.
- Empty Drift (fresh install / guest first run) must still fall through to the shimmer + background fetch — offline-first means "render Drift if present", not "never fetch".

### How to verify

- Cold restart with cached sessions → first open of the list is **instant**, no shimmer, before any network. Airplane mode → list still renders from Drift.
- Authenticated: a sync delta (create/update/delete on another device) updates the open list with no manual refresh (via `invalidate()` → Drift re-read).
- Fresh guest, empty Drift → shimmer then list after the online fetch; second open instant.

## Decisions (settled)

- **Cold-start render is made synchronous by seeding in `App.initialize()` with an awaited `notifier.loadLocal()`** (see Details #1) — `currentState.entries` is warm before any screen builds, so the synchronous `currentItems()` read hits ready data. No App-level snapshot cache, no first-microtask race.

## Open Questions

- None blocking.
