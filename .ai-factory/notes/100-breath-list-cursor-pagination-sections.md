# Breath-Session List → Cursor Pagination + Server Section Tags + Duplication

**Date:** 2026-06-04
**Source:** conversation context — starred-own-sessions feature (mobile half). Pairs with `mind_api/.ai-factory/notes/40-starred-own-sessions-cursor-pagination.md` (requirements) and `mind_api/.ai-factory/notes/41-breath-sessions-proto-cursor-sections.md` (final contract).

## Key Findings

- The backend `ListSessions` contract changes from offset pagination to an **opaque cursor**, and now returns **per-item section tags** with **intentional duplication** (the same session appears once per section it belongs to). Sections, in fixed order: `STARRED` (all starred — own + others) → `MINE` (all own) → `SHARED` (others' shared).
- The current mobile model **cannot represent this**: the Notifier keys items by `id` (`Map<String,BreathSession> byId` + `List<String> order`) which collapses duplicates, and the Drift cache table `BreathSessions` has `id` as PRIMARY KEY so it cannot store the same session twice either. Therefore: the **list must render from cursor API responses held in the Notifier**, not from Drift; the Notifier state becomes an **ordered list of `(session, section)` entries that allows duplicate ids**.
- Drift is **retained** as a write-through cache for single-session reads (detail screen, `getById`, star write-through) — only the *list ordering/sectioning* stops coming from Drift. The Drift offset query `getSessions(limit, offset)` becomes unused by the list.
- This is one coupled vertical (proto → API → repository → notifier → service → package interface → viewmodel → screen). It cannot be split into independently-compiling halves: changing the response shape breaks every layer at once, and a "cursor-only, UX unchanged" intermediate would require throwaway client-side section code. It ships as one milestone.
- **Prerequisites:** (1) `mind_api` Phase 33 proto + service milestones merged (server speaks the new contract). (2) Mobile note 99 (own sessions starrable) — so the STARRED section can actually receive own sessions.

## Details

### Final proto contract (from API note 41 — copy verbatim into `mind_mobile/proto/`)

```proto
enum SessionSection { STARRED = 0; MINE = 1; SHARED = 2; }

message SessionListItem {
  BreathSessionWithStarredDto session = 1;
  SessionSection section = 2;
}

message ListSessionsRequest {
  optional string cursor = 1;   // replaces page (tag 1 reuse — lockstep, safe)
  int32 page_size = 2;
}

message ListSessionsResponse {
  repeated SessionListItem items = 1;
  optional string next_cursor = 2;
  // removed: total, page, page_size
}
```

### Step 0 — Proto copy + regen

- Copy `mind_api/proto/breath_sessions.proto` → `mind_mobile/proto/breath_sessions.proto` (do not edit by hand — `mind_api/proto/` is the single source of truth).
- Run `./scripts/gen_proto.sh`. This regenerates `lib/Core/Grpc/generated/breath_sessions.pb.dart` / `.pbgrpc.dart` with `ListSessionsRequest{cursor?, pageSize}`, `ListSessionsResponse{items, nextCursor}`, `SessionListItem{session, section}`, `enum SessionSection`. The old `data/total/page/pageSize` getters disappear → `BreathSessionApi.fetchAll` stops compiling. Expected; fixed in the same milestone.
- First-page request: construct `ListSessionsRequest(pageSize: N)` with `cursor` left unset (proto3 `optional` absent). Next page: `ListSessionsRequest(cursor: c, pageSize: N)`.

### Layer-by-layer changes

#### Domain section enum (new)

Add `enum BreathListSection { starred, mine, shared }` in `lib/BreathModule/Models/` (e.g. `BreathListSection.dart`). Domain must not depend on generated proto, so map proto `SessionSection` → this enum in the Api wrapper.

#### `lib/BreathModule/Core/BreathSessionApi.dart` + `IBreathSessionApi.dart`

Replace `fetchAll(int page, int pageSize)` with cursor form:

```dart
Future<BreathSessionsListResponse> fetchPage(String? cursor, int pageSize);
```

Implementation:
```dart
final req = cursor == null
    ? proto.ListSessionsRequest(pageSize: pageSize)
    : proto.ListSessionsRequest(cursor: cursor, pageSize: pageSize);
final response = await _service.listSessions(req);
return BreathSessionsListResponse(
  entries: response.items.map((it) => BreathSessionListEntry(
    session: _mapSessionWithStarred(it.session),
    section: _mapSection(it.section),
  )).toList(),
  nextCursor: response.hasNextCursor ? response.nextCursor : null,
);
```
Add `_mapSection(proto.SessionSection s)` → `BreathListSection`. Keep `_mapSessionWithStarred` (now reads `it.session`, a `BreathSessionWithStarredDto`).

#### `lib/BreathModule/Models/BreathSessionsListResponse.dart`

Replace `{ data, total, page, pageSize, hasMore }` with:
```dart
class BreathSessionListEntry {
  final BreathSession session;
  final BreathListSection section;
  const BreathSessionListEntry({required this.session, required this.section});
}

class BreathSessionsListResponse {
  final List<BreathSessionListEntry> entries;
  final String? nextCursor;
  const BreathSessionsListResponse({required this.entries, required this.nextCursor});
  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}
```

#### `lib/BreathModule/Core/BreathSessionRepository.dart` + `IBreathSessionRepository.dart`

Drop the Drift-offset-first list logic entirely. The list is now API-cursor sourced; Drift is write-through only.

```dart
Future<({List<BreathSessionListEntry> entries, String? nextCursor})> fetch(String? cursor, int pageSize) async {
  final response = await _api.fetchPage(cursor, pageSize);
  await _dao.saveSessions(response.entries.map((e) => e.session).toList()); // write-through; PK upsert dedups in Drift, harmless
  return (entries: response.entries, nextCursor: response.nextCursor);
}

Future<({List<BreathSessionListEntry> entries, String? nextCursor})> refresh(int pageSize) async {
  final response = await _api.fetchPage(null, pageSize); // first page = cursor unset
  // Do NOT deleteAllSessions here: with duplication the entry list ≠ row set, and detail/getById still need rows.
  await _dao.saveSessions(response.entries.map((e) => e.session).toList());
  return (entries: response.entries, nextCursor: response.nextCursor);
}
```
`getSessionById` and `starSession` Drift write-through stay unchanged. `BreathSessionDao.getSessions(limit, offset)` is now unused by the list — leave it in place (harmless; may serve future offline needs).

#### `lib/BreathModule/Core/BreathSessionNotifier.dart` + `Models/BreathSessionNotifierEvent.dart`

State model changes from id-keyed to an ordered entry list that allows duplicate ids:

```dart
class BreathSessionsState {
  final List<BreathSessionListEntry> entries; // STARRED block, then MINE, then SHARED (server order, dup ids allowed)
  final String? nextCursor;
  final BreathSessionNotifierEvent? lastEvent;
}
```

- `load(String? cursor, int pageSize)`: if `cursor == null` (first page) replace `entries` with the response; else append. **No dedup** — duplicates across sections are intentional. Store `nextCursor`. Emit `PageLoaded(entries: newEntries, nextCursor: ...)`.
- `refresh(int pageSize)`: replace `entries` with first-page response, store `nextCursor`, emit `SessionsRefreshed(entries, nextCursor)`.
- `PageLoaded` / `SessionsRefreshed` events: replace `page`/`hasMore` fields with the entry list + `nextCursor` (`hasMore` derivable as `nextCursor != null`).
- `getById(String id)`: scan `entries` for the first entry whose `session.id == id`, return its session; if none, fall back to `await repository.getById(id)` (Drift). Section is irrelevant for a single-session read.
- `starSession(id, starred)` — optimistic local section mutation so the STARRED section updates without a server round-trip:
  - Call `repository.starSession(id, starred)` (gRPC + Drift) as today.
  - `starred == true`: set `isStarred = true` on every entry with this id; if no entry with `section == starred` exists for this id, **prepend** a new `BreathSessionListEntry(session: <that session with isStarred=true>, section: BreathListSection.starred)`.
  - `starred == false`: **remove** every entry where `id == id && section == starred`; set `isStarred = false` on the remaining entries with this id.
  - Emit `SessionStarred(updatedSession)`. The ViewModel re-groups by section tag (below), so flat insertion position only needs to be inside/near the STARRED block — prepend is fine.

#### `lib/BreathModule/BreathSessionListService.dart` + package `IBreathSessionListService.dart`

The package interface (declared in `packages/breath_module/lib/src/BreathSessionsList/IBreathSessionListService.dart`) goes cursor-based:
- `fetchPage(int page, int pageSize)` → `loadNext()` (cursor held in the domain notifier; the package never sees the opaque cursor — it just asks for "more").
- `refresh(int pageSize)` stays by name; internals fetch first page.
- `PageLoadedEvent` (package) replaces `page`/`hasMore` with `hasMore` only (bool) — the package does not need the cursor string.

Concrete `BreathSessionListService` maps domain `BreathSessionListEntry` → package cell DTO, translating `BreathListSection` → package `ListSection` and tagging each cell with its section. `_determineOwnership` and the `ownership`/`isStarred` cell fields are **retained** (still computed) but no longer drive grouping — grouping now uses the server `section` tag. Keep them for cell metadata.

#### Package DTOs — `packages/breath_module/lib/src/BreathSessionsList/Models/`

- Add `enum ListSection { starred, mine, shared }`.
- `BreathSessionListItemDTO`: add `final ListSection section;`.
- `BreathSessionListCellModel` (`BreathSessionListItem.dart`): add `final ListSection section;`.
- `SectionHeaderType { mySessions, starredSessions, sharedSessions }` — **unchanged**; the three ARB labels (`breathSessionListMySessions` = "My Sessions", `breathSessionListStarredSessions` = "★ Starred", `breathSessionListSharedSessions` = "Shared Sessions") already exist. No ARB change.

#### `packages/breath_module/.../BreathSessionListViewModel.dart`

- Replace `int _currentPage = 0` with cursor-driven loading: track only a `bool _isLoading` / rely on `state.hasMore`. The opaque cursor lives in the domain notifier; the ViewModel calls `service.loadNext()` and never handles the cursor.
- `_handlePageLoaded`: first-page event → replace cells; subsequent → append. No dedup (duplicates intended).
- `loadNextPage()` → `loadNext()`: guard on `state.hasMore && !_isLoading`, call `service.loadNext()`.
- `_buildItemsWithSections(cells)` — group by `cell.section` instead of `ownership`/`isStarred`, in fixed order STARRED → MINE → SHARED, preserving arrival order within each group:
  ```dart
  final starred = cells.where((c) => c.section == ListSection.starred).toList();
  final mine    = cells.where((c) => c.section == ListSection.mine).toList();
  final shared  = cells.where((c) => c.section == ListSection.shared).toList();
  // emit SectionHeaderType.starredSessions block, then mySessions, then sharedSessions, each if non-empty
  ```
  This naturally renders the same session twice when it is tagged both STARRED and MINE/SHARED.
- `BreathSessionListState.hasMore`: derive from `nextCursor != null` carried through the events.

#### `packages/breath_module/.../BreathSessionListScreen.dart`

- Scroll trigger `_onScroll` calls `loadNext()` instead of `loadNextPage()`; gate on `hasMore`.
- `ListView.builder` itemBuilder is unchanged in structure (renders `BreathSessionListCellModel` / `SectionHeaderModel` / `SkeletonCellModel`), and already uses the list **index** as the implicit key.

### Critical gotchas (duplication-driven)

- **Never key list items by session id.** Flutter `ListView.builder` keys by index — keep it that way. If any cell/widget is given a `ValueKey(cell.id)`, two duplicated cells collide and Flutter throws "Duplicate keys". Audit the cell widgets for id-based keys before finishing (current code has none).
- **No dedup anywhere** in Notifier/ViewModel — the byId/order dedup of the old model must not be reintroduced.
- **Drift list reads are gone.** Confirm nothing else reads `BreathSessionDao.getSessions(limit, offset)` for the list. Detail/`getById` use `getSessionById` — unaffected.
- **`refresh()` must not `deleteAllSessions`.** The old `refresh` wiped the table; with duplication the entry list is not a row set, and detail/`getById` rely on cached rows. Replace-in-place via `saveSessions` (upsert) only.
- **Section blocks stay contiguous by construction** (cursor streams STARRED→MINE→SHARED), but the ViewModel re-groups by tag anyway, so out-of-order arrival is still rendered correctly.

### Sync interaction

Whatever currently triggers a breath-list refresh on a server change (sync/changelog) keeps calling `refresh(pageSize)` — its external signature is unchanged; only its internals switch to the first cursor page. No new wiring required.

### How to verify

1. Cold open the list → STARRED block first (★ Starred header), then My Sessions, then Shared Sessions; each in the server's order.
2. Star one of your **own** sessions from its detail screen (note 99) → on returning to the list it appears under ★ Starred **and** still under My Sessions (duplicated, no crash).
3. Unstar it → the ★ Starred copy disappears; the My Sessions copy remains.
4. A starred **other-user** session shows under ★ Starred **and** Shared Sessions.
5. Scroll to the bottom of a long list → next cursor page loads; no skipped or repeated rows beyond the intended section duplication; loading stops when `nextCursor` is null.
6. Create / delete a session, then scroll → no offset-drift artifacts (the keyset guarantee).
7. `flutter analyze` clean; `flutter test` green (update any list/pagination tests that referenced `page`/`total`).
