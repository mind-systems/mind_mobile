# Breath list — online refresh is write-through-then-reread; UI never holds the server cursor

**Date:** 2026-06-20
**Source:** conversation context

## Key Findings

- After note 132 the list renders from Drift, but `load`/`refresh` still set `entries` directly from the `ListSessions` network response and the ViewModel still threads the opaque server `nextCursor` for pagination. This is the source of the user's "dead end": mixing a UI that should be offline-first with a server cursor that can go stale (the local DB may lack what the cursor's page references) couples two paginations that shouldn't be coupled.
- Resolution: **the server cursor belongs to the refresh/sync layer, never the UI.** `load`/`refresh` become *write-through-then-reread*: fetch from `ListSessions` → `saveSessions` into Drift → re-read Drift via `buildSectionedEntries` → emit. The cursor is consumed **inside** the refresh (loop pages into Drift until exhausted) and never surfaced to the ViewModel. Pagination, if ever needed, is over the **local DB**. Drift becomes the single source of truth the UI reads.
- This is uniform for guest + authenticated: the same `ListSessions` write-through is the populate/refresh for everyone (the only online path for guests, who have no sync); authenticated users *also* get `SyncEngine` deltas into the same Drift via the same re-read path (note 132). The user's requirement — "sync every session the user has seen, offline-first for all, identical for guest and new users" — is met: seen sessions persist via write-through, render from Drift, refresh online when available.

## Details

### Current state

- `BreathSessionNotifier.load(cursor, pageSize)` / `refresh(pageSize)` call `repository.fetch/refresh` (→ `ListSessions`), set `entries` from the response, and store `nextCursor`. `BreathSessionListService.loadNext` passes `notifier.currentState.nextCursor`; the ViewModel exposes `hasMore`/`loadNext` driven by that cursor.
- `repository.fetch/refresh` already `saveSessions` (write-through) — so the data lands in Drift; the response is just *also* used as the render source.

### Target

1. **Refresh = full write-through mirror.** `refresh(pageSize)` loops `ListSessions` from `cursor=null` following `nextCursor` until null, `saveSessions` each page into Drift, then re-reads Drift (`buildSectionedEntries`) and emits. (Personal list is small; a full mirror is cheap and makes the local STARRED/MINE/SHARED derivation complete — no "duplicate on an unloaded page" edge from note 100.) The server cursor is a local loop variable, never stored on the notifier state.
2. **Drop `nextCursor` from `BreathSessionsState`** (and the ViewModel's cursor-based `hasMore`/`loadNext`), or repurpose `loadNext`/`hasMore` to page over Drift if the dataset ever needs it. For now: full Drift render, `hasMore=false` (everything is local). Keep `loadNext` as a no-op/local-pager stub.
3. **`_loadInitialPage()` (ViewModel)** now calls the write-through `refresh` (background), correcting the Drift-seeded render. Offline → the fetch fails silently and the Drift render stands.

### Files

- `lib/BreathModule/Core/BreathSessionNotifier.dart` — `refresh` loops pages → write-through → re-read Drift → emit; `load`/`nextCursor` removed or relegated; `BreathSessionsState.nextCursor` dropped.
- `lib/BreathModule/Core/BreathSessionRepository.dart` — `refresh` returns nothing UI-render-bound (or returns the Drift list); it owns the page loop + `saveSessions`; no offset-Drift path reintroduced.
- `lib/BreathModule/BreathSessionListService.dart` — `loadNext`/`refresh`/`observeChanges` adjusted; `hasMore` reflects local completeness (false for a full mirror).
- `packages/breath_module/.../BreathSessionListViewModel.dart` — remove cursor-driven pagination state; `_loadInitialPage` → background write-through refresh; `_handleListUpdated` unchanged.
- `proto` / `BreathSessionApi` — UNCHANGED. `ListSessions` (cursor) stays as the wire call; only the UI's relationship to it changes.

### Guards

- Do NOT remove `ListSessions` or change the proto — it remains the online populate/refresh; only the UI stops rendering its response and holding its cursor.
- Do NOT reintroduce an offset-Drift *UI* pagination contract from the pre-note-100 era; the UI reads the full Drift mirror.
- Keep write-through everywhere (detail `getById`, create, update, star) so "seen" stays persisted.
- Failure path: an offline/failed `refresh` must NOT clear the Drift-rendered list — catch and keep the local render (today's `_loadInitialPage` catch sets empty; change it to leave the existing Drift content).
- Privacy: `_onUserIdChanged → deleteAll` stays.

### How to verify

- Online refresh updates Drift and the list re-renders from Drift (not from the raw response). Pull-to-refresh offline → list unchanged, no error wipe.
- No `nextCursor` is read anywhere in the ViewModel/service render path (grep). The server cursor exists only inside the refresh loop.
- Guest, authenticated, and fresh-install users all follow the identical render-from-Drift + write-through-refresh path; authenticated additionally update via `SyncEngine` invalidate.

## Open Questions

- If a user's list ever grows large enough that a full mirror per refresh is costly, switch the refresh to a delta/`If-Modified` or lean entirely on `SyncEngine` for authenticated users and a capped first-page fetch for guests. Not a concern at current personal-list scale.
