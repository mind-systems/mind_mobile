# Review: Sync API Client

## Scope

6 files changed: 3 response models (`ChangeEvent`, `SyncResponse`, `BatchSessionsResponse`), interface (`ISyncApi`), implementation (`SyncApi`), DI wiring (`App.dart`).

## Correctness

**Models** — All three follow the established `fromJson` factory pattern. Field types match the sync-engine spec (`id` as `int`, `entity`/`refId`/`action` as `String`). `SyncResponse.fullResync` correctly defaults to `false` when absent from JSON — matches the spec where a normal incremental response omits the flag.

**SyncApi.fetchChanges** — String-interpolated query param (`?after=$lastEventId`). `lastEventId` is `int`, so no URL-encoding concern. Matches the pattern in `BreathSessionApi.fetchAll`.

**SyncApi.fetchSessionsBatch** — Joins UUIDs with commas into the query string. UUIDs contain only `[a-f0-9-]`, so no encoding issue. URL length is bounded by the caller (SyncEngine controls batch size).

**App.dart** — Field, constructor param, initializer, and `App._()` argument all wired correctly. Follows single-line style rule. Positioned after `breathSessionApi` in the init sequence.

## Bugs

None found.

## Security

- Both endpoints go through `HttpClient` → `AuthInterceptor` (JWT attached automatically). No auth bypass.
- No user-controlled strings are interpolated into URLs — `lastEventId` is `int`, `ids` are UUIDs from the sync event pipeline. No injection vector.

## Runtime risks

None. Error handling is inherited from `HttpClient._handleDioError` (all `DioException`s become `ApiException`). No new failure modes introduced.

## Minor notes (non-blocking)

- **Empty ids list**: If `fetchSessionsBatch` is called with an empty list, the request becomes `GET /breath_sessions/batch?ids=`. Not a bug — the caller (SyncEngine) should guard against this, and it's outside the API client's scope.
- **Query param style**: `fetchChanges` and `fetchSessionsBatch` use URL string interpolation. `UserApi.fetchSuggestions` uses the `queryParameters` map. Both work with Dio — this is a pre-existing inconsistency, not introduced by this change.

REVIEW_PASS
