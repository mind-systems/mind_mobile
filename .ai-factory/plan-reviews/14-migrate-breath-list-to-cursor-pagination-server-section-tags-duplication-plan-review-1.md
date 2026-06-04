# Plan Review: Migrate breath list to cursor pagination + server section tags + duplication

**Plan:** `14-migrate-breath-list-to-cursor-pagination-server-section-tags-duplication.md`
**Reviewed against:** spec note 100, mind_api proto, and the live mind_mobile codebase.
**Risk Level:** 🔴 High — one guaranteed compile break (unlisted consumer of `byId`) and one architectural gap that defeats an explicit acceptance criterion (optimistic STARRED duplication never reaches the UI).

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** Aligned. The plan respects the layered boundary (domain notifier → concrete Service → package ViewModel via DTOs). The cursor stays in the domain notifier and never crosses into the package — consistent with the module-boundary rule. **WARN:** see RULES note below regarding the service staying stateless.
- **Rules (`.ai-factory/RULES.md`):** `WARN`. Rule 1 requires Module Services to be **stateless** — `observeChanges()` must derive directly from `notifier.stream.expand(...)`, no stored state. The current `BreathSessionListService` complies. The plan's Task 10 ("`loadNext()` reads `notifier.currentState.nextCursor`") keeps the cursor in the notifier, which is correct — but the plan must NOT introduce a `pageSize` field or cursor cache in the service (see Issue 3). Keep `loadNext()` reading from the notifier only.
- **Roadmap (`.ai-factory/ROADMAP.md`):** Aligned. Plan maps directly to Phase 34 line 49, which explicitly lists "optimistic STARRED mutation in `starSession`" as a requirement — this reinforces Critical Issue 2 below: the optimistic mutation is required behavior, and the plan's event wiring cannot deliver it.

## Critical Issues

### 1. Unlisted consumer of `byId` will break compilation — `BreathModule.buildConstructor`

Task 7 drops `byId`/`order`/`orderedSessions` from `BreathSessionsState`. But the plan's file lists never touch `lib/BreathModule/BreathModule.dart`, which reads:

```dart
// lib/BreathModule/BreathModule.dart:64
final session = sessionId != null
    ? app.breathSessionNotifier.currentState.byId[sessionId]
    : null;
```

After Task 7 this no longer compiles. **Add a step** (in Task 7 or Task 10's commit) to update `buildConstructor` to resolve the session from the new entry list — e.g. `currentState.entries.firstWhereOrNull((e) => e.session.id == sessionId)?.session`, or route it through the existing `notifier.getById` path. Without this the `flutter analyze` gate in Task 13 cannot pass.

(Other notifier consumers are fine: `SyncEngine` only calls `invalidate()` — preserved; `BreathSessionService` only calls `getById` — preserved.)

### 2. Optimistic STARRED duplication never reaches the UI — defeats verification step 2

This is the central design flaw. The data flow the plan describes cannot satisfy spec note 100 verification step 2 ("star your own session → it appears under ★ Starred **and** still under My Sessions") nor the roadmap's "optimistic STARRED mutation" requirement.

Trace:
1. Task 7 `starSession` prepends a new `BreathSessionListEntry(section: starred)` into the notifier's `entries` and emits `SessionStarred(updatedSession)` — a **single session**, not the entry list.
2. Task 10 maps `SessionStarred` → the package's `SessionUpdatedEvent(dto)` — a **single DTO** carrying **one** `section`.
3. The existing `BreathSessionListViewModel._handleSessionUpdated` replaces every id-matching cell with that one `updatedCell`, then `_buildItemsWithSections` groups by `cell.section`. One cell → one section.

Result: the starred own session stays only in its original section (MINE); the optimistic STARRED entry created in the notifier is **invisible** to the ViewModel because no event carries it. The duplicate only appears after a full server reload. The carefully-specified notifier prepend in Task 7 is effectively dead code under the Task 9–10 event contract.

The same root cause is a **regression** for any legitimately multi-section session: a session tagged STARRED+SHARED (starred other-user session) or STARRED+MINE that receives a `SessionUpdated` collapses to a single cell/section, dropping one of its rendered copies until reload.

**The plan must make an explicit design decision here**, e.g. one of:
- Have `starSession` (and `update`/`create` where duplication matters) emit an event carrying the **full entry list** (like `PageLoaded`/`SessionsRefreshed`), so the ViewModel rebuilds its section-grouped list from the authoritative entries; or
- Redesign the ViewModel to render directly from the notifier's `entries` rather than maintaining a parallel cell list patched by single-session events.

As written, Tasks 7 and 9–11 are internally inconsistent: Task 7 implements optimistic duplication that Tasks 9–11 provide no channel to surface.

## Non-Blocking Issues

### 3. `loadNext()` has no `pageSize` source (Task 9 / Task 10)

Task 9 changes the interface from `fetchPage(int page, int pageSize)` to `loadNext()` with no args, but `notifier.load(cursor, pageSize)` and `api.fetchPage(cursor, pageSize)` still need a page size. `refresh(int pageSize)` keeps it; `loadNext()` loses it. Specify where `loadNext()` gets the size. To honor RULES rule 1 (stateless service), prefer a `const`/injected-at-construction value rather than service-held mutable state, or pass it from the ViewModel's `pageSize` field through a still-parameterized `loadNext(pageSize)`. The plan should name the source explicitly.

### 4. `_currentPage` removal touches more handlers than Task 11 lists

Task 11 says to remove `int _currentPage`, but `_currentPage = 0` is also assigned in `_handleSessionsRefreshed` (VM line 123) and `_handleSessionsInvalidated` (line 74), and read/incremented in `loadNextPage` and `_loadInitialPage`. Removing the field requires editing all of these. This is within Task 11's file but the task body only mentions `_loadInitialPage`/`loadNextPage`/`_handlePageLoaded` — call out the refresh/invalidate handlers so the implementer doesn't leave dangling references.

### 5. First-vs-append heuristic is workable but fragile (Task 11)

Replacing `event.page == 0` with "current items contain no real cells → first page, else append" works given the current flow (initial state is skeleton-only; pagination always has real cells present, plus `loadNextPage` appends a skeleton before awaiting). It is acceptable, but it is an implicit invariant — note it explicitly so a future refactor that pre-populates cells doesn't silently turn a first-page load into an append. A cleaner alternative: the service/notifier already knows `cursor == null` means first page; consider surfacing an `isFirstPage`/`replace` bool on `PageLoadedEvent` instead of inferring it in the VM.

### 6. Spec note 100 line 127 references `repository.getById` — the real method is `fetchById`

Minor: the plan's Task 7 correctly says `repository.fetchById(id)` (matching `IBreathSessionRepository`/`BreathSessionRepository`). The authoritative spec note has the wrong name. The plan is right; no action needed beyond keeping `fetchById`.

## Verified Correct

- **Proto contract is genuinely merged.** `mind_api/proto/breath_sessions.proto` already exposes `optional string cursor` (tag 1), `optional string next_cursor`, `repeated SessionListItem items`, `SessionListItem{session, section}`, and `enum SessionSection { STARRED, MINE, SHARED }`. The mobile proto still has the old offset shape, so Task 1's copy + `./scripts/gen_proto.sh` is the right first step. `gen_proto.sh` exists.
- **proto3 `optional` handling is correct.** `cursor == null ? ListSessionsRequest(pageSize:n) : ListSessionsRequest(cursor:c, pageSize:n)` and `response.hasNextCursor ? response.nextCursor : null` match generated-Dart semantics for `optional` fields.
- **`_mapSessionWithStarred(it.session)`** — `it.session` is `BreathSessionWithStarredDto`, the exact type the existing helper consumes. Correct.
- **`refresh()` must not `deleteAllSessions`** — current `refresh` does `deleteAllSessions` then `saveSessions` (Repository lines 27–29); the plan correctly removes the wipe and relies on PK-upsert. Good catch, and consistent with detail/`getById` still needing cached rows.
- **Drift `getSessions(limit, offset)` left in place** — confirmed only the repository list path consumes it; leaving it unused is harmless.
- **ListView index-keying guard** — confirmed `BreathSessionListScreen` uses index-based `itemBuilder` with no `ValueKey(cell.id)`; the "never key by id" guard is already satisfied and Task 12 correctly preserves it.
- **l10n** — `breathSessionListMySessions`/`...StarredSessions`/`...SharedSessions` are all already used in the screen; no ARB change needed, as the plan states.
- **Section order** — plan's STARRED→MINE→SHARED matches spec note 100 line 8 (the current code's MINE→STARRED→SHARED order is correctly being changed).
- **All three test files referenced by Task 13 exist.**

## Summary

The mechanical migration (proto → models → API → repository → state shape) is well-researched and largely correct; the guards (no dedup, index keys, no `deleteAllSessions`) are sound and verified against the code. Two things block approval:

1. **Compile break** — `BreathModule.buildConstructor` reads `byId` and is not in any task. Must be added.
2. **Architectural gap** — the optimistic STARRED duplication required by the spec and roadmap cannot flow through the single-session `SessionStarred`/`SessionUpdated` event contract; the plan needs an explicit event/rendering decision so duplicated entries actually reach the ViewModel.

Address Issues 1 and 2 (and clarify 3–4) and the plan is ready.
