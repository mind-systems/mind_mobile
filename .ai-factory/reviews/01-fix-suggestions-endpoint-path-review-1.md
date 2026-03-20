# Review: Fix suggestions endpoint path

## Scope

Single line change in `lib/Core/Api/UserApi.dart:26` — endpoint path updated from `'/users/me/suggestions'` to `'/breath_sessions/suggestions'`.

## Checklist

| Check | Result |
|-------|--------|
| Path matches backend controller | OK — endpoint moved to `breath_sessions` controller |
| Query parameter preserved | OK — `timeOfDay` still passed unchanged |
| Response parsing unchanged | OK — still deserializes `List<SuggestionDTO>` |
| Method signature unchanged | OK — `IUserApi` contract intact |
| Callers unaffected | OK — `SuggestionsCard` and test fake both go through `IUserApi.fetchSuggestions()`, no hardcoded paths elsewhere |
| Auth: endpoint still requires JWT | Assumed — `breath_sessions/` routes are auth-gated on the backend like `users/me/` was; `AuthInterceptor` attaches the token regardless of path |
| No migration needed | OK — client-only change |
| No type mismatches | OK — response shape hasn't changed |

## Issues found

None.

REVIEW_PASS
