# Plan Review: Suppress shimmer flash on re-open of breath session list

**Plan:** `.ai-factory/plans/61-suppress-shimmer-flash-on-re-open-of-breath-session-list.md`
**Files Reviewed:** 3 target files + notifier/state model
**Risk Level:** 🟢 Low

## Verification of Plan Assumptions

All three task assumptions were verified against the codebase:

| Claim | Status |
|-------|--------|
| `BreathSessionListItemDTO` already imported in `IBreathSessionListService.dart` | ✅ Confirmed (line 1) |
| `currentItems()` can map `notifier.currentState.entries` via `_mapEntries` | ✅ `currentState` getter returns `_subject.value` with `entries`; `_mapEntries` exists (line 48) |
| `notifier.currentState` already used in concrete service | ✅ Used in `loadNext` (line 38) |
| `_buildItemsWithSections` + `_transformDTOsToModels` exist in ViewModel | ✅ Both present (lines 142, 169) |
| `SkeletonCellModel` / `BreathSessionListMode` available in `build()` | ✅ Already used in current `build()` |
| Notifier is long-lived (cached entries survive ViewModel rebuilds) | ✅ Injected from `App.shared`; ViewModel is per-screen, notifier is not |

The core mechanism is sound: on re-open the long-lived notifier still holds `entries`, so `currentItems()` returns content synchronously and the shimmer is skipped. A true cold start has `entries == []`, so it correctly falls through to the shimmer.

## Context Gates

### Architecture (`.ai-factory/ARCHITECTURE.md`) — PASS
The change respects the domain/module boundary. `currentItems()` is added to the module-declared interface and implemented in the concrete service, which maps domain entries → DTOs via the existing `_mapEntries`. No domain models cross into the ViewModel — it consumes `BreathSessionListItemDTO` only. Compliant.

### Rules (`.ai-factory/RULES.md`) — PASS
- "Module Services must be stateless — no `StreamController`/`StreamSubscription`/`dispose()`." → `currentItems()` is a pure synchronous read of notifier state. No state added. ✅
- "`observeChanges()` must return a derived stream directly from the notifier." → Untouched. ✅
- DI via constructor → Untouched. ✅

### Roadmap (`.ai-factory/ROADMAP.md`) — WARN
This is a `fix`-class change (shimmer flash on re-open) but is not linked to a ROADMAP phase. The roadmap's most recent breath-list work is Phase 34 (cursor pagination + sections), which this builds directly on. **Non-blocking**, but consider adding a roadmap entry for traceability, consistent with prior phases.

## Findings (Non-Blocking Observations)

1. **`_loadInitialPage()` is pagination-forward, not a refresh, on re-open.**
   The plan's inline comment `// always refresh from server in background` is slightly inaccurate. `_loadInitialPage()` → `service.loadNext()` → `notifier.load(notifier.currentState.nextCursor, …)`. On re-open the persisted `nextCursor` is non-null, so this **appends the next page** rather than refreshing page one. This is **pre-existing behavior** (the current `build()` already calls `_loadInitialPage()` unconditionally) and is not introduced by this plan, so it is out of scope. Recommend softening the comment to `// continue/refresh list from server in background` to avoid implying a page-one reload. Reconciliation of `hasMore` still happens correctly — both via this load and via the `BehaviorSubject` replay of the current state through `observeChanges()`.

2. **`hasMore: true` conservative default is safe.**
   If the list was already fully paginated (`nextCursor == null`), returning `hasMore: true` could let a `loadNext()` scroll trigger a page-one reload (`notifier.load(null, …)` replaces entirely). However, the `BehaviorSubject` replay fires almost immediately on subscribe and `_handleListUpdated` corrects `hasMore` to the real value before any realistic user scroll. Acceptable as documented.

3. **Compilation coupling between Task 1 and Task 2 (expected).**
   Adding the abstract method (Task 1) without the concrete implementation (Task 2) breaks compilation of `BreathSessionListService`. This is the normal interface-then-impl sequence and the tasks are correctly ordered with a stated dependency. No action needed.

4. **Empty-list users still see a brief shimmer on re-open.**
   When a user genuinely has zero sessions, `entries == []` so `currentItems()` returns `[]` and the shimmer shows again until the background load emits `empty`. This matches the plan's stated intent ("shimmer intentionally still shows on cold start") and is acceptable since the milestone targets the content case.

## Positive Notes

- Minimal, surgical three-file change that reuses existing mappers (`_mapEntries`, `_buildItemsWithSections`, `_transformDTOsToModels`) with zero duplicated logic.
- Correctly preserves the subscription wiring and `_loadInitialPage()` call, so reconciliation paths (`_handleListUpdated`, `_handleSessionsInvalidated`) remain intact.
- No DAO/Drift/proto/event-type changes — scope is well-contained and respects the "never key list cells by id / no dedup" guards from Phase 34.
- Race-free: `_loadInitialPage()` is async and mutates `entries` only after an `await`, so the synchronous `currentItems()` read returns the prior cached state deterministically.

## Conclusion

The plan is technically correct, respects the architecture and project rules, and all file paths / API usages are accurate. The only items are a slightly misleading code comment and an optional roadmap linkage — neither blocks implementation.

PLAN_REVIEW_PASS
