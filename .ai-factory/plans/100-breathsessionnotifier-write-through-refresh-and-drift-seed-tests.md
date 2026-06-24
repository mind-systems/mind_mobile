# Test Plan: BreathSessionNotifier write-through refresh and Drift-seed tests

## Context
`BreathSessionNotifier` (`lib/BreathModule/Core/BreathSessionNotifier.dart`) is the domain source of truth for breathing sessions. After the Phase 46 rewrite, `refresh()` is a write-through full-mirror sync: it delegates pagination to `repository.refresh(pageSize)`, then re-reads the local Drift mirror via `repository.localSessions()` and emits the derived sectioned list. The existing `refresh()` group tests the happy path but does not cover the cold-start Drift seed (`loadLocal()`), the delegation contract of `refresh()`, the `invalidate()` re-read path, or the full section-derivation matrix. This plan extends the existing spec file with those groups.

**Scope boundary (do not violate):** the cursor-loop page mechanics (two-page `ListSessions` → upsert each page → `saveSessions` called twice) live *inside* the repository, not the notifier. `IBreathSessionRepository.refresh(pageSize)` returns `void` and is opaque to the notifier. That loop is already covered by `test/BreathModule/BreathSessionRepository_test.dart` — do NOT duplicate it here. At the notifier level, "pagination" is verified only as *delegation*: that `refresh()` calls `repository.refresh(pageSize)` exactly once per invocation, forwards the page size, awaits it, and then re-reads Drift.

## Settings
- Testing: yes
- Logging: minimal
- Docs: no

## Test Command
`/usr/local/bin/flutter test test/BreathModule/breath_session_notifier_test.dart`

## Target Spec File
`test/BreathModule/breath_session_notifier_test.dart`

## Tasks

### Phase 1: Test-fake instrumentation (prerequisite for Phase 3)

- [x] **Task 1: Extend `FakeBreathSessionRepository` with delegation counters**
  Files: `test/BreathModule/breath_session_notifier_test.dart`
  This is a fake-instrumentation task, not a `describe`/`group` block. The existing fake's `refresh(int pageSize)` is a no-op (line 28); the notifier re-reads `localSessions()` after it returns. To verify the notifier's delegation contract without testing the fake itself, add to the fake:
  - `int refreshCallCount` — incremented on each `refresh()` call.
  - `List<int> refreshPageSizes` — records each `pageSize` argument received.
  Keep `refresh()` otherwise a no-op (seeded `_sessions` is returned directly by `localSessions()`). Do NOT add an internal `ListSessions`/`saveSessions` loop to the fake — that would be testing the fake, not the notifier (see Context scope boundary). Reuse existing `_make()`, `_session()`, and `_entryIds()` helpers for all tasks below.

### Phase 2: Cold-start Drift seed — `loadLocal()`

- [x] **Task 2: `loadLocal()` — Drift seed at construction**
  Files: `test/BreathModule/breath_session_notifier_test.dart`
  New `group('loadLocal()')`. Grounded in source lines 107–114 (`loadLocal()` reads `_readLocalEntries()`, returns early if empty, else emits `LocalSessionsLoaded`). The notifier's seeded state is empty at construction (line 78–80); `loadLocal()` is the cold-start populate path.
  Test cases:
  - `should leave entries empty before loadLocal() is called when Drift has data` — seed repo, construct notifier, assert `currentState.entries` is empty *before* awaiting `loadLocal()` (constructor does no Drift read).
  - `should populate entries from Drift after loadLocal()` — seed two sessions, `await loadLocal()`, assert entries non-empty and contain both ids.
  - `should emit LocalSessionsLoaded event after loadLocal() with non-empty Drift` — assert `currentState.lastEvent` is `isA<LocalSessionsLoaded>()`.
  - `should return early without emitting when Drift is empty` — seed `[]`, `await loadLocal()`, assert `currentState.entries` stays empty and `lastEvent` is still `null` (no emission; line 109 early return).

### Phase 3: Refresh as write-through delegation

- [x] **Task 3: `refresh()` — delegation to repository**
  Files: `test/BreathModule/breath_session_notifier_test.dart`
  Extend the existing `group('refresh()')` (or add `group('refresh() — write-through delegation')`). Grounded in source lines 133–149 (`refresh()` guards on `_isLoading`, awaits `repository.refresh(pageSize)`, re-reads Drift, emits `SessionsRefreshed`). Uses the counters from Task 1.
  Test cases:
  - `should call repository.refresh exactly once per refresh()` — seed one session, `await refresh(10)`, assert `repo.refreshCallCount == 1`.
  - `should forward the page size to repository.refresh` — `await refresh(25)`, assert `repo.refreshPageSizes` equals `[25]`.
  - `should re-read Drift after repository.refresh completes and replace stale entries` — seed `['old']`, `refresh(10)`; re-seed `['new']`, `refresh(10)`; assert entries are exactly `['new']` and `cachedById('old')` is null (re-read happens AFTER write-through, line 140).
  - `should not run a second refresh() while one is in flight` — call `refresh(10)` twice without awaiting the first, `Future.wait` both, assert `repo.refreshCallCount == 1` (the `_isLoading` guard, line 134 — second call returns early).

### Phase 4: Invalidate re-read — `invalidate()`

- [x] **Task 4: `invalidate()` — re-read without network**
  Files: `test/BreathModule/breath_session_notifier_test.dart`
  New `group('invalidate()')`. Grounded in source lines 116–122 (`invalidate()` re-reads `_readLocalEntries()` and ALWAYS emits `LocalSessionsLoaded`, even when empty — unlike `loadLocal()`). Models the SyncEngine-delta path: Drift is updated externally, then `invalidate()` re-reads it.
  Test cases:
  - `should re-read updated Drift state on invalidate() without calling repository.refresh` — seed `['initial']`, `refresh(10)`; re-seed with `_session('initial').copyWith(description: 'updated')`; record `refreshCallCount`; `await invalidate()`; assert `cachedById('initial')!.description == 'updated'` AND `refreshCallCount` did not increase (no network call).
  - `should emit LocalSessionsLoaded event on invalidate()` — after the above, assert `currentState.lastEvent` is `isA<LocalSessionsLoaded>()` (line 120).
  - `should emit empty entries on invalidate() when Drift is empty` — seed `['a']`, `refresh(10)`; re-seed `[]`; `await invalidate()`; assert `currentState.entries.isEmpty` (privacy: cleared Drift must clear state; `invalidate()` emits even when empty).

### Phase 5: Section derivation — `buildSectionedEntries()` via the public API

- [x] **Task 5: section derivation — ownership (MINE / SHARED)**
  Files: `test/BreathModule/breath_session_notifier_test.dart`
  New `group('section derivation')`. Grounded in source lines 35–53. Exercise the builder through `refresh()` (its public entry point). `_session()` defaults `userId` to `'user-1'`, which equals `_make()`'s `currentUserId`, so a default session resolves to MINE; pass an explicit foreign `userId` for SHARED.
  Test cases:
  - `should emit a MINE entry for a session owned by the current user` — seed `_session('a')` (owned), `refresh(10)`, assert an entry exists with `section == BreathListSection.mine` (line 46).
  - `should emit a SHARED entry for a session owned by another user` — seed `_session('a', userId: 'other-user')`, `refresh(10)`, assert an entry exists with `section == BreathListSection.shared`.
  - `should emit no STARRED entry for an unstarred session` — seed `_session('a')` (default `isStarred: false`), `refresh(10)`, assert no entry has `section == BreathListSection.starred` and total entry count is 1.

- [x] **Task 6: section derivation — STARRED duplicate**
  Files: `test/BreathModule/breath_session_notifier_test.dart`
  Same `group('section derivation')`. Grounded in source lines 48–50 (a starred session yields its ownership entry PLUS a STARRED duplicate with the same session id).
  Test cases:
  - `should emit both MINE and STARRED entries for a starred owned session` — seed `_session('a', isStarred: true)`, `refresh(10)`, assert exactly one entry with `section == mine` and exactly one with `section == starred`, both for id `'a'`; total entry count is 2.
  - `should emit both SHARED and STARRED entries for a starred shared session` — seed `_session('a', userId: 'other-user', isStarred: true)`, `refresh(10)`, assert one `shared` entry and one `starred` entry for id `'a'`.

- [x] **Task 7: section derivation — sort order and tie-breaker**
  Files: `test/BreathModule/breath_session_notifier_test.dart`
  Same `group('section derivation')`. Grounded in source lines 37–41 (sort by `createdAt` DESC, tie-break by `id` ASC). Note: `BreathSession.createdAt` defaults to epoch `0` when omitted, so sort tests MUST pass explicit `createdAt` values to be meaningful.
  Test cases:
  - `should order entries by createdAt DESC` — seed three sessions with `createdAt` `DateTime(2020)`, `DateTime(2025)`, `DateTime(2022)` for ids `a`, `b`, `c`; `refresh(10)`; assert `_entryIds` order is `['b', 'c', 'a']`.
  - `should break createdAt ties by id ASC` — seed two sessions with the SAME explicit `createdAt` for ids `'z'` and `'a'`; `refresh(10)`; assert order is `['a', 'z']` (line 40 secondary sort). Use a fixed literal `DateTime`, not `DateTime.now()`, for determinism.
  - `should keep the STARRED duplicate adjacent to its ownership entry in the sorted stream` — seed one starred owned session with the newest `createdAt` among several; `refresh(10)`; assert both its `mine` and `starred` entries are present (grouping into visual sections is a downstream ViewModel concern — the notifier emits a single flat sorted list).
