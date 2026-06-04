# Code Review (pass 3): Migrate breath list to cursor pagination + server section tags + duplication

**Reviewed:** `git diff HEAD` against the plan and the live codebase. This pass verifies the fixes for the findings from passes 1 and 2 and does a final holistic correctness check.

## Status of prior findings

### Review 1, Finding 1 — phantom blank STARRED entry — RESOLVED ✓
`BreathSessionNotifier.starSession` early-returns when the id is absent from `entries` (`:163`); the synthetic `orElse` placeholder is gone. Test `breath_session_notifier_test.dart:425` ("no-ops silently … no phantom entry added") asserts the entry count is unchanged.

### Review 2, Finding 1 — `StateError` on unstar of a starred-only entry — RESOLVED ✓
`BreathSessionNotifier.dart:166-224`. The fix captures `source` before any mutation (`:167`, guaranteed non-throwing by the `:163` guard) and the final payload lookup now uses `orElse` falling back to `source.copyWith(isStarred: starred)` (`:216-224`). When the unstar filter removes the only loaded (STARRED) copy, the method completes, emits `SessionStarred`, and the session correctly drops out of the loaded list (it re-syncs on the next load/refresh, where its MINE/SHARED copy is fetched).

New regression test `breath_session_notifier_test.dart:388` ("unstar starred-only entry completes without throwing and removes the entry") exercises exactly this path via the new `FakeBreathSessionRepository.sectionForFetch` field (`:22`, wired into `fetch`/`refresh` at `:40`/`:51`), asserting `completes`, that no entry for the id remains, and that `SessionStarred` is emitted. Correct and well-targeted.

## Final correctness check (full diff)

- **Star path (`starred: true`)** — sets `isStarred` on all id-matching entries and prepends a STARRED copy only when none exists; `firstWhere` at `:191` is safe (guard guarantees a match; star path never removes entries). The `source` capture is also valid here.
- **Notifier `load`/`refresh`/`create`/`update`/`delete`** — unchanged since pass 1; append-without-dedup, full-replace on first page/refresh, prepend-`mine` on create, section-preserving update, remove-all-by-id on delete. No id-keyed maps.
- **API/repository** — `_mapSection` safe `default → shared`, `hasNextCursor()`/`nextCursor` correct; `refresh` upserts without `deleteAllSessions`; write-through preserved for detail/`getById`.
- **Service** — stateless; `observeChanges` maps full `state.entries` to a single `ListUpdatedEvent`; `loadNext` reads the cursor from the notifier.
- **ViewModel/Screen** — full-snapshot rebuild, STARRED→MINE→SHARED grouping with duplication, index-keyed `ListView.builder` (no `ValueKey(id)`), `_onScroll → loadNext()`.
- **`BreathModule.buildConstructor`** — uses `cachedById`; no remaining `byId`/`order`/`orderedSessions` references anywhere in `lib/` or `packages/`.
- **Tests** — all three files compile against the new contract and cover sections, duplication, ordering, full-replacement, both star edge cases, and the no-phantom invariant.

## Non-blocking note (pre-existing, not introduced by this change)

`refresh()`/`loadNext()` rely on an incoming `ListUpdatedEvent` to clear `syncing`/`paging` mode; if the notifier's `_isLoading` guard drops a concurrent call, the mode can briefly persist until the next emission. This is the same event-driven pattern as before the migration and is hard to hit given the 200ms scroll throttle — worth a future tidy-up but not a blocker for this work.

## Summary

Both findings from the prior passes are fixed correctly and backed by targeted regression tests. The full change set is internally consistent and free of new correctness or security issues.

REVIEW_PASS
</content>
