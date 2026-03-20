# Patch: 03-create-homescreen-service-layer

Fixes for review issues found in `03-create-homescreen-service-layer-review-1.md`.

---

## Fix 1: Skip BehaviorSubject replay in `observeChanges()`

**File:** `lib/HomeModule/HomeService.dart`
**Problem:** `userNotifier.stream` is a `BehaviorSubject` that replays the current value on subscription. When `HomeViewModel.build()` subscribes to `observeChanges()`, the replay immediately fires `HomeAuthenticated` (for authenticated users) or `HomeSessionExpired` (for guests). Since `build()` already calls `_loadInitialData()`, this causes a double load — 4 API calls instead of 2 on every HomeScreen visit.
**Root cause:** `ProfileService.observeProfile()` uses the replay intentionally (to populate `userName`), but `HomeService` has a separate explicit `_loadInitialData()` in `build()`, making the replay redundant.

**Change:** Add `.skip(1)` on `userNotifier.stream` before the `.where()` filters. `liveSessionNotifier.events` uses `PublishSubject` (no replay) and needs no change.

```dart
// BEFORE (lines 47-57):
  @override
  Stream<HomeEvent> observeChanges() {
    final statsInvalidated = liveSessionNotifier.events
        .where((e) => e is LiveBreathSessionEnded)
        .map((_) => StatsInvalidated() as HomeEvent);
    final sessionExpired = userNotifier.stream
        .where((s) => s is GuestState)
        .map((_) => HomeSessionExpired() as HomeEvent);
    final authenticated = userNotifier.stream
        .where((s) => s is AuthenticatedState)
        .map((_) => HomeAuthenticated() as HomeEvent);
    return statsInvalidated.mergeWith([sessionExpired, authenticated]);
  }

// AFTER:
  @override
  Stream<HomeEvent> observeChanges() {
    final statsInvalidated = liveSessionNotifier.events
        .where((e) => e is LiveBreathSessionEnded)
        .map((_) => StatsInvalidated() as HomeEvent);
    final userChanges = userNotifier.stream.skip(1);
    final sessionExpired = userChanges
        .where((s) => s is GuestState)
        .map((_) => HomeSessionExpired() as HomeEvent);
    final authenticated = userChanges
        .where((s) => s is AuthenticatedState)
        .map((_) => HomeAuthenticated() as HomeEvent);
    return statsInvalidated.mergeWith([sessionExpired, authenticated]);
  }
```

---

## Fix 2: Move duration formatting to the widget via raw DTO fields

**Problem:** `HomeService._formatDuration()` hardcodes English units (`h`, `min`). The old `StatsCard` used Russian units (`ч`, `мин`). Since the Service is pure Dart with no `BuildContext`, it can't access l10n. Russian users see mixed languages: "Время практики: 5 h 30 min".

**Fix:** Replace the pre-formatted `totalDuration` string field in `StatsDTO` with raw `durationHours` and `durationMinutes` integers. Add l10n keys for the unit labels. Format the display string in `StatsCard` using l10n.

### Step 2a: Update `StatsDTO`

**File:** `lib/HomeModule/Presentation/HomeScreen/Models/HomeDTOs.dart`

```dart
// BEFORE (lines 7-20):
class StatsDTO {
  final int totalSessions;
  final String totalDuration;
  final String currentStreak;
  final String longestStreak;
  final String lastSessionDate;
  const StatsDTO({
    required this.totalSessions,
    required this.totalDuration,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastSessionDate,
  });
}

// AFTER:
class StatsDTO {
  final int totalSessions;
  final int durationHours;
  final int durationMinutes;
  final String currentStreak;
  final String longestStreak;
  final String lastSessionDate;
  const StatsDTO({
    required this.totalSessions,
    required this.durationHours,
    required this.durationMinutes,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastSessionDate,
  });
}
```

### Step 2b: Update `HomeService.fetchStats()` and remove `_formatDuration`

**File:** `lib/HomeModule/HomeService.dart`

```dart
// BEFORE (lines 34-44):
  @override
  Future<StatsDTO?> fetchStats() async {
    if (isGuest) return null;
    final stats = await userApi.fetchStats();
    return StatsDTO(
      totalSessions: stats.totalSessions,
      totalDuration: _formatDuration(stats.totalDurationSeconds),
      currentStreak: '${stats.currentStreak}',
      longestStreak: '${stats.longestStreak}',
      lastSessionDate: _formatDate(stats.lastSessionDate),
    );
  }

// AFTER:
  @override
  Future<StatsDTO?> fetchStats() async {
    if (isGuest) return null;
    final stats = await userApi.fetchStats();
    return StatsDTO(
      totalSessions: stats.totalSessions,
      durationHours: stats.totalDurationSeconds ~/ 3600,
      durationMinutes: (stats.totalDurationSeconds % 3600) ~/ 60,
      currentStreak: '${stats.currentStreak}',
      longestStreak: '${stats.longestStreak}',
      lastSessionDate: _formatDate(stats.lastSessionDate),
    );
  }
```

Delete `_formatDuration` method (lines 60-65):
```dart
// DELETE:
  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '$h h $m min';
    return '$m min';
  }
```

### Step 2c: Add l10n keys for duration units

**File:** `packages/mind_l10n/lib/l10n/app_en.arb`

Add after `"homeStatsDuration"` line:
```json
  "homeStatsDurationHours": "{h} h {m} min",
  "@homeStatsDurationHours": {
    "placeholders": { "h": { "type": "String" }, "m": { "type": "String" } }
  },
  "homeStatsDurationMinutes": "{m} min",
  "@homeStatsDurationMinutes": {
    "placeholders": { "m": { "type": "String" } }
  },
```

**File:** `packages/mind_l10n/lib/l10n/app_ru.arb`

Add after `"homeStatsDuration"` line:
```json
  "homeStatsDurationHours": "{h} ч {m} мин",
  "@homeStatsDurationHours": {
    "placeholders": { "h": { "type": "String" }, "m": { "type": "String" } }
  },
  "homeStatsDurationMinutes": "{m} мин",
  "@homeStatsDurationMinutes": {
    "placeholders": { "m": { "type": "String" } }
  },
```

### Step 2d: Regenerate l10n

Run:
```bash
cd packages/mind_l10n && /usr/local/bin/flutter gen-l10n
```

### Step 2e: Format duration in `StatsCard` with l10n

**File:** `lib/HomeModule/Presentation/HomeScreen/Widgets/StatsCard.dart`

```dart
// BEFORE (line 27):
              Text('${l10n.homeStatsDuration}: ${stats.totalDuration}', style: theme.textTheme.bodyMedium),

// AFTER:
              Text('${l10n.homeStatsDuration}: ${_formatDuration(stats, l10n)}', style: theme.textTheme.bodyMedium),
```

Add a private helper to `StatsCard`:
```dart
class StatsCard extends ConsumerWidget {
  const StatsCard({super.key});

  static String _formatDuration(StatsDTO stats, AppLocalizations l10n) {
    if (stats.durationHours > 0) {
      return l10n.homeStatsDurationHours('${stats.durationHours}', '${stats.durationMinutes}');
    }
    return l10n.homeStatsDurationMinutes('${stats.durationMinutes}');
  }

  // ... rest of build unchanged
```

Add import for `HomeDTOs.dart` at the top of the file:
```dart
import 'package:mind/HomeModule/Presentation/HomeScreen/Models/HomeDTOs.dart';
```

---

## Commit plan

Single commit after both fixes:
```
Fix HomeScreen service layer: skip BehaviorSubject replay, localize duration
```
