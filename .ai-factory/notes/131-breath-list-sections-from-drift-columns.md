# Breath list — derive sections + starred duplication from row columns (not the server tag)

**Date:** 2026-06-20
**Source:** conversation context

## Key Findings

- Today the breath list groups by the **server-provided** `BreathSessionListEntry.section` (`BreathListSection {starred, mine, shared}`), assigned by `ListSessions` and carried through `BreathSessionNotifier.entries`. The offline-first goal (render from Drift) needs the sections built **locally** from session columns, because the Drift `BreathSessions` table stores no section tag — only `userId`, `isStarred`, `shared`, `createdAt`.
- All inputs for local derivation already exist on every `BreathSession`: MINE = `userId == currentUser.id`, SHARED = `userId != currentUser.id`, STARRED = `isStarred == true` (rendered as a **duplicate** entry alongside its MINE/SHARED placement). Duplication is a **render concern**, not storage — note 100's "Drift PK-by-id can't hold dup ids" was a category error.
- This task is a **behaviour-equivalent refactor**: still network-fed, but the sectioned+duplicated list is now built from a flat `List<BreathSession>` via columns. It is the shared builder both the network path and the later Drift-render path (note 132) will call. No UI change, no Drift change, no proto change.

## Details

### Current state

- `BreathSessionNotifier` stores `entries: List<BreathSessionListEntry>` where each entry pairs a `BreathSession` with a server `BreathListSection`. `load`/`refresh` set `entries` directly from `repository.fetch(...).entries` (which come from `ListSessions`).
- `BreathSessionListService._mapEntries` maps each entry → `BreathSessionListItemDTO` using `entry.section` (`_mapSection`) and `_determineOwnership(session)` (already derives mine/shared from `userId`).
- `BreathSessionListViewModel._buildItemsWithSections` groups the DTOs by `section` (STARRED → MINE → SHARED).

### Target

Introduce one pure function — call it `buildSectionedEntries(List<BreathSession> sessions, String currentUserId)` — that produces the ordered, sectioned, duplicated list:
- For each session: emit a MINE entry if `userId == currentUserId`, else a SHARED entry.
- Additionally emit a STARRED entry for every session with `isStarred == true` (the duplicate).
- Order within each section: `createdAt` DESC (matches `BreathSessionDao.getSessions()` ordering — see note 132). Section order STARRED → MINE → SHARED is applied by the existing `_buildItemsWithSections` downstream.

Place the builder where the notifier can call it (it owns `entries`). The notifier's `load`/`refresh` keep fetching from the API but now build `entries` via `buildSectionedEntries(result.entries.map((e) => e.session), currentUserId)` instead of trusting `result.entries`' server `section`. `currentUserId` comes from the injected `UserNotifier` (the notifier already receives `authStream`; add a `currentUserId` source or pass it).

### Files

- `lib/BreathModule/Core/BreathSessionNotifier.dart` — add the builder + use it in `load`/`refresh`/`create`/`starSession` paths where `entries` are constructed (the optimistic `starSession` STARRED logic collapses into "set `isStarred`, rebuild via the builder").
- `lib/BreathModule/Models/BreathListSection.dart` / `BreathSessionsListResponse.dart` — `BreathSessionListEntry.section` may stay for the wire DTO but is no longer the grouping source; do not remove the wire field yet (note 133 retires the network render path).
- `lib/BreathModule/BreathSessionListService.dart` — `_mapEntry` now maps the locally-built entry; `_determineOwnership` and the section mapping stay consistent with the builder.

### Guards

- Behaviour must stay equivalent for the common case — local derivation must match the server's STARRED/MINE/SHARED semantics (incl. a starred session appearing in both STARRED and its owner section).
- Do NOT touch `BreathSessionListViewModel._buildItemsWithSections` section ordering, the Drift schema, or the proto.
- `starSession` optimistic mutation must keep working (rebuild the sectioned list from the mutated rows rather than the bespoke insert/remove logic).

### How to verify

- A starred own session shows in STARRED and MINE; a starred shared session in STARRED and SHARED; unstarring removes only the STARRED copy. Identical to today's server-tagged grouping.

## Open Questions

- Within-section order becomes `createdAt` DESC (local), which may differ from the server's curated order. Acceptable for a personal list; flag if product wants server order preserved (would require storing an order column).
