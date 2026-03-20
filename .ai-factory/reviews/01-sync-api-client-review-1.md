# Review: Sync API Client

## Code Review Summary

**Files Reviewed:** 6 (3 response models, 1 interface, 1 implementation, 1 DI wiring)
**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md:** WARN — no violations. New files placed in `lib/Core/Api/` and `lib/Core/Api/Models/`, consistent with the architecture's Core infrastructure layer. `ISyncApi` sits alongside `ITokenApi` in `Core/Api/`, appropriate for a cross-cutting sync concern.
- **RULES.md:** WARN — file does not exist, no rules to check.
- **ROADMAP.md:** OK — "Sync API Client" milestone is present and marked complete.

### Critical Issues

None.

### Suggestions

None.

### Positive Notes

- **Consistent patterns throughout.** All three models (`ChangeEvent`, `SyncResponse`, `BatchSessionsResponse`) follow the established `fromJson` factory style used by `TokenDTO` and `BreathSessionsListResponse`. The list deserialization in `BatchSessionsResponse.fromJson` is identical to the pattern in `BreathSessionsListResponse.fromJson`.

- **`SyncResponse.fullResync` handles absent keys gracefully.** The `as bool? ?? false` pattern correctly defaults to `false` when the server omits the flag during normal incremental responses.

- **`SyncApi` follows existing API class patterns exactly.** Constructor takes `HttpClient`, methods are `async`, deserialization uses `response.data as Map<String, dynamic>`. Matches `TokenApi` and `BreathSessionApi`.

- **DI wiring is correct and well-positioned.** `syncApi` field, constructor param, initializer (after `breathSessionApi`), and `App._()` argument are all in the right places. Single-line initializer style rule is followed.

- **No security concerns.** Both endpoints go through `HttpClient` → `AuthInterceptor` (JWT attached automatically). `lastEventId` is `int` and `ids` are UUIDs from the sync pipeline — no user-controlled strings interpolated into URLs.

- **Error handling inherited cleanly.** All `DioException`s are caught by `HttpClient._handleDioError` and converted to `ApiException`. No new error paths introduced.

REVIEW_PASS
