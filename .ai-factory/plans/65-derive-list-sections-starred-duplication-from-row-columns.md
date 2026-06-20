# Plan: Derive list sections + starred duplication from row columns

## Context
Replace trust in the server-assigned `BreathSessionListEntry.section` with a local, pure builder that derives MINE / SHARED / STARRED sections (incl. the starred duplicate) from `BreathSession` columns inside `BreathSessionNotifier`. Behaviour-equivalent and still network-fed; lays the foundation for the later Drift-render path (note 131/132).

## Settings
- Testing: yes (only to keep the existing notifier test target compiling/green — no new feature coverage required)
- Logging: minimal
- Docs: no (one targeted snippet fix only — see Task 7)

## Tasks

### Phase 1: Local user-id source + section builder

- [x] **Task 1: Inject a current-user-id source into the notifier**
  Files: `lib/BreathModule/Core/BreathSessionNotifier.dart`, `lib/Core/App.dart`
  Add `required String Function() currentUserId` to the `BreathSessionNotifier` constructor and store it as a field. Keep the existing `authStream` subscription and `_onUserIdChanged` invalidation untouched — this getter is only for synchronously reading the active user id when building entries. In `App.dart` (the `BreathSessionNotifier(...)` construction at line 176, after `userNotifier` is created on line 175), pass `currentUserId: () => userNotifier.currentUser.id`. Keep the notifier pure Dart — no Flutter/Riverpod imports.
  > Adding a `required` param breaks both notifier test constructor sites — Task 6 updates them. All tasks land in one commit so the repo never goes red.

- [x] **Task 2: Add the pure section builder + order-independent unique-session helper** (depends on Task 1)
  Files: `lib/BreathModule/Core/BreathSessionNotifier.dart`
  Add a pure builder `List<BreathSessionListEntry> buildSectionedEntries(List<BreathSession> sessions, String currentUserId)` (static or top-level — no instance state) that:
  - Sorts a copy of the input by `createdAt` DESC, with a **deterministic secondary tie-breaker on `id`** (Dart's `List.sort` is not stable, and the epoch-0 default `createdAt` is shared by many sessions — without a tie-breaker both production and test ordering are undefined). Suggested comparator: `final c = b.createdAt.compareTo(a.createdAt); return c != 0 ? c : a.id.compareTo(b.id);`.
  - For each session emits one ownership entry: `BreathListSection.mine` if `session.userId == currentUserId`, else `BreathListSection.shared`.
  - Additionally emits a `BreathListSection.starred` **duplicate** entry for every session with `isStarred == true`.
  - Emits the entries in a fixed, deterministic order so that, after the downstream `_buildItemsWithSections` groups by section, each section is in `createdAt` DESC (then `id`) order.

  Also add a private helper `List<BreathSession> _uniqueSessions(List<BreathSessionListEntry> entries)` that de-duplicates entries by `session.id`. **Do not blindly keep the first occurrence** — the server emits a session id twice for a starred session (a STARRED entry + a MINE/SHARED entry), and the MINE/SHARED duplicate is not guaranteed to carry `isStarred == true` (confirmed by the ViewModel fixtures in `breath_session_list_sections_test.dart`). Make the helper **order-independent**: collapse duplicates by id and set the surviving session's `isStarred` to `true` if **any** duplicate of that id is starred (OR the flag), keeping all other fields from the first occurrence. This prevents starred sessions from silently dropping out of the STARRED section if the server ever emits the duplicates in a different order.

  Do NOT modify `BreathListSection`, the Drift schema, the proto, or `BreathSessionListViewModel._buildItemsWithSections`.

### Phase 2: Route entry construction through the builder

- [x] **Task 3: Build `load`/`refresh` entries via the builder** (depends on Task 2)
  Files: `lib/BreathModule/Core/BreathSessionNotifier.dart`
  In `load`: derive the flat session list and call `buildSectionedEntries(sessions, currentUserId())`. For `cursor == null`, `sessions = _uniqueSessions(result.entries)`. For append, `sessions = _uniqueSessions([...state.entries, ...result.entries])` (one combined dedup — the builder re-sorts globally by `createdAt` DESC then `id`, so merge order is irrelevant). Set `state.entries` to the built list; keep `nextCursor` from `result` and keep the existing `PageLoaded` event. In `refresh`: `sessions = _uniqueSessions(result.entries)`, set entries to `buildSectionedEntries(...)`, keep `SessionsRefreshed`. No longer trust `result.entries`' server `section`.

- [x] **Task 4: Build `create` entry via the builder** (depends on Task 2)
  Files: `lib/BreathModule/Core/BreathSessionNotifier.dart`
  Replace the bespoke `newEntry = BreathSessionListEntry(section: mine)` prepend with: `sessions = _uniqueSessions([BreathSessionListEntry(session: saved, section: BreathListSection.mine), ...state.entries])`, then `entries = buildSectionedEntries(sessions, currentUserId())`. Keep the `SessionCreated(saved)` event and `nextCursor`.
  > Behaviour shift (intentional, accepted by note 131): the new session is no longer pinned to the absolute top of the whole list — it lands at the top of its derived section (`createdAt` DESC). Record this in the commit body so it is not read as a regression.

- [x] **Task 5: Collapse `starSession` into "set `isStarred`, rebuild"** (depends on Task 2)
  Files: `lib/BreathModule/Core/BreathSessionNotifier.dart`
  After the repository write, keep the guard `if (!state.entries.any((e) => e.session.id == id)) return;`. Then: `sessions = _uniqueSessions(state.entries).map((s) => s.id == id ? s.copyWith(isStarred: starred) : s).toList()`, `entries = buildSectionedEntries(sessions, currentUserId())`, and `updatedSession = sessions.firstWhere((s) => s.id == id)`. Emit `SessionStarred(updatedSession)`. Remove the entire bespoke STARRED insert/remove + `orElse` fallback block — the builder now produces/drops the starred duplicate automatically. Verify semantics still match: a starred own session appears in STARRED + MINE; a starred shared session in STARRED + SHARED; unstarring drops only the STARRED duplicate while the MINE/SHARED entry remains.

### Phase 3: Keep existing tests compiling & green

- [x] **Task 6: Update `breath_session_notifier_test.dart` for the new constructor and derived semantics** (depends on Tasks 1-5)
  Files: `test/BreathModule/breath_session_notifier_test.dart`
  The constructor change and the section/order re-derivation break this target at compile time and several assertions semantically. Apply:
  - **Both constructor sites** (`_make` at line 116, and the inline construction at line 394): pass `currentUserId: () => authSubject.value.user.id` (reads the same live source production uses, so user-change tests stay correct).
  - **`_session(...)` helper** (line 98): change `userId: 'u'` to `userId: 'user-1'` so it matches the auth user `_user1.id` and resolves to MINE (otherwise every session becomes SHARED, breaking `created entry has mine section` at line 254 and the MINE `firstWhere` at line 379). Where a SHARED case is needed, construct a session with a non-matching `userId` explicitly.
  - **`create() › prepends new entry` (line 230)**: the builder sorts by `createdAt` DESC then `id`, and all `_session(...)` share epoch-0 `createdAt`. Either give `_session(...)` distinct ascending `createdAt` values so newest-first ordering is meaningful, or relax this assertion to "saved-new is present in the MINE section" rather than absolute `entries.first`.
  - **`load() › cursor appends entries without dedup` (line 159)**: this asserts the literal append behaviour the plan deliberately replaces. Rename/rewrite it to assert the new builder semantics — all unique ids present, no duplicate ids for non-starred sessions, within-section order by `createdAt` DESC then `id`.
  - **`starSession` tests (lines 348-410)**: keep them green against the rebuild path — the STARRED-only-page unstar test (line 388) now keeps the session visible in MINE/SHARED after unstar (more correct), so update its expectation from "entry removed entirely" to "only the STARRED duplicate is gone; MINE/SHARED entry remains". Adjust the `FakeBreathSessionRepository.sectionForFetch` usage accordingly (section tag is no longer authoritative; what matters is `userId`/`isStarred`).
  - Add a focused assertion that a starred session yields both a STARRED and a MINE entry (the duplicate) after `load`, and that `_uniqueSessions` OR-ing works when the fake returns the starred duplicate before/after the ownership entry.
  Run `flutter test test/BreathModule/breath_session_notifier_test.dart` and the full `flutter test` to confirm the whole target compiles and passes.

- [x] **Task 7: Fix the stale notifier snippet in the testing doc** (depends on Task 1)
  Files: `docs/core/testing.md`
  Lines 82-92 show a `BreathSessionNotifier(repository:, authStream:)` example that becomes a non-compiling copy-paste trap after the constructor gains `currentUserId`. Add the `currentUserId: () => ...` argument to that snippet. Single-line doc fix only — no other doc edits.

### Notes for the implementer
- `update` already replaces the session per-entry while preserving each entry's section; since ownership/starred are unchanged by an update, its sections stay correct — leave it as-is to limit scope (rebuilding via the builder would be purely cosmetic).
- Edge case (acceptable, more correct than before): unstarring a session whose ownership duplicate is on an unloaded page now keeps it visible in its MINE/SHARED section instead of vanishing until refresh.
- `BreathSessionListService` needs no change — it still reads `entry.section`, which is now populated locally by the builder; `_determineOwnership` stays consistent with the builder's mine/shared rule.

## Commit Plan

Single commit. Task 1's `required currentUserId` change breaks the notifier test target at compile time, and the test assertions only become correct once the builder is wired through every path (Tasks 3-5). Splitting would leave the repo red between commits, so land all tasks together.

- **Commit** (Tasks 1-7): "Derive breath list sections and starred duplication from row columns"
  Body:
  - Foundation for the Drift-render path (note 131/132): sections/starred duplication are now derived locally from `userId`/`isStarred`/`createdAt` via a pure `buildSectionedEntries` builder instead of trusting the server `section` tag. Still network-fed; no Drift/proto/schema change.
  - Within-section order is now `createdAt` DESC then `id`; `create` lands the new session at the top of its section rather than the absolute list top (intentional).
  - Updates `breath_session_notifier_test.dart` for the new `currentUserId` constructor arg and derived semantics, and fixes the stale snippet in `docs/core/testing.md`.
