# Plan: Time-of-Day Suggestions Widget UI

## Context

Redesign the existing `SuggestionsCard` on the HomeScreen into a thin-bordered card with a randomized localized title (per time slot) and a horizontal auto-scrolling carousel of session cards. The carousel reverses at ends and stops permanently on user interaction.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Localization — time-of-day title variants

- [x] **Task 1: Add time-of-day title keys to ARB files**
  Files: `packages/mind_l10n/lib/l10n/app_en.arb`, `packages/mind_l10n/lib/l10n/app_ru.arb`
  Add 12 new localization keys (4 per time slot) using the `homeSuggestions` prefix:
  - `homeSuggestionsMorning1` … `homeSuggestionsMorning4` — "Good morning", "Morning energy", "Start your day right", "Wake up gently"
  - `homeSuggestionsMidday1` … `homeSuggestionsMidday4` — "Midday reset", "Recharge your focus", "Take a breath", "A moment for yourself"
  - `homeSuggestionsEvening1` … `homeSuggestionsEvening4` — "Wind down", "Evening calm", "Prepare for rest", "End the day well"
  Add corresponding Russian translations for all 12 keys.
  After editing, run `cd /Users/max/projects/mind/mind_mobile && /usr/local/bin/flutter gen-l10n` to regenerate `app_localizations*.dart`.

### Phase 2: Title helper

- [x] **Task 2: Create `SuggestionsTitle` helper** (depends on Task 1)
  Files: `lib/HomeModule/Presentation/HomeScreen/Widgets/SuggestionsTitle.dart` (new)
  Create a small helper that, given a `DayPeriod` (from `lib/Core/TimeOfDayHelper.dart`) and `AppLocalizations`, returns a randomly chosen title string for that period.
  - Use `DayPeriod.morning` / `.midday` / `.evening` to select the 4-key group.
  - Use `Random().nextInt(4)` to pick one of the four keys.
  - Return type: `String`.
  - Pure function (or static method): `String getSuggestionsTitle(DayPeriod period, AppLocalizations l10n)`.

### Phase 3: Suggestion card carousel item

- [x] **Task 3: Create `SuggestionCarouselItem` widget**
  Files: `lib/HomeModule/Presentation/HomeScreen/Widgets/SuggestionCarouselItem.dart` (new)
  A small stateless widget representing one session card inside the carousel:
  - Width: `MediaQuery.of(context).size.width * 0.44` (slightly less than half screen).
  - Fixed height (e.g. 72) to fit 2 lines of session name.
  - Background: `theme.cardColor` with `kCardCornerRadius` border radius.
  - Content: suggestion title (`bodyMedium`), max 2 lines, overflow ellipsis. Vertically centered padding.
  - Tappable via `InkWell` — `onTap` callback receives the suggestion id.
  - Follow the thin-border pattern from `ExerciseEditCell`: `Border.all(color: onSurface.withValues(alpha: 0.1))`.

### Phase 4: Auto-scrolling carousel widget

- [x] **Task 4: Create `AutoScrollCarousel` widget**
  Files: `lib/HomeModule/Presentation/HomeScreen/Widgets/AutoScrollCarousel.dart` (new)
  A `StatefulWidget` that wraps a horizontal `ListView.builder` and provides ambient auto-scroll:
  - Uses a `ScrollController` with `animateTo` driven by a repeating post-frame callback (or `Ticker`).
  - Scrolls slowly in one direction; when `scrollController.position.pixels` reaches `maxScrollExtent`, reverses direction; when it reaches `0`, reverses again.
  - Speed: ~20–30 logical pixels per second (calm, ambient pace).
  - On any user `ScrollNotification` of type `UserScrollNotification`, sets a flag that permanently stops the auto-scroll. Use `NotificationListener<ScrollNotification>` wrapping the `ListView`.
  - `itemBuilder` and `itemCount` passed as constructor params (generic reusable carousel).
  - Horizontal padding: 16 on both sides. Gap between items: 10.
  - Disposes ticker/controller on `dispose`.

### Phase 5: Rewrite SuggestionsCard

- [x] **Task 5: Rewrite `SuggestionsCard` as thin-bordered carousel card** (depends on Tasks 2, 3, 4)
  Files: `lib/HomeModule/Presentation/HomeScreen/Widgets/SuggestionsCard.dart`
  Rewrite the existing `SuggestionsCard` to match the new design:
  - Keep the `suggestionsFutureProvider` and `ConsumerWidget` structure.
  - Outer container: thin border (`Border.all(color: onSurface.withValues(alpha: 0.1))`), `kCardCornerRadius`, horizontal margin 16, vertical padding.
  - Title row: call `getSuggestionsTitle(getDayPeriod(DateTime.now()), l10n)` — called once per build (provider caches, so rebuilds are rare). Use `titleSmall` style. Padding: `fromLTRB(16, 12, 16, 8)`.
  - Body: `AutoScrollCarousel` with `SuggestionCarouselItem` children built from the suggestions list.
  - On tap: navigate to the session via `context.push(BreathSessionScreen.path, extra: suggestion.id)`. Import `BreathSessionScreen` from `breath_module` and `go_router`.
  - Loading state: keep existing `CircularProgressIndicator` sized box.
  - Error state: keep existing error text.
  - Empty state: `SizedBox.shrink()`.

### Phase 6: HomeScreen sliver reordering

- [x] **Task 6: Move SuggestionsCard above the module grid** (depends on Task 5)
  Files: `lib/HomeModule/Presentation/HomeScreen/HomeScreen.dart`
  In `HomeScreen.build`, move the `SliverToBoxAdapter(child: SuggestionsCard())` to be the **first sliver** in the `CustomScrollView.slivers` list — above `SliverPadding` (module grid) and `StatsCard`. This ensures suggestions appear at the very top of the scrollable content, as specified.

## Commit Plan
- **Commit 1** (after tasks 1-2): "Add time-of-day localized title variants for suggestions widget"
- **Commit 2** (after tasks 3-6): "Redesign SuggestionsCard as thin-bordered auto-scrolling carousel"
