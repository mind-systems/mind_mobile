# Plan Review 2: Derive list sections + starred duplication from row columns

**Plan:** `.ai-factory/plans/65-derive-list-sections-starred-duplication-from-row-columns.md`
**Files Reviewed:** plan + 8 source/test/doc files (notifier, App.dart, BreathSession, BreathListSection, ViewModel, ListService, notifier test, ViewModel sections test, testing.md)
**Risk Level:** 🟢 Low

This is the second-pass plan. All three findings from review 1 (compile/semantics break, order-dependent
dedup, non-deterministic sort) have been folded in directly and correctly. The design remains sound and is
now implementation-ready. Verification below.

---

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** PASS. Notifier stays pure Dart — `currentUserId` is a
  `String Function()` closure, no Flutter/Riverpod import. `buildSectionedEntries` is instance-free
  (static/top-level), matching the "pure builder" intent.
- **Rules (`.ai-factory/RULES.md`):** PASS. Dependency is constructor-injected (Task 1); App.dart only gains
  a thin closure argument to the already-existing construction — no new module state/stream introduced.
- **Roadmap (`.ai-factory/ROADMAP.md`):** WARN (non-blocking). This is a `refactor` foundation tied to
  note 131/132 with no explicit open roadmap item. The commit body links note 131/132, which is sufficient.

---

## Verification of Review-1 Fixes

- **Issue #1 (BLOCKER — test target breaks at compile + semantics):** RESOLVED. Task 6 now covers both
  constructor sites (lines 116 and 394 — confirmed accurate), changes `_session(...)` `userId` from `'u'`
  to `'user-1'` to match `_user1.id` so sessions resolve to MINE, and rewrites the order/append/star
  assertions. Confirmed `_user1.id == 'user-1'` (test line 95) and the auth source matches production.
- **Issue #2 (order-dependent first-occurrence dedup):** RESOLVED. Task 2's `_uniqueSessions` is now
  order-independent and ORs `isStarred` across duplicates. Confirmed against the ViewModel fixture
  (`breath_session_list_sections_test.dart` line 234) where the MINE duplicate carries `isStarred: false` —
  so the OR is genuinely required, not theoretical.
- **Issue #3 (unstable sort):** RESOLVED. Task 2 specifies a deterministic `id` tie-breaker with a concrete
  comparator. Justified because `BreathSession`'s default `createdAt` is `epoch(0)` (model line 25), shared
  by all test sessions.
- **Doc snippet drift:** RESOLVED by Task 7. Confirmed `docs/core/testing.md` lines 84–87 show the stale
  two-arg constructor; the single-line fix is appropriate.

---

## Correctness Spot-Checks (this pass)

- **Line references accurate.** App.dart: `userNotifier` at line 175, `BreathSessionNotifier(...)` at line
  176 (grep-confirmed) — exactly as the plan states. `userNotifier.currentUser` exists and is the same
  source `BreathSessionListService._determineOwnership` reads, so the notifier builder and the service stay
  consistent (plan note line 67 holds).
- **Builder ↔ ViewModel contract intact.** `_buildItemsWithSections` re-groups by section preserving
  arrival order; emitting globally `createdAt` DESC-then-`id` sorted entries gives correct within-section
  order regardless of how ownership/starred entries interleave in the flat list. No ViewModel change needed —
  correctly identified.
- **`starSession` rebuild path is sound.** With `_uniqueSessions(state.entries)` always containing the id
  (guaranteed by the retained guard at line 163), `sessions.firstWhere((s) => s.id == id)` for the
  `SessionStarred` payload can never throw — so dropping the old `orElse` fallback (Task 5) is safe.
- **`create` behaviour shift is real and disclosed.** In the test fake, `saved-new` keeps `epoch(0)`
  `createdAt`, so it sorts after `'a'` by the `id` tie-breaker — Task 6 correctly pre-empts this by relaxing
  the `entries.first == 'saved-new'` assertion. Intentional, recorded in the commit body.

---

## Minor Notes / Nits (non-blocking)

- **Star-derivation tests need `isStarred` on the seed, not `sectionForFetch`.** Because the builder ignores
  the server `section` tag and reads `session.isStarred`, the existing `_session(...)` helper (no `isStarred`
  param) plus `sectionForFetch = starred` will no longer produce a STARRED entry — the fake returns a session
  with `isStarred == false`, so the builder emits only a MINE/SHARED entry. Task 6 already states "section
  tag is no longer authoritative; what matters is `userId`/`isStarred`", which captures the intent, but the
  implementer should concretely (a) seed `_session('a').copyWith(isStarred: true)` for starred cases, and
  (b) to exercise the `_uniqueSessions` OR-ing, have the fake emit two entries for one id (starred-first and
  starred-last) since today's fake returns exactly one entry per seeded session. This is a test-construction
  detail, not a plan defect.
- **Cross-page derivation is now eager (acceptable).** A starred own session returned on any page immediately
  yields both a STARRED and a MINE entry (builder-derived), even if the server only tagged one. This is the
  same "more correct than before" family the plan documents for the unstar edge case; worth a one-line
  mention in the commit body alongside the existing notes, but not required.

---

## Positive Notes

- Every review-1 finding is addressed at the exact mechanism level (comparator, OR-dedup, both constructor
  sites, doc snippet) rather than hand-waved — the plan is concrete enough to implement without guesswork.
- Collapsing `starSession` from the bespoke insert/remove/`orElse` block into "set `isStarred`, rebuild" is a
  genuine simplification and removes the fragile fallback-payload path.
- Correctly scopes out `_buildItemsWithSections`, the Drift schema, the proto, and `BreathSessionListService`
  — minimal blast radius, foundation-only, still network-fed.
- Single-commit rationale is correct: the `required currentUserId` arg makes the split unavoidable without a
  red intermediate state.

---

## Verdict

The plan is solid and implementation-ready. All blocking and robustness issues from review 1 are resolved,
line references and API usage are accurate, and the remaining items are test-construction details already
anticipated by Task 6.

PLAN_REVIEW_PASS
