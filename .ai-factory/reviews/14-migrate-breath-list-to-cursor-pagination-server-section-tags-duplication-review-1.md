# Code Review: Migrate breath list to cursor pagination + server section tags + duplication

**Reviewed:** `git diff HEAD` against the plan and the live codebase.
**Scope:** proto regen, domain models, API/repository, notifier, service, package DTOs/interface, ViewModel, screen, and the three test files.

Overall the migration is well-executed and internally consistent. The full-entry-list snapshot design (Design Decision in the plan) is implemented faithfully across all layers, all removed symbols (`byId`/`order`/`orderedSessions`/`fetchAll`/`PageLoadedEvent`/etc.) are gone with no dangling references in `lib/` or `packages/`, and the guards (no dedup, index-keyed list, `refresh()` upserts instead of `deleteAllSessions`) all hold. One real correctness bug and a couple of lower-severity notes follow.

## Findings

### 1. [Medium] `starSession(starred: true)` injects a phantom blank entry when the session is not in `entries`

`lib/BreathModule/Core/BreathSessionNotifier.dart:179-192`

When `starred == true` and no entry with the given `id` exists in `state.entries`, the prepend branch's `firstWhere(..., orElse: ...)` fabricates a placeholder session and prepends a real STARRED entry built from it:

```dart
final base = updatedEntries.firstWhere(
  (e) => e.session.id == id,
  orElse: () => BreathSessionListEntry(
    session: BreathSession(id: id, userId: '', description: '', shared: false, exercises: []),
    section: BreathListSection.starred,
  ),
);
final starredEntry = BreathSessionListEntry(
  session: base.session.copyWith(isStarred: true),
  section: BreathListSection.starred,
);
updatedEntries = [starredEntry, ...updatedEntries];
```

Because the Service maps the full `entries` list to the UI on every emission, this phantom surfaces as a **blank cell under ★ Starred** (empty title, empty subtitle, `00:00` duration).

This is reachable in production. The detail screen's `BreathSessionService.starSession` (`lib/BreathModule/BreathSessionService.dart:50`) calls `notifier.starSession` directly. `entries` is not guaranteed to contain the session at that moment:
- `SyncEngine` calls `breathSessionNotifier.invalidate()` on server change, which sets `entries` to `[]`. If a sync invalidation lands while a detail screen is open and the user then taps star, the optimistic branch runs against an empty list and injects the phantom.
- Any future deep-link/notification path that opens a detail screen without the list having been loaded hits the same branch.

The old notifier explicitly no-opped this case (`final session = state.byId[id]; if (session == null) return;`). The plan's Task 7 likewise assumed the session is present in `entries` ("set `isStarred` on every entry with this id; if no entry with `section == starred` exists, prepend a new entry [for that session]") — it never asked for a synthetic session to be created.

Note the regression is masked by the test: `breath_session_notifier_test.dart:398` is titled *"no-ops silently if session not found in state"* but only asserts `completes` — it does **not** assert that no entry was added, so it passes despite the phantom being created. The same `orElse` placeholder pattern also exists in the final `updatedSession` lookup (`:210-218`); there it only feeds the event payload (ignored on the list path), so it is harmless, but it reflects the same unguarded assumption.

**Suggested fix:** when the session is absent from `entries`, skip the local mutation entirely (the server write has already succeeded) — e.g. guard the prepend on a real match and early-return otherwise — and tighten the test to assert `entries` is unchanged.

### 2. [Low] `refresh()` / `loadNext()` can strand the UI in `syncing` / `paging` mode

`packages/.../BreathSessionListViewModel.dart:95-130` + `lib/BreathModule/Core/BreathSessionNotifier.dart:72,104`

The notifier's `load`/`refresh` both early-return when `_isLoading` is true, without emitting. The ViewModel sets `syncing` (in `refresh`) or appends a skeleton and sets `paging` (in `loadNext`) *before* awaiting, and relies on the arriving `ListUpdatedEvent` to restore `content`. If the call is dropped by the `_isLoading` guard (e.g. a pull-to-refresh fires while a pagination load is mid-flight, or vice-versa), no event arrives and the mode stays `syncing`/`paging` until the next unrelated emission.

This is a pre-existing pattern (the prior code had the same `_isLoading` guard and event-driven reset), so it is not a regression introduced here, and it is hard to hit given the 200ms scroll throttle. Worth a follow-up: have the dropped call signal back so the ViewModel can revert mode, or reset mode on the `await` completing.

## Verified correct

- **Proto/codegen:** `_mapSection` (`BreathSessionApi.dart:71`) covers all three `proto.SessionSection` values with a safe `default → shared`; `response.hasNextCursor()` + `nextCursor` usage matches the generated `optional` semantics; `_mapSessionWithStarred(item.session)` consumes the correct `BreathSessionWithStarredDto`.
- **Repository:** `refresh` no longer calls `deleteAllSessions` and write-through `saveSessions` (PK-upsert) is preserved for detail/`getById`; `fetch`/`refresh` return `(entries, nextCursor)`. `getSessions(limit, offset)` left in place, unused by the list.
- **`hasMore` derivation** is consistent across `BreathSessionsListResponse.hasMore`, the notifier's stored `nextCursor`, and the Service (`nextCursor != null && isNotEmpty`). An empty-string cursor degrades to `hasMore == false`, so no infinite-scroll risk.
- **Notifier ops:** `create` prepends a `mine` entry, `update` replaces session on all id-matching entries preserving section, `delete` removes all id-matching entries — all without id-keyed maps and without dedup.
- **Service is stateless** (RULES rule 1): `observeChanges()` derives entirely from `state`; `loadNext` reads the cursor from `notifier.currentState`. No stored cursor/cell cache.
- **ViewModel** renders from full snapshots with no append/dedup; `_buildItemsWithSections` groups STARRED → MINE → SHARED, emitting a header only for non-empty groups, and renders duplicate ids correctly (confirmed by the duplication tests).
- **Screen** stays index-keyed (`ListView.builder`, no `ValueKey(cell.id)`); `_onScroll` calls `loadNext()`.
- **`BreathModule.buildConstructor`** updated to `currentState.cachedById(sessionId)` (the only synchronous `byId` reader); `SyncEngine` (`invalidate()`) and `BreathSessionService` (`getById`) unaffected. `SyncEngine.dart:114`'s `response.data` is the unrelated `BatchSessionsResponse`, not the breath list response.
- **Tests** compile against the new contract and meaningfully cover sections, duplication, within-section ordering, full-replacement, and the optimistic-star happy path. (Exception: the "session not found" no-op test under-asserts — see Finding 1.)

## Summary

One Medium correctness bug (phantom blank STARRED entry from the unguarded `starSession` `orElse`, reachable via the detail-screen star + sync-invalidation path, and hidden by an under-asserting test) and one Low pre-existing stuck-mode edge case. Everything else in the vertical is correct and consistent with the plan.
</content>
