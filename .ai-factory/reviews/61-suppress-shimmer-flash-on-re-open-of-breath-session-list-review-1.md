# Code Review: Suppress shimmer flash on re-open of breath session list

**Plan:** `.ai-factory/plans/61-suppress-shimmer-flash-on-re-open-of-breath-session-list.md`
**Files reviewed (code):**
- `packages/breath_module/lib/src/BreathSessionsList/IBreathSessionListService.dart`
- `lib/BreathModule/BreathSessionListService.dart`
- `packages/breath_module/lib/src/BreathSessionsList/BreathSessionListViewModel.dart`
- `test/BreathModule/Presentation/BreathSessionsList/breath_session_list_sections_test.dart` (existing implementer of the interface)

The three production changes match the plan and are individually correct: the new `currentItems()` accessor reuses the existing `_mapEntries` mapper (no duplicated logic), reads the long-lived notifier's in-memory state synchronously, and `build()` reuses `_buildItemsWithSections`/`_transformDTOsToModels` to render content immediately when the cache is warm, falling through to the shimmer on a cold (empty) start. The boundary is respected — only DTOs cross into the ViewModel.

However, there is one blocking correctness problem.

## Findings

### 1. [HIGH — breaks compilation of the test suite] `_FakeService` no longer satisfies `IBreathSessionListService`

Adding `currentItems()` as an abstract method to `IBreathSessionListService` makes every implementer of that interface obligated to provide the method. The existing test fake does not:

`test/BreathModule/Presentation/BreathSessionsList/breath_session_list_sections_test.dart:19`
```dart
class _FakeService implements IBreathSessionListService {
  // observeChanges / loadNext / refresh implemented...
  // ❌ no currentItems() override
}
```

Because the class uses `implements` (not `extends`/`with`), Dart requires every interface member to be implemented. The analyzer raises `missing_concrete_implementation` / `non_abstract_class_inherits_abstract_member`, and the file **fails to compile**. The entire `breath_session_list_sections_test.dart` suite — 16 tests covering section ordering, duplication, and full-list replacement — will not run. `flutter test` fails.

This is a real regression introduced by this change, not a pre-existing issue. The plan's "Testing: no" setting covered *adding* tests, but it does not exempt the change from keeping the existing suite compiling.

**Fix:** add the missing override to `_FakeService`. Returning an empty list is sufficient and preserves all current test expectations (an empty cache makes `build()` take the existing shimmer path, exactly as the tests assume today):
```dart
@override
List<BreathSessionListItemDTO> currentItems() => const [];
```
`BreathSessionListItemDTO` is already imported in the test's `show` clause, so no import change is needed.

**Optional follow-up (not blocking):** consider one test that returns a non-empty `currentItems()` and asserts `build()` yields `BreathSessionListMode.content` (no shimmer) — this is the actual behavior the milestone introduces and is currently unverified.

## Non-blocking observations

- **`hasMore: true` on the warm path is safe.** If the list was already fully paged (`nextCursor == null`), a scroll could in principle trigger `loadNext()` → `notifier.load(null, …)` (a page-one reload). In practice the `BehaviorSubject` replay reaches `_handleListUpdated` and corrects `hasMore` before any realistic scroll. Matches the plan's documented intent. No change needed.
- **Comment accuracy.** `// always refresh from server in background` overstates `_loadInitialPage()`, which calls `loadNext(nextCursor)` — on re-open this fetches the *next* page rather than reloading page one. Pre-existing behavior, cosmetic only.
- **Race-free read.** `_loadInitialPage()` mutates notifier state only after an `await`, so the synchronous `currentItems()` call in `build()` deterministically observes the prior cached state. Correct.

## Conclusion

One blocking finding: the existing test fake must implement the newly-required `currentItems()` or the test suite will not compile. The production code is otherwise correct and well-scoped.
