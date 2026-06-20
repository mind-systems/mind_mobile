# Plan: Render the list from Drift (offline-first cold start; invalidate() re-reads Drift)

## Context
Make the breath session list render instantly and offline on cold start by seeding `BreathSessionNotifier` from Drift at app init and turning `invalidate()` into a Drift re-read that emits a populated list, instead of an empty state that forces a network reload.

## Design notes

- **Deliberate reversal of note 100 / Phase 34.** Note 100 decided "the list renders from cursor API responses; Drift stays write-through for detail/`getById` only." This plan intentionally adds a Drift **render** path for the list. This is a design change, not a regression — call it out in the implementation commit so future readers don't treat it as a mistake. Depends on note 131 (sections derived from columns via `buildSectionedEntries`).
- **Empty-Drift semantics (resolved — seed and invalidate differ).** The seed and the privacy-wipe have opposite needs in the empty case:
  - **Seed (`loadLocal()`)** must NOT emit when Drift is empty. The notifier's initial seeded state has `lastEvent: null`, so `observeChanges()` emits nothing on subscriber replay and the ViewModel's `initialLoading` skeleton holds until the background network load corrects it. If the seed emitted an empty `LocalSessionsLoaded`, `observeChanges()` would map it to `ListUpdatedEvent(items: [])` and the ViewModel would flash the "no sessions" empty state for the full network latency on every fresh/empty-Drift launch. Skipping the empty emission preserves the clean **skeleton → content** sequence.
  - **Invalidate (`invalidate()`)** must ALWAYS emit, even when empty — this is the privacy-wipe path (`_onUserIdChanged` → `deleteAll()` → `invalidate()`): the previous user's rows must be cleared from the visible list immediately. It is also the SyncEngine delta path, which should reflect deletions.
  - Consequence: `loadLocal()` and `invalidate()` share the read+build logic but are NOT byte-identical — the shared helper computes entries; `loadLocal()` guards on empty (return without emitting), `invalidate()` always emits. Task 3 reflects this.
- **Transient `hasMore` after a non-empty seed (benign).** `loadLocal()` preserves the current `nextCursor` (`null` on first seed), so the replayed seed event computes `hasMore = false` while the ViewModel's synchronous `build()` branch hard-codes `hasMore: true`. This oscillates true→false until the background `_loadInitialPage()` corrects it. Self-correcting and already covered by the ViewModel's existing "conservative — background load corrects it" comment.
- **Content shrink when Drift holds more than one page (accepted interim behavior, until note 133).** `localSessions()` returns the *entire* cached set, so a non-empty seed renders every accumulated row (prior pages + SyncEngine deltas). But the ViewModel's background `_loadInitialPage()` calls `load(null, pageSize)`, and the notifier's `cursor == null` branch **replaces** the entry set with just the first network page (`sessions = _uniqueSessions(result.entries)`). So for a user whose Drift cache exceeds `pageSize` (~50), the cold-start sequence is **content(N) → content(50)**: the list visibly shrinks to one page once the background load resolves. This is the price of shipping the Drift seed ahead of the network-refresh rework. **Decision: accept this for the interim.** It self-heals into a valid one-page list (paging back up on scroll) and is not a skeleton/empty flash. The proper fix — make the background load reconcile against the full seed instead of replacing it — belongs to note 133, which reworks the network refresh path. Do NOT attempt that fix here; this plan adds only the Drift read path. If product deems the shrink unacceptable, sequence note 133 to land together with this milestone.
- **`SessionsInvalidated` reload path is retired (intentional dead branch).** `invalidate()` is the only emitter of `SessionsInvalidated`; after Task 3 it emits `LocalSessionsLoaded` instead. Consequently `observeChanges()`'s `if (event is SessionsInvalidated)` branch, `SessionsInvalidatedEvent`, and the ViewModel's `_handleSessionsInvalidated()` (skeleton + network reload) all become unreachable. This is the entire point of the change (render from Drift rather than force a network reload) and causes no live regression: the only `invalidate()` caller that fires while the list is mounted is the SyncEngine **delta** path (`SyncGrpcListener` → `_processEvents`, which never reaches `_handleFullResync`), and it is strictly improved by rendering the just-saved Drift rows directly. `_handleFullResync` is reachable only from the REST `sync()` poll at app init / login, when the list is not mounted. Leave the now-dead `SessionsInvalidated` class and branches in place (Task 2) — do not delete them in this milestone — but a future reader should treat them as retired, not as a live bug.
- **`invalidate()` preserves `nextCursor` across the privacy wipe (LOW, benign).** Task 3 emits `nextCursor: _subject.value.nextCursor` (the original `invalidate()` hard-reset it to `null`). On a user switch the previous user's cursor is preserved alongside the empty entry list, so `hasMore` could briefly read `true` with zero items. Benign — the list rebuilds fresh on next open via `build()` → `_loadInitialPage()` with `cursor == null`, and entries are empty so there is no cross-user leakage. The user-change unit test still passes (that path's cursor is `null` after the single-session load). No action required; noted for completeness.

## Settings
- Testing: no (no new coverage — but existing notifier tests MUST keep compiling and passing; see Task 5)
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Repository Drift read path

- [x] **Task 1: Expose a Drift list read on the repository**
  Files: `lib/BreathModule/Core/IBreathSessionRepository.dart`, `lib/BreathModule/Core/BreathSessionRepository.dart`
  Add `Future<List<BreathSession>> localSessions()` to `IBreathSessionRepository`. Implement it in `BreathSessionRepository` by delegating to the existing (currently unused) `_dao.getSessions()` — no `limit`/`offset`, returning the full cached set ordered `createdAt` DESC. This is a pure local read: it must NOT touch `_api`. `BreathSession` is already imported in both files.

### Phase 2: Notifier event type

- [x] **Task 2: Add a local-load event type** (depends on Task 1)
  Files: `lib/BreathModule/Core/Models/BreathSessionNotifierEvent.dart`
  Add a new event `class LocalSessionsLoaded extends BreathSessionNotifierEvent {}` (no payload needed — the state already carries `entries`). It exists so `BreathSessionListService.observeChanges()` maps the re-read to a `ListUpdatedEvent` (full-list snapshot) rather than a `SessionsInvalidatedEvent`. Follow the existing sealed-class style in this file. Leave `SessionsInvalidated` in place — `observeChanges()` still references it — but `invalidate()` will no longer emit it (it becomes a retired/dead path; see Design notes).

### Phase 3: Notifier seed + invalidate re-read

- [x] **Task 3: Seed from Drift and make `invalidate()` re-read Drift** (depends on Task 2)
  Files: `lib/BreathModule/Core/BreathSessionNotifier.dart`
  - Add a private helper that does the read + build, e.g. `Future<List<BreathSessionListEntry>> _readLocalEntries()` → `buildSectionedEntries(await repository.localSessions(), currentUserId())`.
  - Add `Future<void> loadLocal()` (the seed): compute entries via the helper; **if entries are empty, return without emitting** (leave the initial `lastEvent: null` state so the skeleton holds — see Design notes). If non-empty, emit `BreathSessionsState(entries: ..., nextCursor: _subject.value.nextCursor, lastEvent: LocalSessionsLoaded())`. Preserve the current `nextCursor` (the Drift read is not paginated; don't clobber `hasMore`).
  - Change `invalidate()` to be `async` / `Future<void>` and **always emit** (even when empty): compute entries via the helper and emit `BreathSessionsState(entries: ..., nextCursor: _subject.value.nextCursor, lastEvent: LocalSessionsLoaded())`. This replaces the current empty `entries: [], lastEvent: SessionsInvalidated()` emission.
  - Keep `_onUserIdChanged → repository.deleteAll()` then `invalidate()` exactly as-is. `deleteAll()` is awaited before the now-async `invalidate()` reads `localSessions()`, so the wipe-then-read ordering holds and the re-read returns an empty list → privacy wipe still produces an empty visible list (no cross-user leakage). Callers (`SyncEngine`, `_onUserIdChanged`) treat `invalidate()` as fire-and-forget; making it `Future<void>` is fine — do not require callers to await.

### Phase 4: Wiring

- [x] **Task 4: Seed the notifier during `App.initialize()`** (depends on Task 3)
  Files: `lib/Core/App.dart`
  Immediately after `breathSessionNotifier` is constructed (line 176, before `syncEngine` / `waitForColdStart`), add `await breathSessionNotifier.loadLocal();`. This guarantees `currentState.entries` is warm before any screen builds, so the synchronous `currentItems()` read in the ViewModel hits ready data with no shimmer flash for the cached case. Keep the seed independent of the cold-start sync timeout so an offline launch still shows cached rows. Do not remove or reorder the existing `syncEngine` cold-start / background fetch — empty Drift (fresh guest) must still fall through to the network path. (This is an awaited one-shot external-wiring call, mirroring the existing `await syncEngine.waitForColdStart(...)` and `await appSettingsRepository.init()` steps; constructor self-seeding can't satisfy "warm before build" because a constructor can't await.)

### Phase 5: Keep existing tests green

- [x] **Task 5: Update the notifier test fake and the privacy-wipe assertion** (depends on Task 3)
  Files: `test/BreathModule/breath_session_notifier_test.dart`
  - **Compilation fix:** `FakeBreathSessionRepository` (line 17) `implements IBreathSessionRepository`; adding `localSessions()` to the interface makes the fake incomplete and the whole file fails to compile. Add `@override Future<List<BreathSession>> localSessions() async => List.of(_sessions);`. Returning the in-memory `_sessions` means that after `deleteAll()` (which sets `_sessions = []`) the re-read is empty, so the privacy-wipe path still yields empty entries.
  - **Assertion fix:** the test at line 546 (`'user id change calls deleteAll and emits empty entries with SessionsInvalidated'`) asserts `lastEvent` is `isA<SessionsInvalidated>()` (line 557). After Task 3, `_onUserIdChanged → invalidate()` emits `LocalSessionsLoaded`. Update the assertion to `isA<LocalSessionsLoaded>()` and rename the test accordingly (e.g. `'... emits empty entries with LocalSessionsLoaded'`). `entries isEmpty` (line 555) and `nextCursor isNull` (line 556) still hold: the fake's `localSessions()` returns the post-`deleteAll` empty list and the helper preserves the null cursor.
  - Run `flutter test test/BreathModule/breath_session_notifier_test.dart` and confirm green.

### Phase 6: Verify integration

- [x] **Task 6: Verify the list/service cold-start path** (depends on Task 4)
  Files: `lib/BreathModule/BreathSessionListService.dart`, `packages/breath_module/lib/src/BreathSessionsList/BreathSessionListViewModel.dart` (confirm exact path)
  Confirm (read-only, adjust only if needed):
  - `BreathSessionListService.currentItems()` reads `notifier.currentState.entries` (already does) — now reflects the Drift seed.
  - `observeChanges()` maps `LocalSessionsLoaded` to a `ListUpdatedEvent` via its existing "all other events → full-list snapshot" branch (no code change expected since only `SessionsInvalidated` is special-cased).
  - The ViewModel `build()` cold-start path finds a non-empty `currentItems()` and shows the list immediately for the cached case; for empty Drift the seed emits nothing, the `initialLoading` skeleton holds, and the background `_loadInitialPage()` corrects from the network. Verify the exact ViewModel path/filename, confirm no shimmer flash for the cached case and no empty-state flash for the fresh/empty case. Do not change the network refresh behaviour (reworked separately in note 133).
  - Acknowledge (do not fix here) the content-shrink-on-background-load from Design notes: when Drift holds more than `pageSize` rows the list goes content(N) → content(50) once `_loadInitialPage()` resolves. Accepted interim behavior pending note 133 — confirm it self-heals (no skeleton/empty flash, list paginates back on scroll).
