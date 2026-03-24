# Review: Throttle `_onScroll`

**Plan:** `.ai-factory/plans/01-throttle-onscroll.md`
**File changed:** `packages/breath_module/lib/src/BreathSessionsList/BreathSessionListScreen.dart`

## Changes reviewed

- Added `dart:async` import for `Timer`.
- Added `Timer? _scrollThrottleTimer` field.
- In `_onScroll`: early-return when timer is active, start a 200ms one-shot timer after each non-suppressed invocation.
- In `dispose`: cancel timer before disposing the scroll controller.

## Analysis

**Throttle behavior is correct.** Leading-edge throttle — fires immediately on the first scroll event, then suppresses all events for 200ms. After cooldown, the next scroll event fires immediately again. This is the right pattern for pagination triggers: responsive on first hit, cheap during sustained scrolling.

**Timer lifecycle is safe.** Timer is cancelled in `dispose()` before `_scrollController.dispose()`, so the callback can never fire on a disposed widget. The callback only nulls the field — no widget state access.

**ViewModel guard is preserved as safety net.** `loadNextPage()` already checks `!state.hasMore || state.isPaging`, so even if two calls somehow slip through, the ViewModel rejects duplicates.

**Edge case — timer starts unconditionally.** The timer starts even when scroll position is far from the threshold (i.e., the `loadNextPage()` call is skipped). This is fine and arguably better — it also throttles the threshold arithmetic and `ref.read` calls during fast scrolling at any position in the list.

**Edge case — scroll stops during cooldown near threshold.** If the user's scroll settles exactly at the threshold boundary during the 200ms window, and no further scroll events arrive, `loadNextPage()` won't fire until the next scroll gesture. In practice this is not a concern: momentum scrolling generates events well past any 200ms window, and the threshold is set 10 cells (~1090px) before the end, giving a large buffer.

**No issues with static analysis.** `flutter analyze` passes cleanly.

## Verdict

Clean, minimal change. No bugs, no security issues, no runtime risks.

REVIEW_PASS
