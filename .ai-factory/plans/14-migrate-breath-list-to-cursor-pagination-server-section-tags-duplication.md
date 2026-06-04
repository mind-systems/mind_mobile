# Plan: Migrate breath list to cursor pagination + server section tags + duplication

## Context
Switch the breath-session list from offset pagination (`page`/`page_size`/`total`) to opaque cursor pagination with server-provided section tags (STARRED/MINE/SHARED) and intentional duplication, so the same session can appear in multiple sections. The list renders from cursor API responses held in the Notifier (Drift stays write-through for detail/`getById` only).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Notes / Prerequisites
- Spec: `.ai-factory/notes/100-breath-list-cursor-pagination-sections.md` (background; superseded where this plan's event-flow design differs — see Design Decision below).
- Prereq 1 (DONE): `mind_api` Phase 33 proto+service merged — `../mind_api/proto/breath_sessions.proto` already exposes `cursor`/`next_cursor`/`SessionListItem`/`SessionSection`.
- Prereq 2: own-star task (note 99) so own sessions can land in STARRED. Not part of this milestone.
- **Guards (apply to every task):** NO dedup anywhere; never key list cells by `id` (duplicate ids → Flutter "Duplicate keys" crash — `ListView.builder` must stay index-keyed); `refresh()` upserts via `saveSessions`, never `deleteAllSessions`.

## Design Decision: full-entry-list snapshot flows on every change

Plan-review Issue 2 is decisive: the spec note's single-session `SessionStarred(session)` / `SessionUpdated(session)` events cannot deliver optimistic STARRED **duplication** to the UI — a single DTO carries one `section`, so the ViewModel's id-match patch collapses a multi-section session to one cell. This also silently drops a rendered copy for any legitimately multi-section session (STARRED+MINE, STARRED+SHARED) on any update until a full reload.

**Resolution (review-endorsed option 2):** the domain Notifier is the single source of truth and always holds the authoritative ordered `entries` (dup ids allowed). The concrete `BreathSessionListService` maps the **full `state.entries`** to section-tagged cell DTOs on *every* stream emission, and emits one uniform `ListUpdatedEvent { items, hasMore }`. The ViewModel rebuilds its section-grouped list from `items` on every event — it never patches a parallel cell list with single-session events. This is naturally stateless (RULES rule 1): the Service derives entirely from `notifier.stream` / `state.entries`, holding no cursor or cell cache.

Consequences this eliminates:
- No first-page-vs-append heuristic in the ViewModel (Issue 5) — the notifier appends to its own `entries`, and the snapshot always carries the full list.
- No `_currentPage` field and no scattered `_currentPage = 0` resets (Issue 4).
- Duplication (optimistic and server-sourced) always reaches the UI (Issue 2).

Domain-layer Notifier events (`PageLoaded`, `SessionsRefreshed`, `SessionCreated/Updated/Deleted/Starred`, `SessionsInvalidated`) are **kept** for semantic clarity / other domain consumers (`BreathSessionService`), but on the list path the Service treats every non-invalidate event identically: rebuild from `state.entries`.

## Tasks

### Phase 1: Proto + contract models

- [x] **Task 1: Copy proto and regenerate gRPC stubs**
  Files: `proto/breath_sessions.proto`, `lib/Core/Grpc/generated/breath_sessions.pb.dart` (generated), `lib/Core/Grpc/generated/breath_sessions.pbgrpc.dart` (generated), `lib/Core/Grpc/generated/breath_sessions.pbjson.dart` (generated)
  Copy `../mind_api/proto/breath_sessions.proto` → `proto/breath_sessions.proto` verbatim (do not hand-edit — `mind_api/proto/` is the single source of truth). Run `./scripts/gen_proto.sh`. This regenerates `ListSessionsRequest{cursor?, pageSize}`, `ListSessionsResponse{items, nextCursor}`, `SessionListItem{session, section}`, `enum SessionSection`. The old `data/total/page/pageSize` getters disappear — `BreathSessionApi.fetchAll` stops compiling (expected; fixed in Task 4).

- [x] **Task 2: Add domain section enum** (depends on Task 1)
  Files: `lib/BreathModule/Models/BreathListSection.dart`
  Add `enum BreathListSection { starred, mine, shared }`. Pure Dart, no proto import — proto `SessionSection` is mapped to this enum inside the Api wrapper (Task 4). This keeps the domain free of generated-proto dependencies.

- [x] **Task 3: Rewrite list response model** (depends on Task 2)
  Files: `lib/BreathModule/Models/BreathSessionsListResponse.dart`
  Replace `{ data, total, page, pageSize, hasMore, fromJson }` with:
  - `class BreathSessionListEntry { final BreathSession session; final BreathListSection section; const ... }`
  - `class BreathSessionsListResponse { final List<BreathSessionListEntry> entries; final String? nextCursor; const ...; bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty; }`
  Drop the `fromJson` factory (the response now comes from proto, not JSON).

### Phase 2: API + Repository

- [x] **Task 4: Switch API to cursor pagination** (depends on Task 3)
  Files: `lib/BreathModule/Core/IBreathSessionApi.dart`, `lib/BreathModule/Core/BreathSessionApi.dart`
  Replace `fetchAll(int page, int pageSize)` with `fetchPage(String? cursor, int pageSize)` in both interface and impl. Build the request: `cursor == null ? ListSessionsRequest(pageSize: n) : ListSessionsRequest(cursor: c, pageSize: n)` (first page = `cursor` left unset). Map `response.items` → `BreathSessionListEntry(session: _mapSessionWithStarred(it.session), section: _mapSection(it.section))`; set `nextCursor: response.hasNextCursor ? response.nextCursor : null`. Add private `_mapSection(proto.SessionSection)` → `BreathListSection`. Keep `_mapSessionWithStarred` (now reads `it.session`, a `BreathSessionWithStarredDto`).

- [x] **Task 5: Make repository cursor-sourced, write-through only** (depends on Task 4)
  Files: `lib/BreathModule/Core/IBreathSessionRepository.dart`, `lib/BreathModule/Core/BreathSessionRepository.dart`
  Replace the two list methods with cursor signatures returning `({List<BreathSessionListEntry> entries, String? nextCursor})`:
  - `fetch(String? cursor, int pageSize)`: call `_api.fetchPage(cursor, pageSize)`, `_dao.saveSessions(entries.map((e) => e.session).toList())` (upsert dedups in Drift, harmless), return entries + nextCursor.
  - `refresh(int pageSize)`: call `_api.fetchPage(null, pageSize)`. **Do NOT `deleteAllSessions`** — upsert via `saveSessions` only (with duplication the entry list ≠ row set, and detail/`getById` rely on cached rows).
  Drop the Drift-offset-first logic entirely. `fetchById`/`create`/`update`/`delete`/`starSession`/`deleteAll` stay unchanged. `BreathSessionDao.getSessions(limit, offset)` becomes unused by the list — leave it in place.

### Phase 3: Notifier

- [x] **Task 6: Update notifier events to entries + cursor** (depends on Task 5)
  Files: `lib/BreathModule/Core/Models/BreathSessionNotifierEvent.dart`
  `PageLoaded`: replace `{page, sessions, hasMore}` with `{List<BreathSessionListEntry> entries, String? nextCursor}`. `SessionsRefreshed`: replace `{sessions, hasMore}` with `{entries, nextCursor}`. Leave `SessionCreated/Updated/Deleted/Starred/Invalidated` unchanged (still carry a single `BreathSession` / id — the list path ignores their payload and rebuilds from state, per the Design Decision).

- [x] **Task 7: Rewrite notifier state and operations** (depends on Task 6)
  Files: `lib/BreathModule/Core/BreathSessionNotifier.dart`
  - State → `class BreathSessionsState { final List<BreathSessionListEntry> entries; final String? nextCursor; final BreathSessionNotifierEvent? lastEvent; }` (ordered, dup ids allowed; drop `byId`/`order`/`orderedSessions`).
  - Add a **synchronous** lookup helper for non-list consumers: `BreathSession? cachedById(String id) => entries.firstWhereOrNull((e) => e.session.id == id)?.session;` (place on the state class or notifier; import `package:collection` or hand-roll the scan to avoid a new dep). Used by Task 8.
  - `load(String? cursor, int pageSize)`: if `cursor == null` replace `entries` with response; else append. **No dedup.** Store `nextCursor`. Emit `PageLoaded(entries: response.entries, nextCursor:)`.
  - `refresh(int pageSize)`: replace `entries` with first-page response, store `nextCursor`, emit `SessionsRefreshed(entries, nextCursor)`.
  - `invalidate()`: emit empty `entries`, null `nextCursor`, `SessionsInvalidated`.
  - `getById(String id)`: scan `entries` for first `e.session.id == id`; if none, fall back to `repository.fetchById(id)`. (Repository method is `fetchById` — note 100 line 127's `getById` name is wrong; use `fetchById`.)
  - `starSession(id, {starred})`: call `repository.starSession` (gRPC+Drift) first, then optimistically mutate `entries`:
    - `starred == true`: set `isStarred = true` (`copyWith`) on every entry with this id; if no entry with `section == BreathListSection.starred` exists for this id, **prepend** `BreathSessionListEntry(session: <that session, isStarred=true>, section: BreathListSection.starred)`.
    - `starred == false`: **remove** every entry where `id == id && section == starred`; set `isStarred = false` on remaining entries with this id.
    - Emit `SessionStarred(updatedSession)`. (The full mutated `entries` list is what the Service reads — Task 9 — so the new STARRED entry surfaces.)
  - `create`: prepend a `BreathSessionListEntry` for the saved session (section derived: `mine`), emit `SessionCreated(saved)`.
  - `update`: replace `session` on every entry whose id matches (preserve each entry's section), emit `SessionUpdated(saved)`.
  - `delete`: remove every entry with the id, emit `SessionDeleted(id)`.
  - No id-keyed maps anywhere.

- [x] **Task 8: Fix synchronous `byId` consumer in the assembly layer** (depends on Task 7)
  Files: `lib/BreathModule/BreathModule.dart`
  `buildConstructor` (line ~64) reads `app.breathSessionNotifier.currentState.byId[sessionId]`, which no longer exists. Replace with the synchronous scan added in Task 7: `app.breathSessionNotifier.currentState.cachedById(sessionId)` (keep the existing `assert(sessionId == null || session != null, ...)`). This is the only synchronous `byId` reader; `SyncEngine` uses `invalidate()` and `BreathSessionService` uses `getById` — both preserved. Required for the `flutter analyze` gate (Task 13) to pass.

### Phase 4: Package boundary — DTOs, interface, service

- [x] **Task 9: Collapse list events to a single full-list snapshot** (depends on Task 8)
  Files: `packages/breath_module/lib/src/BreathSessionsList/IBreathSessionListService.dart`, `lib/BreathModule/BreathSessionListService.dart`

  **Package interface** (`IBreathSessionListService.dart`):
  - Replace `fetchPage(int page, int pageSize)` with `loadNext(int pageSize)` (page size passed by the ViewModel — Issue 3; the opaque cursor lives in the notifier, never crosses the boundary). Keep `refresh(int pageSize)`.
  - Replace the event hierarchy: remove `PageLoadedEvent`, `SessionsRefreshedEvent`, `SessionCreatedEvent`, `SessionUpdatedEvent`, `SessionDeletedEvent`. Add `class ListUpdatedEvent extends BreathSessionListEvent { final List<BreathSessionListItemDTO> items; final bool hasMore; ... }`. Keep `SessionsInvalidatedEvent`.

  **Concrete service** (`BreathSessionListService.dart`):
  - `observeChanges()` maps each emitted `BreathSessionsState`: if `lastEvent is SessionsInvalidated` → `SessionsInvalidatedEvent()`; if `lastEvent == null` → emit nothing; otherwise → `ListUpdatedEvent(items: _mapEntries(state.entries), hasMore: state.nextCursor != null)`. Derives entirely from `state` — no stored cursor/cell cache (RULES rule 1).
  - `loadNext(int pageSize)` → `notifier.load(notifier.currentState.nextCursor, pageSize)` (first call's `nextCursor` is null → first page). `refresh(pageSize)` → `notifier.refresh(pageSize)`.
  - `_mapEntries(List<BreathSessionListEntry>)` → `List<BreathSessionListItemDTO>`, one DTO per entry, translating `BreathListSection` → `ListSection` and tagging each DTO's `section`. Reuse the existing per-session mapping (`patterns`/`duration`/`complexity`); `_determineOwnership`/`ownership`/`isStarred` retained as cell metadata (no longer drive grouping).
  - Remove the now-dead single-session map branches.

- [x] **Task 10: Add section to package DTOs** (depends on Task 9)
  Files: `packages/breath_module/lib/src/BreathSessionsList/Models/BreathSessionListItem.dart`, `packages/breath_module/lib/src/BreathSessionsList/Models/BreathSessionListItemDTO.dart`
  In `BreathSessionListItem.dart` add `enum ListSection { starred, mine, shared }` (exported transitively via `breath_module.dart`'s existing export of this file) and add `final ListSection section;` to `BreathSessionListCellModel`. In `BreathSessionListItemDTO.dart` add `final ListSection section;`. Keep `ownership`/`isStarred`/`SessionOwnership`. `SectionHeaderType` unchanged — the three ARB labels already exist, no l10n change.

### Phase 5: ViewModel + Screen

- [x] **Task 11: Render the ViewModel from full-list snapshots** (depends on Task 10)
  Files: `packages/breath_module/lib/src/BreathSessionsList/BreathSessionListViewModel.dart`
  - Remove `int _currentPage` entirely (and every `_currentPage = 0` / increment — currently in `build`/`_loadInitialPage`/`loadNextPage`/`_handleSessionsRefreshed` line 123/`_handleSessionsInvalidated` line 74).
  - `_onEvent` now handles exactly two events: `ListUpdatedEvent` and `SessionsInvalidatedEvent`. Delete `_handlePageLoaded`/`_handleSessionsRefreshed`/`_handleSessionCreated`/`_handleSessionUpdated`/`_handleSessionDeleted` and the `_extractCellModels`/append logic.
  - `_handleListUpdated(ListUpdatedEvent e)`: `cells = _transformDTOsToModels(e.items)`; if empty → `{ items: [SkeletonCellModel(animated:false)], mode: empty, hasMore: e.hasMore }`; else → `{ items: _buildItemsWithSections(cells), mode: content, hasMore: e.hasMore }`. Always a full replace — no dedup, no append (Issues 2/4/5 resolved by design).
  - `_handleSessionsInvalidated()`: reset to `initialLoading` skeleton and call the initial load (no `_currentPage`).
  - Initial load (`build`/`_loadInitialPage`): call `service.loadNext(pageSize)` (first call → first page, cursor null in notifier). On error → empty mode.
  - `loadNextPage()` → `loadNext()`: guard `state.hasMore && !state.isPaging`; append a trailing `SkeletonCellModel(animated:true)` + set `paging` mode; call `service.loadNext(pageSize)`; on error remove the skeleton and revert to `content`. The arriving `ListUpdatedEvent` (full list) replaces items and clears the skeleton.
  - `refresh()`: set `syncing` mode, call `service.refresh(pageSize)`; on error revert to `content`.
  - `_buildItemsWithSections(cells)`: group by `cell.section` in fixed order STARRED → MINE → SHARED, preserving arrival order within each group:
    ```
    final starred = cells.where((c) => c.section == ListSection.starred).toList();
    final mine    = cells.where((c) => c.section == ListSection.mine).toList();
    final shared  = cells.where((c) => c.section == ListSection.shared).toList();
    ```
    Emit `SectionHeaderType.starredSessions` block, then `mySessions`, then `sharedSessions`, each only if non-empty. Renders a session twice when tagged both STARRED and MINE/SHARED.
  - `_dtoToCellModel`: pass `section: dto.section` into `BreathSessionListCellModel`.

- [x] **Task 12: Wire scroll trigger to loadNext** (depends on Task 11)
  Files: `packages/breath_module/lib/src/BreathSessionsList/BreathSessionListScreen.dart`
  `_onScroll` calls `loadNext()` instead of `loadNextPage()`, still gated by `state.hasMore` inside the VM. `ListView.builder` stays **index-keyed** — do not add `ValueKey(cell.id)` (duplicate ids would crash). No structural change to `itemBuilder`.

### Phase 6: Fix compilation fallout in tests

- [x] **Task 13: Update existing tests to the new contract** (depends on Task 12)
  Files: `test/BreathModule/breath_session_notifier_test.dart`, `test/BreathModule/BreathSessionRepository_test.dart`, `test/BreathModule/Presentation/BreathSessionsList/breath_session_list_sections_test.dart`
  Update fakes/assertions that reference removed symbols (`page`/`total`/`pageSize`/`data`/`byId`/`order`/`orderedSessions`/`fetchAll`/offset `fetch`/`load(int,…)`/`PageLoadedEvent`/`SessionsRefreshedEvent`/`SessionCreatedEvent`/`SessionUpdatedEvent`/`SessionDeletedEvent`). Migrate to `fetchPage(cursor, pageSize)`, entry lists, `nextCursor`, `BreathListSection`/`ListSection`, and the single `ListUpdatedEvent`. The section-grouping test must assert grouping by server `section` with intentional duplication (same id under STARRED **and** MINE/SHARED) and must assert the optimistic-star path: after `starSession(ownId, starred:true)`, the next `ListUpdatedEvent` contains the session under both STARRED and MINE. Goal: `flutter analyze` clean, `flutter test` green. Do not add new test suites — only repair existing ones broken by the migration.

## Commit Plan
- **Commit 1** (after tasks 1-3): "Add cursor-paginated breath list proto and contract models"
- **Commit 2** (after tasks 4-5): "Switch breath session API and repository to cursor pagination"
- **Commit 3** (after tasks 6-8): "Rewrite breath session notifier to section-tagged entry list"
- **Commit 4** (after tasks 9-10): "Map full breath entry list to section-tagged snapshot events"
- **Commit 5** (after tasks 11-12): "Render breath list from section-grouped snapshots, load by cursor"
- **Commit 6** (after task 13): "Update breath list tests for cursor pagination and sections"
</content>
