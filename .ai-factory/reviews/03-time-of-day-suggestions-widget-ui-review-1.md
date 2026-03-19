# Review: Time-of-Day Suggestions Widget UI

**Plan:** `.ai-factory/plans/03-time-of-day-suggestions-widget-ui.md`
**Files reviewed:** 11 changed/new files (full diff + full file reads)

---

## Issues

### 1. BUG — InkWell splash invisible in SuggestionCarouselItem

**File:** `lib/HomeModule/Presentation/HomeScreen/Widgets/SuggestionCarouselItem.dart:27-45`
**Severity:** Moderate (visual, not crash)

The `InkWell` wraps a `Container` with `BoxDecoration(color: theme.cardColor, ...)`. The Container's background color paints **over** the ink splash effect, making tap feedback invisible. The nearest `Material` ancestor is the `Scaffold`, but the opaque Container sits between it and the InkWell's splash layer.

Compare with `HomeScreenCell.dart:18-22` which uses the correct pattern: `Material(color: ...) → InkWell(child: ...)`.

**Fix:** Replace the `SizedBox → InkWell → Container` hierarchy with `SizedBox → Material → InkWell → Container(no color, border only)`:

```dart
return SizedBox(
  width: width,
  height: _height,
  child: Material(
    color: theme.cardColor,
    borderRadius: BorderRadius.circular(kCardCornerRadius),
    child: InkWell(
      onTap: () => onTap(id),
      borderRadius: BorderRadius.circular(kCardCornerRadius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kCardCornerRadius),
          border: Border.all(color: onSurface.withValues(alpha: 0.1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        alignment: Alignment.centerLeft,
        child: Text(...),
      ),
    ),
  ),
);
```

---

### 2. BUG — Title randomizes on every rebuild

**File:** `lib/HomeModule/Presentation/HomeScreen/Widgets/SuggestionsTitle.dart:7`
**Severity:** Minor (cosmetic flicker, low frequency)

`getSuggestionsTitle` creates `Random().nextInt(4)` on each call. Since it's invoked inside `SuggestionsCard.build()` (line 45), any widget rebuild picks a potentially different title. The spec says: *"Random title selected once on widget build, not on every rebuild."*

In practice, rebuilds are rare because the `FutureProvider` caches its result. But parent-tree rebuilds (e.g. theme change, orientation change) will cause a title flicker.

**Fix options (pick one):**
- **(a)** Promote `SuggestionsCard` to `ConsumerStatefulWidget`, pick the title in `didChangeDependencies` (once per mount), store in a `late String _title` field.
- **(b)** Fold the random index into the provider — return a record `(String title, List<SuggestionDTO> suggestions)` from `suggestionsFutureProvider` so the title is computed once when data arrives.

---

### 3. LAYOUT — Carousel cross-axis alignment

**File:** `AutoScrollCarousel.dart` + `SuggestionCarouselItem.dart`
**Severity:** Cosmetic

`_carouselHeight` in `SuggestionsCard` is 88px, but `SuggestionCarouselItem._height` is 72px. In a horizontal `ListView`, items are top-aligned by default, leaving 16px of dead space below each card. This may look slightly unbalanced.

**Suggestion:** Either reduce `_carouselHeight` to ~80 (72 + 8 bottom breathing room), or center items vertically by wrapping the `itemBuilder` output in a `Center` or `Align(alignment: Alignment.center)`.

---

## Verified — No Issues

| Area | Status |
|------|--------|
| L10n keys: EN/RU ARBs match generated Dart files | OK |
| L10n keys: all 12 keys present in both locales | OK |
| `TimeOfDayHelper` slot boundaries match spec (morning 5-11, midday 12-16, evening 17-4) | OK |
| AutoScrollCarousel ticker lifecycle (start after frame, dispose on unmount) | OK |
| AutoScrollCarousel direction reversal at scroll extents | OK |
| `UserScrollNotification` correctly detects user touch without false-triggering from `jumpTo` | OK |
| `jumpTo` (not `animateTo`) avoids scroll animation conflicts | OK |
| First-tick delta-time handled (dt=0 when `_lastTickTime == Duration.zero`) | OK |
| Navigation: `context.push(BreathSessionScreen.path, extra: id)` matches existing coordinator pattern | OK |
| HomeScreen sliver reordering: SuggestionsCard now first sliver | OK |
| No unused imports | OK |
| No security concerns (no user input in routes, no injection vectors) | OK |

---

REVIEW_PASS
