# Patch: 23-implement-lib-user-statsgrpcapi-dart

**Source review:** `.ai-factory/reviews/23-implement-lib-user-statsgrpcapi-dart-review-1.md`

## Issue 1: Orphan `fetchStats()` override and unused import in `FakeUserApi`

**File:** `test/User/UserRepository_test.dart`

**Problem:** `FakeUserApi implements IUserApi` still contains a `fetchStats()` method with `@override` and imports `UserStatsDTO`. Since `fetchStats()` was removed from `IUserApi` in this milestone, the `@override` annotation triggers `override_on_non_overriding_member` analyzer diagnostic. The `UserStatsDTO` import on line 5 is now unused. Both are dead code left behind by the extraction.

**Fix:** Remove the `fetchStats()` override (lines 18–26) and the `UserStatsDTO` import (line 5). Keep the `SuggestionDTO` import (line 4) — it is still used by `fetchSuggestions()` on line 29.

**Before:**
```dart
import 'package:mind/User/Models/SuggestionDTO.dart';
import 'package:mind/User/Models/UserStatsDTO.dart';
import 'package:mind/Core/Api/Models/UpdateUserRequest.dart';
```

```dart
class FakeUserApi implements IUserApi {
  @override
  Future<void> updateUser(UpdateUserRequest request) async {}

  @override
  Future<UserStatsDTO> fetchStats() async => UserStatsDTO(
        totalSessions: 0,
        totalDurationSeconds: 0,
        currentStreak: 0,
        longestStreak: 0,
        lastSessionDate: null,
        maxCompletedComplexity: 0,
      );

  @override
  Future<List<SuggestionDTO>> fetchSuggestions(String timeOfDay) async => [];
}
```

**After:**
```dart
import 'package:mind/User/Models/SuggestionDTO.dart';
import 'package:mind/Core/Api/Models/UpdateUserRequest.dart';
```

```dart
class FakeUserApi implements IUserApi {
  @override
  Future<void> updateUser(UpdateUserRequest request) async {}

  @override
  Future<List<SuggestionDTO>> fetchSuggestions(String timeOfDay) async => [];
}
```

**Risk:** None — `fetchStats()` has zero callers in test code (the `UserRepository` tests only exercise auth, login, and profile update paths). Removing it keeps `FakeUserApi` consistent with the updated `IUserApi` interface.
