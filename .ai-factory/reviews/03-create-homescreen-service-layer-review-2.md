## Code Review — Patch 1 fixes

**Scope:** Changes from `03-create-homescreen-service-layer-patch-1.md` (Fix 1: BehaviorSubject replay, Fix 2: duration localization).

### Fix 1: BehaviorSubject replay — verified correct

**File:** `lib/HomeModule/HomeService.dart:52`

`userNotifier.stream.skip(1)` is applied once and reused for both `sessionExpired` and `authenticated` streams. `liveSessionNotifier.events` (PublishSubject, no replay) is left untouched. The merged stream now only reacts to state *changes* after subscription, while `build()` handles the initial load. No double API calls.

### Fix 2: Duration localization — verified correct

**Files:** `HomeDTOs.dart`, `HomeService.dart`, `StatsCard.dart`, ARBs, generated l10n files.

- `StatsDTO.totalDuration` (String) replaced with `durationHours` (int) + `durationMinutes` (int). No remaining references to the old field.
- `HomeService._formatDuration` deleted. `fetchStats()` passes raw integers from `UserStatsDTO.totalDurationSeconds`.
- `StatsCard._formatDuration` formats using `l10n.homeStatsDurationHours` / `l10n.homeStatsDurationMinutes`. Branch on `durationHours > 0` is correct — avoids "0 h 5 min".
- ARB keys added to both `app_en.arb` and `app_ru.arb` with correct placeholders. JSON validated.
- Generated files (`app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_ru.dart`) match the ARBs: abstract methods with `String` params, concrete implementations with correct templates (`$h h $m min` / `$h ч $m мін`).

### No new issues found

- No dangling references to `totalDuration` or `_formatDuration` in the codebase.
- `HomeViewModel` and `HomeState` are unaffected — they pass `StatsDTO` through without accessing duration fields directly.
- `IHomeService` interface unchanged — `fetchStats()` still returns `Future<StatsDTO?>`.

REVIEW_PASS
