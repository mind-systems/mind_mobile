# Plan Review: Derive list sections + starred duplication from row columns

**Plan:** `.ai-factory/plans/65-derive-list-sections-starred-duplication-from-row-columns.md`
**Files Reviewed:** plan + 9 source/test files
**Risk Level:** 🟡 Medium

The design is sound and well-aligned with note 131/132 and the existing architecture. The notifier
stays pure Dart, the closure injection matches `BreathSessionListService._determineOwnership`'s
existing user source, and routing entries through one pure builder is the right shape for the later
Drift-render path. However there is **one compile-breaking gap** (existing tests) and a couple of
correctness/robustness risks that must be addressed before implementation.

---

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** PASS. The notifier remains a pure-Dart domain object;
  injecting a `String Function()` keeps it free of Flutter/Riverpod. The builder is instance-free.
- **Rules (`.ai-factory/RULES.md`):**
  - Rule "All dependencies must be injected via constructor" — **PASS**: `currentUserId` is constructor-injected.
  - Rule "Never add module-specific state, streams, or triggers to App.dart" — **PASS** (WARN-adjacent):
    the plan only adds a thin closure argument to the *already-existing* `BreathSessionNotifier(...)`
    construction in App.dart. No new state/stream is introduced. Acceptable.
- **Roadmap (`.ai-factory/ROADMAP.md`):** **WARN.** This is a `refactor` foundation under the Phase 34
  area (note 131/132) but has no explicit open roadmap item. Non-blocking; mention linkage to note 131/132
  in the commit body.

---

## Critical Issues

### 1. 🔴 BLOCKER — Adding `required currentUserId` breaks the existing notifier test suite (compile + semantics)

`test/BreathModule/breath_session_notifier_test.dart` constructs the notifier at **two** sites without
the new argument:

- line 116: `BreathSessionNotifier(repository: repo, authStream: authSubject.stream)`
- line 394: `BreathSessionNotifier(repository: repo, authStream: authSubject.stream)`

Adding `required String Function() currentUserId` to the constructor makes both calls fail to compile.
`flutter test` compiles the whole test target, so **the entire test suite stops building** — not just
these tests. The plan's "Testing: no" setting means "don't add new coverage"; it does **not** excuse
leaving the project uncompilable. This must be fixed.

Beyond compilation, the refactor silently changes what these existing tests assert, because the builder
re-derives sections from `BreathSession.userId`/`isStarred`/`createdAt` instead of the server tag:

- Every `_session(id)` helper uses `userId: 'u'`, while the auth user is `user-1`. Under the builder,
  `userId ('u') != currentUserId ('user-1')` → **all sessions become SHARED, never MINE**. This breaks:
  - `create() › created entry has mine section` (line 254) — expects `BreathListSection.mine`.
  - `starSession() › unstar removes STARRED entry and sets isStarred=false on remaining` (line 367) —
    `firstWhere(... section == BreathListSection.mine)` (line 379) will throw (no MINE entry exists).
- `create() › prepends new entry to entries list` (line 230) expects `entries.first.id == 'saved-new'`.
  The builder sorts by `createdAt` DESC, and all `_session(...)` have the **same** default `createdAt`
  (epoch 0 — see `BreathSession` constructor), so first-position is no longer guaranteed.
- `load() › cursor appends entries without dedup` (line 159) asserts the literal append behaviour the
  plan deliberately replaces with builder-driven re-sort + dedup.

**Required:** add an explicit task to update `test/BreathModule/breath_session_notifier_test.dart`:
pass a `currentUserId` source to both constructors, give `_session(...)` a `userId` that matches the
auth user (or parameterize it) so MINE/SHARED resolve as intended, and update the section/order
expectations and the "append without dedup" test to the new semantics. Without this, Commit 1 (Task 1)
already leaves the repo red.

### 2. 🟡 IMPORTANT — `_uniqueSessions` "keep first occurrence" depends on an unstated server-ordering invariant

The server's `ListSessions` returns the same session id twice for a starred session (STARRED entry +
MINE/SHARED entry — confirmed by the duplication tests). Each entry's `isStarred` comes from its own
`BreathSessionWithStarredDto` (`BreathSessionApi._mapSessionWithStarred`). It is **not guaranteed** that
the MINE/SHARED duplicate carries `isStarred == true` — the ViewModel test fixtures
(`breath_session_list_sections_test.dart` line 234) model exactly the case where the MINE duplicate has
`isStarred: false`.

`_uniqueSessions(...)` keeping the *first* occurrence therefore only produces a correct flat list if the
server always emits the STARRED (`isStarred=true`) entry **before** the MINE/SHARED duplicate. If the
order ever flips, dedup keeps `isStarred=false`, the builder drops the starred duplicate, and starred
sessions silently disappear from the STARRED section after a load/refresh — a regression.

**Recommendation:** make `_uniqueSessions` robust to entry order by OR-ing the flag across duplicates of
the same id (e.g. keep the session but set `isStarred = entries.any(sameId && isStarred)`), rather than
trusting first-occurrence. At minimum, the plan should state the relied-upon invariant explicitly and add
a `// minimal` log if a unique session's `isStarred` had to be promoted, so a contract change is visible.

### 3. 🟡 MINOR — `createdAt` DESC sort needs a deterministic tie-breaker

`List.sort` in Dart is **not guaranteed stable**. Sessions with equal `createdAt` (same-millisecond
creation, or the epoch-0 default used throughout tests) will land in an undefined relative order, making
both production output and any test assertion on within-section order non-deterministic.

**Recommendation:** add a secondary, stable tie-breaker in the builder's comparator (e.g. `id`) so
ordering is fully deterministic. This also de-risks the test updates in issue #1.

---

## Minor Notes / Nits

- **Docs drift (WARN, "Docs: no").** `docs/core/testing.md` (lines 82–92) shows a
  `BreathSessionNotifier(repository:, authStream:)` example that will become stale/non-compiling after
  the constructor change. Even with docs out of scope, leaving a copy-pasteable broken snippet is a trap —
  consider a one-line update or flag it.
- **Behaviour change is acceptable but should be called out in the commit.** `create` no longer pins the
  new session to the absolute top of the list; it now lands at the top of the MINE section (after STARRED).
  Note 131/the plan already accept this; just make sure the commit message records the intentional shift so
  it isn't read as a regression.
- **`update` left as-is is fine.** Ownership/starred are unchanged by an update, so preserving each entry's
  section is correct. Agreed with the plan's "leave it" decision; rebuilding via the builder would be purely
  cosmetic.
- **App.dart wiring is correct.** `userNotifier` is created at line 175 and `breathSessionNotifier` at
  line 176; `currentUserId: () => userNotifier.currentUser.id` reads live state and matches
  `_determineOwnership`. Line references in the plan are accurate.

---

## Positive Notes

- Collapsing the bespoke `starSession` insert/remove/`orElse` block into "set `isStarred`, rebuild" is a
  genuine simplification and removes the fragile fallback-payload logic.
- Correctly identifies that `_buildItemsWithSections`, the Drift schema, and the proto must **not** change —
  the within-section order is owned by entry order, and section order stays downstream.
- The "more correct than before" edge case (unstarring a session whose ownership duplicate is on an
  unloaded page no longer makes it vanish) is a real improvement and is explicitly documented.
- Keeping `BreathSessionListService` untouched (it still reads `entry.section`, now locally populated) is
  the right minimal-blast-radius call.

---

## Verdict

The architecture is right, but the plan is **not implementation-ready** as written: Task 1 breaks the
existing test target at compile time and several existing notifier tests fail semantically, and there is
no task covering those updates. Address issue #1 (mandatory), and fold in issues #2 and #3 (robustness),
then proceed.

Recommended additions:
- New task (or fold into Task 1/Task 5): update `test/BreathModule/breath_session_notifier_test.dart`
  — both constructor sites, `_session` userId, and section/order/append expectations.
- Make `_uniqueSessions` order-independent for `isStarred` (issue #2).
- Add a deterministic tie-breaker to the builder's sort (issue #3).
