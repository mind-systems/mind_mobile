# Code Review: Derive list sections + starred duplication from row columns

**Plan:** `.ai-factory/plans/65-derive-list-sections-starred-duplication-from-row-columns.md`
**Changed files reviewed (in full):**
- `lib/BreathModule/Core/BreathSessionNotifier.dart`
- `lib/Core/App.dart`
- `test/BreathModule/breath_session_notifier_test.dart`
- `docs/core/testing.md`
- Supporting context read: `BreathSessionRepository.dart`, `BreathSessionApi.dart`, `BreathSessionListService.dart`, `BreathSessionListViewModel.dart`, `SyncEngine.dart`, models.

**Verification run:**
- `flutter test test/BreathModule/breath_session_notifier_test.dart` → **28/28 passed**.
- `flutter analyze` on the three changed lib files → **No issues found**.

---

## Summary

The change is correct and faithfully implements the plan and note 131. Sections (MINE/SHARED + STARRED duplicate) are now derived locally in `buildSectionedEntries` from `userId`/`isStarred`/`createdAt`, the server `section` tag is no longer trusted, and `starSession` collapses cleanly into "set `isStarred`, rebuild". No correctness, security, or runtime-breaking defects were found.

Key risks called out in the plan review were all properly handled:

- **Constructor break / test target.** Both notifier construction sites in the test (`_make` and the inline one) now pass `currentUserId`, and `App.dart` wires `currentUserId: () => userNotifier.currentUser.id`. No other construction sites exist (grep-confirmed). Whole test target compiles and runs.
- **`_uniqueSessions` order-independence.** Implemented as an OR over `isStarred` across duplicates of an id (`existing.copyWith(isStarred: true)` when any duplicate is starred), keeping all other fields from the first occurrence — robust to server emitting the MINE/SHARED duplicate (which may carry `isStarred=false`) before the STARRED entry. Covered by the "uniqueSessions OR-ing" test.
- **Unstable sort.** `buildSectionedEntries` sorts `createdAt` DESC with a deterministic `id` tie-breaker, so output is fully deterministic even for the shared epoch-0 default `createdAt`.

## Correctness spot-checks

- **`create` ordering is not a regression.** `saved` returned by `BreathSessionApi.create` populates `createdAt: DateTime.parse(dto.createdAt)` from the server response, so a newly created session carries a fresh timestamp and sorts to the top of its (MINE) section — matching prior "new session on top" behaviour. The intentional shift (top-of-section rather than absolute-top) is documented.
- **No other consumers broken.** `SyncEngine` only calls `breathSessionNotifier.invalidate()` (unchanged). `BreathSessionListService` still reads `entry.section` (now locally populated) and its `_determineOwnership` mirrors the builder's mine/shared rule. `_buildItemsWithSections`, Drift schema, and proto are untouched, as required.
- **starSession edge case** (ownership duplicate on an unloaded page) now keeps the session visible in MINE/SHARED after unstar — the documented, more-correct behaviour; the `firstWhere` is safe because the session always survives in the rebuilt list.
- **User switch** path is consistent: `invalidate()` clears entries and the `currentUserId` closure reads the BehaviorSubject's already-updated value, so no stale-user section derivation.

---

## Advisory notes (non-blocking, no action required to proceed)

1. **Unrelated file staged for commit.** `assets/audio/tick_heartbeat.ogg` is staged (binary, modified) but has nothing to do with this milestone. Recommend not including it in the section-derivation commit — keep the commit scoped to the notifier/test/doc/App changes.
2. **`buildSectionedEntries` is a public top-level symbol** (no `_`). This is intentional per note 132 (the later Drift-render path will reuse it), so leaving it public is fine; just be aware it is now part of the file's API surface.
3. **Minor redundancy in `create`.** The placeholder `section: BreathListSection.mine` passed into `_uniqueSessions(...)` is ignored (the helper only reads `entry.session`); any section value would do. Harmless — purely cosmetic.
4. **Accepted behaviour, already documented.** Within-section order is now `createdAt` DESC (local) rather than server-curated, and the merged list re-sorts on each page append; this can make items shift position during pagination. This is the tradeoff flagged in note 131's open questions, not a defect.

---

No bugs, security issues, or correctness problems found. Advisory notes above are optional hygiene/awareness items only.

REVIEW_PASS
