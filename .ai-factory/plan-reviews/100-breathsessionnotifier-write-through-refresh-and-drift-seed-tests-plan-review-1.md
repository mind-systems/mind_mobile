# Plan Review: BreathSessionNotifier write-through refresh and Drift-seed tests

**Plan:** `100-breathsessionnotifier-write-through-refresh-and-drift-seed-tests.md`
**Risk Level:** 🟢 Low
**Verdict:** Solid — accurate and well-grounded. Minor notes only, none blocking.

## Verification Performed

Cross-checked every source-line reference and API assumption against the live code:

| Plan claim | Source | Status |
|---|---|---|
| `loadLocal()` reads `_readLocalEntries()`, early-returns if empty, else emits `LocalSessionsLoaded` (lines 107–114) | `BreathSessionNotifier.dart:107-114` | ✅ exact |
| `invalidate()` always emits `LocalSessionsLoaded` even when empty (lines 116–122) | `BreathSessionNotifier.dart:116-122` | ✅ exact |
| `refresh()` guards on `_isLoading`, awaits `repository.refresh(pageSize)`, re-reads Drift, emits `SessionsRefreshed` (lines 133–149) | `BreathSessionNotifier.dart:133-149` | ✅ exact |
| `buildSectionedEntries` ownership/starred logic (lines 35–53), sort DESC + id tie-break (lines 37–41), starred duplicate (lines 48–50) | `BreathSessionNotifier.dart:35-53` | ✅ exact |
| Seeded empty state at construction (lines 78–80) | `BreathSessionNotifier.dart:78-80` | ✅ exact |
| Fake `refresh(int)` is a no-op at line 28 | test file line 28 | ✅ exact |
| `BreathSession.createdAt` defaults to epoch 0 when omitted | `BreathSession.dart:25` (`DateTime.fromMillisecondsSinceEpoch(0)`) | ✅ correct |
| `_session()` defaults `userId` to `'user-1'` == `_make()` currentUserId → MINE | test file lines 77, 101 | ✅ correct |
| `BreathListSection` enum values `mine`/`shared`/`starred` | `BreathListSection.dart:1` | ✅ correct |
| `BreathSessionListEntry` has `.session` / `.section` | `BreathSessionsListResponse.dart:4-12` | ✅ correct |
| `repository.refresh(pageSize)` returns `void`, opaque to notifier; cursor loop lives in repository | `IBreathSessionRepository.dart:7-10` | ✅ correct — scope boundary is sound |

The scope boundary in Context (do not re-test repository pagination at the notifier level; verify delegation only) is correct and matches the interface contract. The Task 1 counter approach (`refreshCallCount`, `refreshPageSizes`, keeping `refresh()` a no-op) is the right way to assert the delegation contract without testing the fake.

The concurrency reasoning in Task 3's last case is sound: the first `refresh()` runs synchronously to the `await repository.refresh()` point (incrementing the counter to 1), control yields, the second call hits the `_isLoading` guard at line 134 and returns before touching the repo — so `refreshCallCount == 1`. Matches the existing `concurrent refresh()` test's behavior.

## Context Gates

- **Architecture** (`.ai-factory/ARCHITECTURE.md`): present. Test-only plan, no boundary impact. No issues.
- **Rules** (`.ai-factory/RULES.md`): present. No test-convention rule conflicts; the only adjacent rule (App.dart infrastructure-only) is not touched. No issues.
- **Roadmap** (`.ai-factory/ROADMAP.md`): present. This is a test-coverage task (milestone `100`, consistent with the sibling `100-*` test plans in the review history). Acceptable linkage. WARN (non-blocking): the plan body does not cite a ROADMAP line, but the numbering convention makes the linkage clear.
- **skill-context** (`.ai-factory/skill-context/aif-review/SKILL.md`): directory exists but is empty — no project-specific review overrides to apply. WARN (non-blocking, optional file absent).

## Minor Notes (non-blocking)

1. **Overlap with existing tests.** A few proposed cases substantially duplicate cases already in the spec:
   - Task 3 "re-read Drift after repository.refresh … replace stale entries" overlaps the existing `replaces state with fresh sessions` (test lines 131–144).
   - Task 3 "should not run a second refresh() while one is in flight" overlaps the existing `concurrent refresh()` (lines 157–169).
   - Task 6 "should emit both MINE and STARRED entries for a starred owned session" is nearly identical to the existing `starred session yields both MINE and STARRED entries after refresh` (lines 171–190).

   This is acceptable — the plan explicitly says to *extend* the existing `refresh()` group, and the new versions add a stronger assertion the old ones lack (`refreshCallCount`/`refreshPageSizes`). To avoid a bloated spec, the implementer should either fold the counter assertion into the existing tests or consciously keep the new cases narrowly scoped to the delegation counters. Worth a one-line note during implementation, not a blocker.

2. **Task 7, third case naming vs. assertion.** The case is titled "keep the STARRED duplicate *adjacent* to its ownership entry," but the described assertion only checks that both the `mine` and `starred` entries are *present*. The builder does emit them adjacently (ownership entry immediately followed by its starred duplicate within the sorted loop, lines 44–51), so if adjacency is the intent, assert their index positions are consecutive; otherwise rename the case to "…both entries present." Either is fine — just align name and assertion.

3. **Phase-dependency note.** The plan labels Phase 1 as "prerequisite for Phase 3." Phase 2 (`loadLocal`) and Phase 5 (section derivation) don't need the counters — only Phases 3 and 4 do. The ordering is fine; just clarifying the counters aren't a hard dependency for Phases 2/5.

## Positive Notes

- Every line citation is exact — no drift between plan and source.
- Correctly distinguishes `loadLocal()` (early-return on empty) from `invalidate()` (always emits), which is the subtle behavioral difference and is tested on both sides (Task 2 empty case + Task 4 empty case).
- Correctly flags the epoch-0 `createdAt` default and mandates explicit `DateTime` literals for sort tests — this is the exact trap that would otherwise make the sort assertions vacuous.
- Reuses existing `_make()`, `_session()`, `_entryIds()` helpers rather than inventing parallel scaffolding.
- Respects the architectural scope boundary: verifies notifier delegation, not repository internals.

PLAN_REVIEW_PASS
