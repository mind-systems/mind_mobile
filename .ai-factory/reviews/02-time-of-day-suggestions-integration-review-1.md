# Review: Time-of-Day Suggestions Integration

## Scope
All staged changes on `dev` branch — 8 source files changed/added, 6 l10n files updated.

## Verification
- `flutter analyze` on all changed files: **no issues found**
- `flutter test test/User/UserRepository_test.dart`: **14/14 passed**

## File-by-file Review

### `lib/Core/TimeOfDayHelper.dart` (NEW)
Pure Dart, no Flutter imports. Hour boundaries (05-11 morning, 12-16 midday, 17-04 evening) are correct and cover all 24 hours. `queryValue` getter returns `name` (lowercase enum member name). Clean.

### `lib/User/Models/SuggestionDTO.dart` (NEW)
Follows `UserStatsDTO` pattern exactly. `fromJson` uses null-safe casts with fallbacks. `iconUrl` is nullable. No issues.

### `lib/Core/Api/HttpClient.dart` (MODIFIED)
Added optional `queryParameters` to `get()`. Passes through to `_dio.get()`. When null, Dio ignores it — backward-compatible. No issues.

### `lib/User/IUserApi.dart` (MODIFIED)
Added `fetchSuggestions(String timeOfDay)` to interface. Import added. No issues.

### `lib/Core/Api/UserApi.dart` (MODIFIED)
Implementation casts `response.data` as `List<dynamic>`, maps through `SuggestionDTO.fromJson`. Follows `fetchStats()` pattern. No issues.

### `lib/HomeModule/Presentation/HomeScreen/Widgets/SuggestionsCard.dart` (NEW)
- `FutureProvider.autoDispose` follows the `userStatsFutureProvider` pattern from `StatsCard.dart`.
- `ConsumerWidget` is correct (no stream subscription needed).
- `.when(loading:, error:, data:)` handles all states.
- Empty-list guard returns `SizedBox.shrink()` — correct.
- Divider pattern matches StatsCard's 1-physical-pixel approach.
- L10n strings used for header and error — no hardcoded strings.

### `lib/HomeModule/Presentation/HomeScreen/HomeScreen.dart` (MODIFIED)
`SuggestionsCard` added as `SliverToBoxAdapter` above `StatsCard`. Same embedding pattern. No `ProviderScope` needed (root scope covers it, as StatsCard already proves).

### `test/User/UserRepository_test.dart` (MODIFIED)
`FakeUserApi` updated with `fetchSuggestions` stub returning `[]`. Tests still pass.

### L10n (ARB + generated Dart)
Both `app_en.arb` and `app_ru.arb` have correctly placed entries. Generated files (`app_localizations.dart`, `_en.dart`, `_ru.dart`) match. JSON syntax valid — no trailing comma issues.

## Observations (non-blocking)

### 1. `DayPeriod` name shadows Flutter's `DayPeriod` — LOW
Flutter's `material.dart` exports `DayPeriod` (with `am`/`pm`). The custom `DayPeriod` in `TimeOfDayHelper.dart` uses the same name. This does **not** cause a compile error today — `SuggestionsCard.dart` imports both but never references `DayPeriod` by name (it calls `getDayPeriod()` and the type is inferred). Confirmed by `flutter analyze` passing clean. However, any future file that imports both `material.dart` and `TimeOfDayHelper.dart` and writes `DayPeriod` explicitly will get an ambiguity error. Consider renaming to `TimePeriod` or using `show`/`hide` on the import.

### 2. `SuggestionDTO.iconUrl` declared but unused in widget — INFO
The field is modeled in the DTO but `SuggestionsCard` doesn't render it. This is fine — the DTO correctly captures the full API shape, and the UI can add icon rendering later.

## Critical Issues
None.

REVIEW_PASS
