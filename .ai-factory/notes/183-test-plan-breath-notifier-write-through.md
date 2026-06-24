# BreathSessionNotifier — Write-Through Refresh & Drift Seed — Test Plan

**Date:** 2026-06-24
**Source:** roadmap-test-coverage agent

## Source Overview

**File:** `lib/BreathModule/Core/BreathSessionNotifier.dart`

Core responsibilities:
1. **Instantiation & Drift Seed** — constructor seeds `BehaviorSubject` from `repository.localSessions()` via `buildSectionedEntries()`
2. **Refresh as Write-Through** — `refresh(pageSize)` loops `ListSessions` (cursor=null → nextCursor until null) → `saveSessions()` into Drift → re-reads Drift → emits `SessionsRefreshed`
3. **Section Derivation** — `buildSectionedEntries(List<BreathSession>, currentUserId)` emits MINE/SHARED + STARRED duplicate entries, sorted `createdAt` DESC
4. **Invalidate Re-read** — `invalidate()` re-reads Drift and emits a populated state with `LocalSessionsLoaded` event

**Key Methods:**
- `buildSectionedEntries()` — pure function, derives sectioned entries from flat session list and current user ID
- `_readLocalEntries()` — reads `repository.localSessions()` and builds sectioned entries
- `loadLocal()` — seeded call during `App.initialize()` (Drift cold-start path)
- `invalidate()` — re-reads Drift (SyncEngine-driven path)
- `refresh(pageSize)` — loops all server pages → write-through → re-read Drift → emit

## Instantiation

**Current behavior (lines 78–94):**
- `BehaviorSubject` is seeded with `entries: []` (empty initial state)
- No Drift read happens in the constructor
- Auth stream subscription wired for user-change detection

**Phase 46 changes:**
- Caller (`App.initialize()`) is responsible for **awaiting `loadLocal()`** to seed Drift data before any screen builds
- The notifier's initial state is empty, but `loadLocal()` must be called synchronously (settled before the first screen build)

## Existing Coverage

**File:** `test/BreathModule/breath_session_notifier_test.dart`

### `refresh()` group (lines 118–205)

| Test | What it covers | New path? | Old path? |
|------|---|---|---|
| `populates state from local sessions after refresh` | calls `repo.refresh()` → re-reads Drift → emits entries | ✅ **NEW** | ❌ |
| `replaces state with fresh sessions` | old state is wiped by new Drift read | ✅ **NEW** | ❌ |
| `emits SessionsRefreshed event` | correct event type after write-through | ✅ **NEW** | ❌ |
| `concurrent refresh() — second call ignored` | `_isLoading` flag prevents re-entrancy | ✅ Both | ✅ Both |
| `starred session yields both MINE and STARRED entries` | `buildSectionedEntries()` creates duplicates | ✅ **NEW** | ❌ |
| `updates existing entries on re-refresh` | Drift upsert + re-read reflects changes | ✅ **NEW** | ❌ |

**Summary:** The refresh() tests assume the fake repository's `localSessions()` returns the sessions that `refresh()` would have written. They do NOT explicitly test the **cursor loop** or **write-through → re-read** flow; they trust that the repository's `refresh()` is the detail (covered in `BreathSessionRepository_test.dart`).

**What's tested for cursor-loop pagination:**
- `BreathSessionRepository_test.dart` group `refresh()` lines 202–255 covers:
  - First page called with `cursor=null` ✅
  - Pages loop until `nextCursor=null` ✅
  - Multiple pages are upserted into DAO ✅

**Coverage Gap:** The notifier's `refresh()` does NOT directly test:
1. Pagination loop integration (notifier awaiting all pages from repository)
2. Drift upsert during each page (repository concern, but notifier should emit after completion)
3. Write-through Drift isolation (old entries before refresh, new entries after)
4. Re-read Drift and emit in one atomic state update

## Test Cases

### Group: Drift Seed at Instantiation (`loadLocal()`)

**Test 1: "should populate state from Drift on loadLocal() call"**
- **Method:** `loadLocal()`
- **Setup:**
  ```dart
  final repo = FakeBreathSessionRepository();
  repo.seed([_session('a'), _session('b')]);
  final notifier = BreathSessionNotifier(
    repository: repo,
    authStream: authSubject.stream,
    currentUserId: () => 'user-1',
  );
  await notifier.loadLocal();
  ```
- **Assertion:** `notifier.currentState.entries` contains entries for 'a' and 'b' in `createdAt` DESC order
- **Why:** Ensures cold-start Drift seed populates the notifier before first screen build

**Test 2: "should emit LocalSessionsLoaded event after loadLocal()"**
- **Method:** `loadLocal()`
- **Setup:** (same as Test 1)
- **Assertion:** `notifier.currentState.lastEvent` is `LocalSessionsLoaded`
- **Why:** Notifier broadcasts that the load is complete (used by observers like SyncEngine)

**Test 3: "should return early silently if Drift is empty on loadLocal()"**
- **Method:** `loadLocal()`
- **Setup:** Repository seeded with `[]`; no prior state emissions
- **Assertion:** State remains seeded empty; no event emitted
- **Why:** Fresh install case; should not block; background refresh will populate

### Group: Refresh as Write-Through Cursor Loop

**Test 4: "should loop all pages from API into Drift during refresh()"**
- **Method:** `refresh(pageSize)`
- **Setup:**
  ```dart
  final repo = FakeBreathSessionRepository();
  // Seed repository so fetchPage() simulates 15 sessions on 2 pages (page size 10)
  repo.seed([_session('s1'), ..., _session('s15')]);
  await notifier.refresh(10);
  ```
- **Assertion:** Repository's `fetchCallCount == 2` (first page + second page); `fetchCallCount` is captured in the fake API
- **Why:** Verifies the notifier delegates pagination to the repository (and the repository's loop is covered in `BreathSessionRepository_test.dart`)

**Test 5: "should not store cursor on notifier state during refresh()"**
- **Method:** `refresh(pageSize)`
- **Setup:** (same as Test 4)
- **Assertion:** `notifier.currentState` has no `nextCursor` or `cursor` field; entries are fully populated
- **Why:** Cursor is a local loop variable, never exposed to the UI layer

**Test 6: "should re-read Drift after refresh() completes and emit re-read entries"**
- **Method:** `refresh(pageSize)`
- **Setup:**
  ```dart
  final repo = FakeBreathSessionRepository();
  repo.seed([_session('old')]);
  await notifier.refresh(10);
  
  // Now replace the API seed (simulating server refresh)
  repo.seed([_session('new')]);
  await notifier.refresh(10);
  ```
- **Assertion:** After second refresh, `notifier.currentState.entries` contains only 'new'; 'old' is gone
- **Why:** Drift re-read happens AFTER write-through, so stale entries are replaced; verifies the re-read path

### Group: Section Derivation (`buildSectionedEntries()`)

**Test 7: "should emit MINE entry for session owned by current user"**
- **Method:** `refresh()` (or directly call `buildSectionedEntries()`)
- **Setup:**
  ```dart
  final session = _session('a', userId: 'user-1');
  repo.seed([session]);
  await notifier.refresh(10);
  ```
- **Assertion:** Entry exists with `section == BreathListSection.mine`
- **Why:** Ownership derivation from `userId` column

**Test 8: "should emit SHARED entry for session owned by another user"**
- **Method:** `refresh()`
- **Setup:**
  ```dart
  final session = _session('a', userId: 'other-user');
  repo.seed([session]);
  await notifier.refresh(10);
  ```
- **Assertion:** Entry exists with `section == BreathListSection.shared`
- **Why:** Alternate ownership derivation

**Test 9: "should emit STARRED entry as duplicate for starred sessions"**
- **Method:** `refresh()`
- **Setup:**
  ```dart
  final session = _session('a', userId: 'user-1', isStarred: true);
  repo.seed([session]);
  await notifier.refresh(10);
  ```
- **Assertion:**
  - Entry with `section == BreathListSection.mine` exists
  - Entry with `section == BreathListSection.starred` exists (same session ID)
  - Total entry count is 2
- **Why:** Star duplication is a render concern; Drift stores one row, emit two list entries

**Test 10: "should sort entries by createdAt DESC within their natural order"**
- **Method:** `refresh()`
- **Setup:**
  ```dart
  repo.seed([
    _session('a', createdAt: DateTime(2020)),
    _session('b', createdAt: DateTime(2025)),
    _session('c', createdAt: DateTime(2022)),
  ]);
  await notifier.refresh(10);
  ```
- **Assertion:** Entry order is ['b', 'c', 'a'] (DESC by createdAt)
- **Why:** Matches `BreathSessionDao.getSessions()` ordering; ensures consistent sort across refresh loops

**Test 11: "should deterministically break createdAt ties by id ASC"**
- **Method:** `refresh()`
- **Setup:**
  ```dart
  final now = DateTime.now();
  repo.seed([
    _session('z', createdAt: now),
    _session('a', createdAt: now),
  ]);
  await notifier.refresh(10);
  ```
- **Assertion:** Entry order is ['a', 'z'] (after tying on createdAt, sorted by id ASC)
- **Why:** Deterministic render; prevents flakiness when sessions share createdAt

**Test 12: "should mix MINE, SHARED, and STARRED in single list sorted by time"**
- **Method:** `refresh()`
- **Setup:**
  ```dart
  repo.seed([
    _session('own1', userId: 'user-1', createdAt: DateTime(2025), isStarred: true),
    _session('shared1', userId: 'other-user', createdAt: DateTime(2024)),
    _session('own2', userId: 'user-1', createdAt: DateTime(2023)),
  ]);
  await notifier.refresh(10);
  ```
- **Assertion:** Entries appear in time order: own1 (MINE + STARRED) → shared1 (SHARED) → own2 (MINE); grouped downstream by ViewModel
- **Why:** The notifier emits a flat sorted list; grouping into sections is a ViewModel concern

### Group: Invalidate Re-read

**Test 13: "should re-read Drift on invalidate() call"**
- **Method:** `invalidate()`
- **Setup:**
  ```dart
  repo.seed([_session('initial')]);
  await notifier.refresh(10);
  
  // Simulate server sync delta: update the session
  repo.seed([_session('initial').copyWith(description: 'updated')]);
  await notifier.invalidate();
  ```
- **Assertion:** `notifier.currentState.cachedById('initial')!.description == 'updated'`
- **Why:** Invalidate re-reads the Drift state (populated by SyncEngine deltas)

**Test 14: "should emit LocalSessionsLoaded on invalidate()"**
- **Method:** `invalidate()`
- **Setup:** (same as Test 13)
- **Assertion:** `notifier.currentState.lastEvent` is `LocalSessionsLoaded`
- **Why:** Observers (SyncEngine, ViewModel) treat it as a "list updated" signal, not "list cleared"

**Test 15: "should show empty list on invalidate() if Drift is empty"**
- **Method:** `invalidate()`
- **Setup:**
  ```dart
  repo.seed([_session('a')]);
  await notifier.refresh(10);
  
  // Simulate deleteAll (user change)
  repo.seed([]);
  await notifier.invalidate();
  ```
- **Assertion:** `notifier.currentState.entries.isEmpty`
- **Why:** Privacy: never leak user A's cached sessions to user B

### Group: Write-Through → Re-Read Atomicity

**Test 16: "should not emit intermediate state during refresh()"**
- **Method:** `refresh(pageSize)` (observe stream)
- **Setup:**
  ```dart
  final states = <BreathSessionsState>[];
  notifier.stream.listen(states.add);
  repo.seed([_session('a'), ..., _session('n')]);
  await notifier.refresh(10);
  ```
- **Assertion:** Only one state emission during refresh (the final re-read); no intermediate partial states
- **Why:** Ensures no UI flicker or intermediate re-renders from partial Drift updates

**Test 17: "should emit SessionsRefreshed event (not partial events) after refresh()"**
- **Method:** `refresh(pageSize)`
- **Setup:** (same as Test 16)
- **Assertion:** All emitted states during refresh have `lastEvent` of type `SessionsRefreshed` (or none if no change)
- **Why:** Service/ViewModel observes the event type; must be consistent

### Group: Existing Behavior Preserved

**Test 18: "should handle CRUD (create, update, delete, star) alongside refresh()"**
- **Method:** `create()`, `update()`, `delete()`, `starSession()` after `refresh()`
- **Setup:**
  ```dart
  repo.seed([_session('a')]);
  await notifier.refresh(10);
  
  await notifier.create(_session('new'));
  await notifier.update(_session('a').copyWith(description: 'changed'));
  await notifier.starSession('a', starred: true);
  await notifier.delete('a');
  ```
- **Assertion:** State transitions are correct per existing tests; no collision with refresh paths
- **Why:** Refresh is a background operation; CRUD must not race it or corrupt state

## Gotchas

1. **FakeBreathSessionRepository does NOT implement cursor pagination** — the test passes a list and the fake API simulates pages via offset. To test the notifier's cursor loop behavior, either:
   - Enhance FakeBreathSessionApi to return multiple pages with `nextCursor` (see `BreathSessionRepository_test.dart` fake for the pattern)
   - Or trust that `BreathSessionRepository_test.dart` covers the cursor loop and only test that the notifier consumes the result correctly

2. **`buildSectionedEntries()` is pure and sync** — can be tested independently of the notifier, but the tests above exercise it via the notifier's public API (refresh, invalidate, CRUD). If you want isolated unit tests for the builder, create a separate `buildSectionedEntries()` test group.

3. **No explicit "Drift persistence" test** — the notifier tests assume the fake repository's `localSessions()` returns what was seeded. To verify the actual Drift write-through path, you need integration tests with a real `BreathSessionDao`. The unit tests here are notifier-level, not Drift-level.

4. **Empty Drift on first `loadLocal()`** — the test must verify that `loadLocal()` on a fresh app (empty Drift) returns early without blocking. Test 3 covers this, but ensure the notifier does NOT fail or emit an error.

5. **Cursor is never in `BreathSessionsState`** — grep the notifier for any `cursor`, `nextCursor`, or `hasMore` fields. If they still exist from the old implementation, they must be removed or relocated (the state must only have `entries` + `lastEvent`).

6. **`invalidate()` vs `refresh()`** — both read Drift, but `invalidate()` is typically called by SyncEngine (sync deltas populate Drift first), while `refresh()` loops the server API. Tests should not mix them — e.g., calling both in sequence without changing the fake data will emit two identical states.

7. **Re-read Drift after write-through** — the notifier calls `repository.refresh()` which fills Drift, then calls `_readLocalEntries()` to re-read. If the repository's `refresh()` is a no-op (as it is in the current test fake), then `_readLocalEntries()` must still work correctly and re-read whatever is currently in Drift. The fake repository's `refresh()` is intentionally a no-op; the Drift writes are simulated via `repo.seed()`.

8. **Starred sessions in both MINE and STARRED** — the builder ensures one owned session appears in both MINE (or SHARED) and STARRED. Tests 9 and existing `refresh()` test (line 171–190) cover this, but verify that the ViewModel's grouping logic (downstream) correctly de-duplicates by ID when rendering by section.

---

**Ready to implement:** These test cases should fully specify the new write-through + Drift-seed behavior without duplicating coverage from `BreathSessionRepository_test.dart`. Start with tests 1–6 (seed + refresh), then 7–12 (sections), 13–15 (invalidate), 16–17 (atomicity), and 18+ (integration).
