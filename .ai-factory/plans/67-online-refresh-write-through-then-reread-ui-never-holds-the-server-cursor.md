# Plan: Online refresh = write-through-then-reread; UI never holds the server cursor

## Context
Make the breath session list fully offline-first: `refresh` becomes a write-through full-mirror sync (loop `ListSessions` into Drift, then re-read Drift and emit), and the opaque server cursor is confined to the refresh loop — it is removed from `BreathSessionsState`, the service, and the ViewModel so the UI renders only from Drift. `ListSessions` and the proto stay unchanged.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Domain — cursor-free state and events

- [x] **Task 1: Drop `nextCursor` from domain state and events**
  Files: `lib/BreathModule/Core/BreathSessionNotifier.dart`, `lib/BreathModule/Core/Models/BreathSessionNotifierEvent.dart`
  Remove the `nextCursor` field from `BreathSessionsState` (constructor, `BehaviorSubject.seeded` default, and every `_subject.add(...)` call site in `loadLocal`, `invalidate`, `create`, `update`, `starSession`, `delete`). In `BreathSessionNotifierEvent.dart`, delete the `PageLoaded` event entirely (the `load` path is removed in Task 2) and drop the `nextCursor` field from `SessionsRefreshed` (keep only `entries`, or make it parameterless since the render now comes from the Drift re-read). The cursor must not survive anywhere on notifier state or events — it lives only as a local loop variable inside the refresh (Task 2/3).

- [x] **Task 2: Rework `refresh` to loop → write-through → re-read Drift; remove `load`** (depends on Task 1)
  Files: `lib/BreathModule/Core/BreathSessionNotifier.dart`
  Replace `load(cursor, pageSize)` (delete it) and rewrite `refresh(pageSize)`:
  - Call `repository.refresh(pageSize)` which now performs the full `ListSessions` page loop and write-through into Drift (Task 3). The notifier no longer threads any cursor.
  - After the repository call returns, re-read the local mirror via the existing `_readLocalEntries()` (`repository.localSessions()` → `buildSectionedEntries`) and emit a `SessionsRefreshed` event with those entries.
  - Failure path: if the repository call throws (offline / partial network failure), **do not emit an empty/cleared state** — rethrow so the caller (ViewModel) can surface an error while the existing Drift-rendered list stands. Keep the `_isLoading` guard and `finally` reset.
  - Keep `_uniqueSessions`/`buildSectionedEntries` helpers; the dedup-on-append branch from the old `load` is gone (full mirror is always re-read fresh from Drift).

### Phase 2: Repository — own the page loop

- [x] **Task 3: Move the `ListSessions` page loop + write-through into the repository; remove `fetch`** (depends on Task 2)
  Files: `lib/BreathModule/Core/BreathSessionRepository.dart`, `lib/BreathModule/Core/IBreathSessionRepository.dart`
  Rewrite `refresh(int pageSize)`:
  - Loop: start `cursor = null`, repeatedly call `_api.fetchPage(cursor, pageSize)`, `_dao.saveSessions(...)` each page (upsert — never `deleteAllSessions`, matching today's write-through), set `cursor = response.nextCursor`, stop when `nextCursor` is null/empty.
  - Change the signature to no longer return UI-render-bound data — return `Future<void>` (the notifier re-reads Drift itself). Update `IBreathSessionRepository.refresh` accordingly.
  - Delete the `fetch(cursor, pageSize)` method and remove it from `IBreathSessionRepository` (no offset/cursor Drift-UI pagination is reintroduced).
  - Leave `IBreathSessionApi.fetchPage(cursor, pageSize)` and the proto UNCHANGED — it remains the wire call consumed inside this loop.
  - Keep `localSessions`, `fetchById`, `create`, `update`, `delete`, `starSession`, `deleteAll` write-through behavior intact.

### Phase 3: Module boundary — service and ViewModel render from the full Drift mirror

- [x] **Task 4: Service — full mirror (`hasMore=false`), `loadNext` stub, cursor-free `observeChanges`** (depends on Task 2)
  Files: `lib/BreathModule/BreathSessionListService.dart`, `packages/breath_module/lib/src/BreathSessionsList/IBreathSessionListService.dart`
  - In `observeChanges`, emit `ListUpdatedEvent(items: ..., hasMore: false)` — the full Drift mirror is always complete; remove the `state.nextCursor`-based `hasMore` computation.
  - `loadNext(pageSize)`: make it a no-op (or route it to `notifier.refresh(pageSize)` as a background write-through). It must no longer read `notifier.currentState.nextCursor` (that field is gone). Prefer a no-op since `hasMore=false` already prevents scroll pagination.
  - `refresh(pageSize)`: keep delegating to `notifier.refresh(pageSize)`.
  - Update the interface doc comments in `IBreathSessionListService.dart` to describe `loadNext` as a no-op/local stub and `refresh` as a write-through full mirror; the `BreathSessionListEvent`/`ListUpdatedEvent`/`SessionsInvalidatedEvent` types are unchanged.

- [x] **Task 5: ViewModel — remove cursor pagination; background write-through refresh that preserves the Drift render on failure** (depends on Task 4)
  Files: `packages/breath_module/lib/src/BreathSessionsList/BreathSessionListViewModel.dart`, `packages/breath_module/lib/src/BreathSessionsList/Models/BreathSessionListState.dart`
  - `_loadInitialPage()`: call the write-through `service.refresh(pageSize)` (background) instead of `loadNext`. On failure, **do not wipe the rendered list** — call `onErrorEvent?.call(SessionListError.loadFailed)` and only fall back to the empty state when the list is still in `initialLoading` (Drift produced nothing); if content is already rendered from Drift, leave `state` untouched.
  - In `build()` and `_handleListUpdated`, set `hasMore: false` (full mirror). The `initialLoading` skeleton state is still shown when `currentItems()` is empty at build time.
  - `loadNext()`: keep it guarded so it is a no-op (the `!state.hasMore` early-return already covers this with `hasMore=false`); it no longer drives server pagination. The screen's scroll listener (`BreathSessionListScreen._onScroll → loadNext()`) needs no change.
  - `refresh()` (pull-to-refresh) already only mutates `mode` on error and preserves items — leave that intact.
  - `BreathSessionListState`: keep the `hasMore` field for compatibility but it is always `false` now; no structural change required unless trivially simplifying.

### Phase 4: Keep the existing test suite compiling

- [x] **Task 6: Update existing tests that reference removed symbols** (depends on Task 3, Task 5)
  Files: `test/BreathModule/breath_session_notifier_test.dart`, `test/BreathModule/BreathSessionRepository_test.dart`
  The refactor removes public API the suite currently uses (`notifier.load`, `BreathSessionsState.nextCursor`, `PageLoaded`, `repository.fetch`, the fake repo's cursor returns). Update these tests so the suite compiles and reflects the new contract: drive population through `refresh`, assert `SessionsRefreshed` + re-read-from-Drift behavior, align the fake `IBreathSessionRepository`/`IBreathSessionDao` with the new `refresh(): Future<void>` + page-loop signature, and remove `load`/`PageLoaded`/`nextCursor` assertions. No new feature test coverage beyond keeping the suite green.

## Commit Plan
- **Commit 1** (after tasks 1-3): "Confine breath list server cursor to a write-through refresh loop"
- **Commit 2** (after tasks 4-5): "Render breath list from full Drift mirror, cursor-free UI"
- **Commit 3** (after task 6): "Update breath session list tests for cursor-free refresh"
