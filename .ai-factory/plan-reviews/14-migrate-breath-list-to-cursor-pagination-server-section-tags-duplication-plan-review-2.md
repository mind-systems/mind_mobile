# Plan Review 2: Migrate breath list to cursor pagination + server section tags + duplication

**Plan:** `14-migrate-breath-list-to-cursor-pagination-server-section-tags-duplication.md`
**Reviewed against:** plan-review-1, spec note 100, `mind_api/proto/breath_sessions.proto`, and the live `mind_mobile` codebase.
**Risk Level:** 🟢 Low — both blocking issues from review 1 are resolved; remaining items are non-blocking robustness/clarity notes.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** Aligned. The cursor stays in the domain notifier and never crosses the package boundary (`loadNext(int pageSize)` reads `notifier.currentState.nextCursor` internally). The Design Decision keeps the domain notifier as the single source of truth and derives DTOs in the concrete Service — consistent with the module-boundary rule.
- **Rules (`.ai-factory/RULES.md`):** Aligned. The revised Task 9 makes `observeChanges()` derive entirely from `state` (no stored cursor/cell cache), satisfying rule 1 (stateless Module Service). Review 1's WARN on `loadNext()` holding service state is resolved — `pageSize` is passed from the ViewModel, the cursor lives in the notifier.
- **Roadmap (`.ai-factory/ROADMAP.md`):** Aligned. The "optimistic STARRED mutation in `starSession`" requirement (Phase 34) is now actually deliverable to the UI via the full-list snapshot event (see Resolved Issue 2).

## Review 1 Blockers — Resolution Verification

### ✅ Issue 1 (byId compile break) — RESOLVED
Task 8 explicitly updates `BreathModule.buildConstructor`. Verified `lib/BreathModule/BreathModule.dart:64` reads `currentState.byId[sessionId]`; the plan's `cachedById(sessionId)` synchronous-scan replacement is correct. I swept all `byId`/`order`/`orderedSessions` readers:
- `BreathModule.buildConstructor` → Task 8 ✓
- `BreathSessionService` uses `notifier.getById` (async) → preserved by Task 7 ✓
- `SyncEngine` uses only `invalidate()` → preserved ✓
No other synchronous `byId` reader exists. The compile break is fully covered.

### ✅ Issue 2 (optimistic STARRED duplication never reaches UI) — RESOLVED
The new **Design Decision** section is the correct fix. By collapsing every list-path emission to a single `ListUpdatedEvent { items, hasMore }` rebuilt from the full `state.entries`, the optimistic STARRED entry prepended in `starSession` (Task 7) now flows to the ViewModel, which re-groups by `cell.section`. This also fixes the latent regression for legitimately multi-section sessions (STARRED+MINE / STARRED+SHARED). The design is internally consistent: Tasks 7 → 9 → 11 now agree on the data path.

### ✅ Issues 3–6 — RESOLVED
- 3 (`loadNext` pageSize source): now `loadNext(int pageSize)` with the size passed from the VM. ✓
- 4 (`_currentPage` scattered resets): Task 11 calls out every site (lines 74/123, `_loadInitialPage`/`loadNextPage`) and removes the field entirely. ✓
- 5 (first-vs-append heuristic): eliminated by design — full snapshot replace, no append logic. ✓
- 6 (`fetchById` vs `getById`): plan uses `fetchById`. ✓

## Missed-Consumer Sweep (the failure mode of review 1)

I grepped every consumer of the symbols this migration removes. All are covered:
- `BreathSessionsListResponse` / `.data` / `.total` / `fetchAll`: only `BreathSessionApi` (Task 4), `BreathSessionRepository` (Task 5), the model itself (Task 3), and `BreathSessionRepository_test.dart` (Task 13). ✓
- `SyncEngine.dart:114` `response.data` is from `syncApi.fetchSessionsBatch` (a **different** batch response type), **not** `BreathSessionsListResponse` — no conflict. Confirmed false alarm.
- `notifier.load(int,…)`: `BreathSessionListService` (Task 9) + `breath_session_notifier_test.dart` (Task 13). ✓
- `service.fetchPage`: VM (Task 11), screen `loadNextPage` (Task 12), `breath_session_list_sections_test.dart` (Task 13). ✓
- `repository.fetch`: only the notifier (Task 7). ✓

No unlisted consumer will break compilation. `ListSection` is transitively exported via `breath_module.dart`'s existing export of `BreathSessionListItem.dart` (Task 10's claim verified).

## Non-Blocking Notes

### N1. Preserve `nextCursor` on CRUD emissions (Task 7)
`create`/`update`/`delete`/`starSession` mutate `entries` but must carry the existing `nextCursor` forward into the new `BreathSessionsState`. Because `ListUpdatedEvent.hasMore` is derived as `state.nextCursor != null` (Task 9), constructing a CRUD state that drops `nextCursor` would silently flip `hasMore` to false and freeze pagination after any create/star/delete. The obvious "copy state, mutate entries" implementation handles this, but the plan should state it explicitly since these handlers previously carried `order` rather than a cursor.

### N2. `_FakeService` interface-method rename in the sections test (Task 13)
`test/.../breath_session_list_sections_test.dart` `_FakeService` implements `IBreathSessionListService.fetchPage(int page, int pageSize)`. After Task 9 the interface method is `loadNext(int pageSize)`, so the fake's override and its `PageLoadedEvent(page:…)` emissions both change to `loadNext` + `ListUpdatedEvent(items:…, hasMore:…)`. Task 13's symbol list emphasizes event/data symbols but doesn't name the `fetchPage`→`loadNext` override rename; `flutter analyze` will catch it, but calling it out avoids churn. Also note `_makeDTO` must gain a `section: ListSection.…` argument.

### N3. `_isLoading` early-return can strand the paging skeleton (pre-existing)
`notifier.load` guards with `if (_isLoading) return;` and emits no event on early return. If a scroll triggers `loadNext()` while the initial load is still in flight, the VM appends a paging skeleton and sets `paging` mode, but the awaited call returns with no `ListUpdatedEvent`, leaving the skeleton and `isPaging` stuck. This is pre-existing behavior (the current `load`/`fetchPage` has the same guard) and low-probability, but the snapshot redesign doesn't change it. Optional hardening: have `load` still emit (or have the VM clear the skeleton on a no-op completion). Not required for this milestone.

### N4. `update` may clear the star icon on a STARRED-tagged entry (pre-existing, cosmetic)
`ReplaceSession`/`CreateSession` return `BreathSessionDto` (no `is_starred`), so `_mapSession` defaults `isStarred:false`. Task 7's `update` replaces the session on every matching entry, which would set `isStarred=false` on a STARRED-section copy. Grouping is unaffected (it keys on `section`, not `isStarred`), so the only effect is the star glyph briefly disappearing until reload. Pre-existing and out of scope; flagging only so it isn't mistaken for a new regression during QA.

## Verified Correct

- **Proto contract is merged and matches the plan.** `mind_api/proto/breath_sessions.proto` exposes `optional string cursor` (tag 1), `optional string next_cursor`, `repeated SessionListItem items`, `SessionListItem{session, section}`, `enum SessionSection { STARRED, MINE, SHARED }`. Mobile proto still has the old offset shape → Task 1's copy + `./scripts/gen_proto.sh` is the correct first step.
- **proto3 `optional` handling** — `cursor == null ? ListSessionsRequest(pageSize:n) : ListSessionsRequest(cursor:c, pageSize:n)` and `response.hasNextCursor ? response.nextCursor : null` match generated-Dart semantics.
- **`_mapSessionWithStarred(it.session)`** — `it.session` is `BreathSessionWithStarredDto`, the type the existing helper consumes. Correct.
- **`refresh()` no longer `deleteAllSessions`** — verified current `refresh` (Repository:27-29) wipes then saves; the plan correctly removes the wipe (duplication means entry list ≠ row set; detail/`getById` need cached rows).
- **`observeChanges` seeded-state safety** — the seeded initial state has `lastEvent == null`, and Task 9 emits nothing for it, so no spurious event fires before the first `loadNext`.
- **Section order** STARRED→MINE→SHARED matches spec note 100 and the proto enum; the current MINE→STARRED→SHARED order is correctly changed.
- **Index-keyed `ListView`** — `BreathSessionListScreen` builds by index with `isLastInSection` computed positionally; no `ValueKey(cell.id)`. The "never key by id" guard holds, and Task 12 preserves it.
- **All three Task 13 test files exist** and reference exactly the symbols the migration removes.

## Summary

The two blockers that made review 1 High-risk are both resolved, and the new full-list-snapshot Design Decision is the right architectural call — it makes optimistic duplication deliverable while keeping the Service stateless (RULES rule 1). My independent missed-consumer sweep found no additional compile breaks; the SyncEngine `response.data` is an unrelated batch type. The four remaining notes are non-blocking (N1 is the most worth incorporating — explicitly preserve `nextCursor` on CRUD emissions). The plan is ready to implement.

PLAN_REVIEW_PASS
