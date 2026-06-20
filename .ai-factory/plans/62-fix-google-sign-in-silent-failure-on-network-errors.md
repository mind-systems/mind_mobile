# Plan: Fix Google Sign-In silent failure on network errors

## Context
GMS technical failures (e.g. network unreachable) currently masquerade as user cancels and produce no visible error. Removing the cancel catch from `_gmsFlow()` lets all GMS failures fall through to the browser flow, which already routes network errors to a snackbar.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Fix GMS flow error handling

- [x] **Task 1: Remove cancel catch from `_gmsFlow()`**
  Files: `lib/User/Infrastructure/GoogleAuthProvider.dart`
  In `_gmsFlow()`, delete the `try`/`on GoogleSignInException catch (e)` wrapper so the method body is just: call `_google.authorizationClient.authorizeServer(['email'])`, throw `Exception('Google Sign-In did not return a serverAuthCode.')` if the result is null, otherwise return `(code: serverAuth.serverAuthCode, redirectUri: null)`. All `GoogleSignInException` variants (including `canceled`) will now bubble unchanged to `getServerAuthCode()`'s outer `catch (e)`, which logs and falls back to `_browserFlow()`. The trailing `// MissingPluginException...` comment becomes redundant — remove it as part of cleaning up the method.
  Guards (do NOT touch these — they are already correct):
  - `_browserFlow()` — already maps `PlatformException(CANCELED)` → `GoogleSignInCanceledException` and lets network errors propagate as regular exceptions.
  - `GoogleSignInCanceledException` model — still used by the browser flow.
  - `UserNotifier.loginWithGoogle()` — swallowing `GoogleSignInCanceledException` is correct for the browser cancel path.
  - The `on GoogleSignInCanceledException { rethrow; }` clause in `getServerAuthCode()` — keep it; it preserves the browser-flow cancel-silently behavior.
  - Verify the now-unused `GoogleSignInExceptionCode` reference no longer leaves a dangling import only if nothing else in the file uses `google_sign_in` symbols (it does — `GoogleSignIn`, `GoogleSignInException` types remain via `authorizationClient`), so leave the import as-is.

## Notes
- Single-file, ~3 lines removed. No commit plan needed (under 5 tasks).
- Behavior after fix: GMS cancel → browser OAuth opens next (acceptable trade-off); GMS network failure → browser also fails → snackbar "Ошибка входа: …".
