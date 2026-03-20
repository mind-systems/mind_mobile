# Plan: Fix suggestions endpoint path

## Context
The suggestions endpoint moved from the users controller to the breath_sessions controller on the backend. The mobile client still hits the old path and needs to be updated.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

- [x] **Task 1: Update endpoint path in UserApi**
  Files: `lib/Core/Api/UserApi.dart`
  In `fetchSuggestions()` (line 26), change the request path from `'/users/me/suggestions'` to `'/breath_sessions/suggestions'`. The method signature, query parameters, and response parsing stay the same.
