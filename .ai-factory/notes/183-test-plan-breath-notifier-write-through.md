# BreathSessionNotifier — Write-Through Refresh & Drift Seed — Test Plan

**Date:** 2026-06-24
**Source:** roadmap-test-coverage agent

## Source Overview

**File:** `lib/BreathModule/Core/BreathSessionNotifier.dart` (lines 74–231)

Core responsibilities:
1. **Instantiation & Drift Seed** — constructor (lines 85–94) seeds `BehaviorSubject` with empty state; caller awaits `loadLocal()` to populate from Drift
2. **Refresh as Write-Through** — `refresh(int pageSize)` (lines 133–149) calls `repository.refresh(pageSize)` → re-reads Drift via `_readLocalEntries()` → emits `SessionsRefreshed`
3. **Section Derivation** — `buildSectionedEntries(List<BreathSession> sessions, String currentUserId)` (lines 35–53, standalone function) emits MINE/SHARED + STARRED duplicate entries, sorted `createdAt` DESC with deterministic tie-breaker on `id` ASC
4. **Invalidate Re-read** — `invalidate()` (lines 116–122) re-reads Drift and emits state with `LocalSessionsLoaded` event

**Key Methods:**
- `buildSectionedEntries(List<BreathSession> sessions, String currentUserId)` — standalone function (lines 35–53), derives sectioned entries; returns `List<BreathSessionListEntry>`
- `_readLocalEntries()` — async method (lines 102–105), reads `repository.localSessions()` → calls `buildSectionedEntries()` → returns `Future<List<BreathSessionListEntry>>`
- `loadLocal()` — async method (lines 107–114), calls `_readLocalEntries()` → emits state with `LocalSessionsLoaded` if entries non-empty; returns `Future<void>`
- `invalidate()` — async method (lines 116–122), calls `_readLocalEntries()` → emits state with `LocalSessionsLoaded`; returns `Future<void>`
- `refresh(int pageSize)` — async method (lines 133–149), calls `repository.refresh(pageSize)` → re-reads Drift → emits with `SessionsRefreshed` event; returns `Future<void>`

## Instantiation

**Constructor signature (lines 85–94):**
```dart
BreathSessionNotifier({
  required IBreathSessionRepository repository,
  required Stream<AuthState> authStream,
  required String Function() currentUserId,
})
```

**Current behavior:**
- `BehaviorSubject<BreathSessionsState>` is seeded with `entries: []` and `lastEvent: null` (line 78)
- No Drift read happens in the constructor
- Auth stream subscription wired for user-change detection (lines 90–94)

**Phase 46 contract:**
- Caller (`App.initialize()`) is responsible for **awaiting `loadLocal()`** to seed Drift data before any screen builds
- The notifier's initial state is empty; `loadLocal()` must be called and settled before the first screen build

## Existing Coverage

**File:** `test/BreathModule/breath_session_notifier_test.dart` (501 lines total)

### `refresh()` group (lines 118–205, 6 tests)

| Test | What it covers | Lines |
|------|---|---|
| `populates state from local sessions after refresh` | calls `repo.refresh()` → re-reads Drift → emits entries | 119–129 |
| `replaces state with fresh sessions` | old state is wiped by new Drift read | 131–144 |
| `emits SessionsRefreshed event` | correct event type; verify `notifier.currentState.lastEvent` is `SessionsRefreshed()` | 146–155 |
| `concurrent refresh() — second call ignored while first in flight` | `_isLoading` flag prevents re-entrancy; both futures await same result | 157–169 |
| `starred session yields both MINE and STARRED entries after refresh` | `buildSectionedEntries()` creates duplicates; both `BreathListSection.mine` and `BreathListSection.starred` present for starred session | 171–190 |
| `updates existing entries on re-refresh` | Drift upsert + re-read reflects field changes (e.g., description) | 192–204 |

**Summary:** Tests use `FakeBreathSessionRepository` (lines 16–66) with `seed()` method (line 20). They do NOT test the **cursor loop pagination**; that's covered in `BreathSessionRepository_test.dart`. The notifier tests verify that `refresh()` awaits `repository.refresh(pageSize)`, then re-reads Drift via `_readLocalEntries()` and emits the result.

**Cursor-loop pagination (repository concern, not tested in notifier suite):**
- `BreathSessionRepository_test.dart` (separate file) covers pagination details.
- Notifier trusts that `repository.refresh(pageSize)` is a complete write-through operation.

**Coverage validated:**
1. ✅ `refresh()` awaits `repository.refresh(pageSize)` to completion
2. ✅ After `refresh()`, `_readLocalEntries()` re-reads Drift
3. ✅ State emission is atomic: one `SessionsRefreshed` per `refresh()` call
4. ✅ `_isLoading` flag prevents concurrent `refresh()` calls (line 134–147)

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
- **Verified in source (lines 38–40):**
  ```dart
  ..sort((a, b) {
    final c = b.createdAt.compareTo(a.createdAt);  // DESC
    return c != 0 ? c : a.id.compareTo(b.id);      // ASC tie-breaker
  });
  ```
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
- **Method:** `refresh(pageSize)` (observe `stream` getter, line 124)
- **Setup:**
  ```dart
  final states = <BreathSessionsState>[];
  notifier.stream.listen(states.add);
  repo.seed([_session('a'), ..., _session('n')]);
  await notifier.refresh(10);
  ```
- **Assertion:** Only one state emission during `refresh()`; only the final re-read (line 142–145) emits
- **Verified in source:** `refresh()` has no intermediate state updates; single `_subject.add()` after re-read (lines 142–145)
- **Why:** Ensures no UI flicker or intermediate re-renders from partial Drift updates

**Test 17: "should emit SessionsRefreshed event (not partial events) after refresh()"**
- **Method:** `refresh(pageSize)`
- **Setup:** (same as Test 16)
- **Assertion:** `notifier.currentState.lastEvent` is `SessionsRefreshed()` (line 144)
- **Verified in source:** `refresh()` emits `SessionsRefreshed()` at line 144
- **Why:** Consumers (ViewModel, SyncEngine) observe event type to distinguish refresh from CRUD or invalidate

### Group: Existing Behavior Preserved (CRUD tests already exist)

**Existing test groups:** `create()` (lines 207–266), `update()` (lines 268–307), `delete()` (lines 309–337), `starSession()` (lines 339–415)

**Test 18: "should handle CRUD (create, update, delete, star) alongside refresh()"** (optional advanced test)
- **Method:** `create()`, `update()`, `delete()`, `starSession()` interleaved with `refresh()`
- **Setup:**
  ```dart
  repo.seed([_session('a')]);
  await notifier.refresh(10);
  
  await notifier.create(_session('new'));
  await notifier.update(_session('a').copyWith(description: 'changed'));
  await notifier.starSession('a', starred: true);
  await notifier.delete('a');
  ```
- **Assertion:** State transitions follow CRUD logic (lines 153–217); no collision with refresh paths
- **Why:** Refresh is a background operation; CRUD must not race it or corrupt state. This is a regression test for concurrent mutation.

## Gotchas

1. **FakeBreathSessionRepository has no pagination** — `refresh()` is a no-op (line 28); the fake seeded state is returned directly by `localSessions()` (line 65). To test the notifier's pagination integration, trust that `BreathSessionRepository_test.dart` covers cursor loops. The notifier tests verify that `refresh()` awaits `repository.refresh()` and re-reads Drift.

2. **`buildSectionedEntries()` is a standalone pure function (lines 35–53)** — not a method on the notifier. Can be tested independently via direct calls or via the notifier's public API (refresh, invalidate, CRUD). Existing tests exercise it indirectly; isolated unit tests for the builder function are optional.

3. **`BreathSessionsState` structure (lines 12–29):**
   - `entries: List<BreathSessionListEntry>` — never `List<BreathSession>` (entries are derived with section metadata)
   - `lastEvent: BreathSessionNotifierEvent?` — event type distinguishes refresh vs. CRUD vs. invalidate
   - No cursor, pagination, or server state stored in the notifier state

4. **Empty Drift on first `loadLocal()`** — when `localSessions()` returns `[]`, `loadLocal()` returns early without emitting (line 109). Test 3 must verify this silent no-op behavior.

5. **BreathListSection enum values are lowercase (line 1 of Models/BreathListSection.dart):**
   - `starred` (not `STARRED`)
   - `mine` (not `MINE`)
   - `shared` (not `SHARED`)

6. **`invalidate()` vs `refresh()` — different purposes, same Drift read:**
   - `invalidate()` (lines 116–122) — called by SyncEngine after deltas populate Drift; emits `LocalSessionsLoaded`
   - `refresh()` (lines 133–149) — called by pull-to-refresh or startup; loops API → writes Drift → emits `SessionsRefreshed`
   - Tests must not mix them in a single scenario; test them separately

7. **Starred duplicate logic (lines 44–50 of buildSectionedEntries()):**
   - One session → one MINE/SHARED entry + one STARRED entry (if `isStarred=true`)
   - Example: starred owned session emits 2 entries with same session ID; different sections
   - Verified in test "starred session yields both MINE and STARRED entries" (lines 171–190)

8. **Event type matching in assertions:**
   - Use `isA<SessionsRefreshed>()` not string comparison
   - Use `isA<LocalSessionsLoaded>()` similarly
   - Event is nullable (`lastEvent: BreathSessionNotifierEvent?`); only check after state emission

---

**Ready to implement:** These test cases should fully specify the new write-through + Drift-seed behavior without duplicating coverage from `BreathSessionRepository_test.dart`. Start with tests 1–6 (seed + refresh), then 7–12 (sections), 13–15 (invalidate), 16–17 (atomicity), and 18+ (integration).
