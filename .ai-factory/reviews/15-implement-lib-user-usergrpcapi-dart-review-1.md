# Code Review: Implement `lib/User/UserGrpcApi.dart`

**Plan:** `15-implement-lib-user-usergrpcapi-dart.md`
**Risk Level:** Low

## Files Reviewed

- `lib/User/UserGrpcApi.dart` (new, 61 lines)
- `lib/Core/App.dart` (1 import + 1 line changed)

## Verification

### Interface compliance

All three `IUserApi` methods implemented with correct signatures:
- `updateUser(UpdateUserRequest)` → `Future<void>`
- `fetchStats()` → `Future<UserStatsDTO>`
- `fetchSuggestions(String)` → `Future<List<SuggestionDTO>>`

### Proto field mapping — `updateUser`

- `UpdateProfileRequest` factory accepts `String? name` and `String? language` — matches `UpdateUserRequest.name` (`String?`) and `.language` (`String?`). Null fields are silently omitted by the proto factory, which is the correct behavior (partial update).

### Proto field mapping — `fetchStats`

Verified against `stats.pb.dart` (`GetStatsResponse`):

| Proto field | Proto type | DTO field | DTO type | Conversion | Correct |
|---|---|---|---|---|---|
| `totalSessions` | `int` | `totalSessions` | `int` | none | yes |
| `totalDurationSeconds` | `int` | `totalDurationSeconds` | `int` | none | yes |
| `currentStreak` | `int` | `currentStreak` | `int` | none | yes |
| `longestStreak` | `int` | `longestStreak` | `int` | none | yes |
| `lastSessionDate` | `String` (default `""`) | `lastSessionDate` | `String?` | `hasLastSessionDate()` guard | yes |
| `maxCompletedComplexity` | `double` | `maxCompletedComplexity` | `int` | `.toInt()` | yes |

### Proto field mapping — `fetchSuggestions`

- `GetSuggestionsRequest.timeOfDay` accepts `TimeOfDay?` enum — matched via `_mapTimeOfDay`.
- `_mapTimeOfDay` string values (`'morning'`, `'midday'`, `'evening'`) verified against `DayPeriod.queryValue` which returns `name` (identical strings). Default case returns `MORNING` — matches codebase defensive pattern.
- `GetSuggestionsResponse.suggestions` is `List<BreathSessionDto>` — `.map(_mapSuggestion).toList()` is correct.
- `_mapSuggestion` correctly maps `dto.description` to both `title` and `description` (matching `SuggestionDTO.fromJson` behavior where both read from `json['description']`). `iconUrl: null` is correct (no proto field).

### App.dart wiring

- `grpcClient.userService` → `UserServiceClient` — matches constructor parameter 1.
- `grpcClient.statsService` → `StatsServiceClient` — matches constructor parameter 2.
- `grpcClient.breathSessionService` → `BreathSessionServiceClient` — matches constructor parameter 3.
- Single line, no trailing commas — complies with style rule.
- All consumers (`UserRepository`, `HomeService`) type against `IUserApi` — swap is transparent.

### Pattern consistency

Follows established `BreathSessionGrpcApi` / `AuthGrpcApi` patterns: constructor takes stubs, inline proto request construction, private `_map*` helpers, single proto import alias per service. No redundant `.pbenum.dart` import — `bsProto.TimeOfDay` works via re-export.

## Issues

None found.

REVIEW_PASS
