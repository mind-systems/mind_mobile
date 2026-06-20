# Plan Review: Online refresh = write-through-then-reread; UI never holds the server cursor

**Plan:** `67-online-refresh-write-through-then-reread-ui-never-holds-the-server-cursor.md`
**Risk Level:** 🟢 Low
**Verdict:** Solid — proceed. Findings below are advisory (test-fidelity clarifications + one defensive guard), not blocking.

## Verification performed

Read every targeted file and cross-checked the plan's assumptions against the codebase:

- `BreathSessionNotifier.dart`, `BreathSessionNotifierEvent.dart` — confirmed `nextCursor` field, `PageLoaded`, `load()`, `_readLocalEntries()`, and all `_subject.add` call sites match the plan's description exactly.
- `BreathSessionRepository.dart`, `IBreathSessionRepository.dart` — confirmed `refresh`/`fetch` shapes and that `refresh` already does write-through upsert (no `deleteAllSessions`).
- `IBreathSessionApi.fetchPage` + `BreathSessionsListResponse` — confirmed cursor/`nextCursor`/`hasMore` wire contract (left unchanged, correct).
- `BreathSessionListService.dart`, `IBreathSessionListService.dart` — confirmed `observeChanges` reads `state.nextCursor` and `loadNext` reads `notifier.currentState.nextCursor`.
- `BreathSessionListViewModel.dart`, `BreathSessionListState.dart`, `BreathSessionListScreen.dart` — confirmed `_loadInitialPage`, `loadNext` guard (`!state.hasMore` early-return), `hasMore` usage, and `_onScroll → loadNext()`.
- Both test files — confirmed exactly which removed symbols they reference.

**Consumer coverage is complete.** A repo-wide grep for `nextCursor` / `.load(` / `.fetch(` / `PageLoaded` shows no `lib/` or `packages/` consumer of the removed symbols outside the files the plan already lists. `BreathSessionApi.dart` and `BreathSessionsListResponse.dart` keep `nextCursor` (proto/wire side) and are correctly left untouched. The service's `observeChanges` handles `SessionsRefreshed`/`PageLoaded` via the generic else-branch (it never reads `event.entries`/`event.nextCursor`), so deleting `PageLoaded` and dropping `SessionsRefreshed.nextCursor` is safe.

## Context Gates

- **Architecture / RULES.md — PASS.** RULES requires Module Services stay stateless and forbids module state in `App.dart`. The plan keeps `BreathSessionListService` stateless (`observeChanges` remains a derived `notifier.stream.expand(...)`; `loadNext` becomes a no-op) and touches no `App.dart` wiring. `App.dart:177` only calls `loadLocal()`, which the plan leaves intact (it correctly lists `loadLocal`/`invalidate` among the `nextCursor` removal sites).
- **ROADMAP.md — PASS (linked).** Maps 1:1 to the open Phase 46 milestone "Online refresh = write-through-then-reread; UI never holds the server cursor" and to research note `133`. Guards in the plan (no proto change, no offset-Drift UI pagination, keep write-through, failure must not wipe Drift render) match the milestone's stated guards.

## Critical Issues

None.

## Recommendations (non-blocking)

1. **Treat Tasks 1–3 as one atomic edit (compile ordering).** `load()` references `PageLoaded`, `result.nextCursor`, and `SessionsRefreshed(nextCursor: ...)`. Task 1 deletes those symbols while Task 2 deletes `load()`. The notifier will not compile between Task 1 and Task 2 in isolation. This is fine for delivery (Commit 1 groups tasks 1–3), but the implementer should apply the notifier/event/repository changes together rather than expecting a green build after Task 1 alone. Worth stating explicitly in the plan.

2. **Add an empty-page break to the repository refresh loop (defensive).** Task 3 stops "when `nextCursor` is null/empty." If the server ever returns a non-empty `nextCursor` alongside an empty `entries` page (bug/edge), the loop spins forever. Recommend also breaking when a page returns `entries.isEmpty`. Cheap insurance.

3. **Task 6 under-specifies two tests whose *meaning* changes (not just compile):**
   - `breath_session_notifier_test.dart` → `refresh()` group → `'replaces state with fresh page'` asserts `cachedById('a')` is `null` after seeding `[x]` and refreshing. The new `refresh` is **additive upsert + re-read of the full Drift mirror** — it no longer "replaces." Against the real repository `'a'` would persist. This assertion must be inverted/removed, and the fake's `refresh`/`localSessions` should model upsert-not-replace (the current fake's `seed()` wholesale-replaces `_sessions`, which would encode misleading "replace" semantics even though the code compiles). The notifier's new `refresh` re-reads via `repository.localSessions()`, so tests should drive population by seeding `_sessions` and asserting the re-read result + `SessionsRefreshed`.
   - `BreathSessionRepository_test.dart` → `refresh` group → `'returns entries from first page'` asserts on `result.entries.length`, but `refresh` now returns `Future<void>`. Rewrite to assert DAO contents instead (ideally also assert the loop drains all pages via the existing offset-based `FakeBreathSessionApi.fetchPage`). Delete the `fetch` group (4 tests) wholesale since `fetch` is removed.

   The plan's blanket instruction ("update these tests so the suite compiles and reflects the new contract") does cover this, but naming these two specifically will prevent a mechanical "make it compile" pass that leaves a semantically wrong assertion in place.

## Positive Notes

- The failure-path design is the key correctness win and is specified correctly: `refresh` rethrows (the existing try/finally already propagates), and `_loadInitialPage` only falls back to empty when still in `initialLoading`, otherwise leaves the Drift render standing. This directly satisfies the note-133 guard "an offline/failed refresh must NOT clear the Drift-rendered list."
- Correctly recognizes that DAO rows are unique by id, so re-reading via `_readLocalEntries()` (which skips `_uniqueSessions`) is sound — the dedup-on-append branch only existed for the multi-page accumulate path that is being removed.
- `loadNext` is neutralized at both layers (service no-op + ViewModel `!hasMore` guard) and the screen scroll listener needs no change — good defense in depth.
- Proto / `ListSessions` / `IBreathSessionApi.fetchPage` correctly left untouched; the cursor is confined to the repository loop variable exactly as the milestone requires.

PLAN_REVIEW_PASS
