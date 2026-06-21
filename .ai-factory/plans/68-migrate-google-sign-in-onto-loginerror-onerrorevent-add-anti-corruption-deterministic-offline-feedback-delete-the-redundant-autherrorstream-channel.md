# Plan: Migrate Google Sign-In onto LoginError/onErrorEvent, add anti-corruption + deterministic offline feedback, delete the redundant authErrorStream channel

## Context
Move Google Sign-In off the crude global `authErrorStream` snackbar channel onto the screen-local `LoginError`/`onErrorEvent` pipeline the OTP login already uses, add an anti-corruption layer that translates GMS network failures into a domain `NoConnectionException` (with deterministic offline feedback), and delete the now-dead `authErrorStream` channel end-to-end.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Anti-corruption layer (infra → domain)

- [x] **Task 1: Add `NoConnectionException` domain exception**
  Files: `lib/User/Models/NoConnectionException.dart`
  Create `class NoConnectionException implements Exception` with a descriptive `toString()`. Mirror the existing `GoogleSignInCanceledException` / `OtpLockedException` style in `lib/User/Models/` (pure Dart, doc comment explaining it is the infra→domain transport for the no-network case). No constructor args needed.

- [x] **Task 2: Translate GMS network errors in `GoogleAuthProvider` and skip browser fallback** (depends on Task 1)
  Files: `lib/User/Infrastructure/GoogleAuthProvider.dart`
  Rework `getServerAuthCode()` so only our own types escape the class (`GoogleSignInCanceledException`, `NoConnectionException`, or a generic `Exception`) — no `GoogleSignInException` / `PlatformException` leaks out:
  - In `getServerAuthCode()`, catch `GoogleSignInException` from `_gmsFlow()`:
    - If `_isNetworkError(e)` → log (`GMS failed with network error … skipping browser fallback`) and `throw NoConnectionException()`. Do **not** call `_browserFlow()` — this skip is the determinism fix (offline browser fallback returns the ambiguous `CANCELED` that was being swallowed as a fake user-cancel).
    - Else (GMS genuinely unavailable, e.g. no Play Services) → log + fall back to `_browserFlow()` as today.
  - Keep a trailing generic `catch (e)` → log + `_browserFlow()` (preserves the MissingPluginException / other paths that legitimately need the browser).
  - Add `bool _isNetworkError(GoogleSignInException e)` helper: the code is `unknownError` (not network-specific), so match on `e.description?.toLowerCase()` containing `'network error'` or `'[7]'` (status 7 = `NETWORK_ERROR`). Keep this string-matching contained to the helper and comment it as the only such seam.
  - In `_browserFlow()`: keep `PlatformException(code == 'CANCELED') → throw GoogleSignInCanceledException()`. For other `PlatformException` (e.g. `NO_BROWSER`) and unexpected errors, add detailed logging (`code` / `message` / `details`) and rethrow generically.
  - Add step logging at the start of `_gmsFlow` and `_browserFlow` (offline-visible diagnostics, since OTLP→Loki needs network).
  - Import the new `NoConnectionException`; import `google_sign_in` types as needed for `GoogleSignInException`.

### Phase 2: Domain notifier cleanup

- [x] **Task 3: Simplify `UserNotifier.loginWithGoogle` and remove `_authErrorSubject`**
  Files: `lib/User/UserNotifier.dart`
  Make `loginWithGoogle` structurally identical to `completePasswordlessSignIn` — no error typing, no publish, just rethrow:
  - Delete the `_authErrorSubject` field (line 19), the `authErrorStream` getter (line 39), and its `.close()` in `dispose` (line 119).
  - In `loginWithGoogle`: remove the `on GoogleSignInCanceledException { return; }` swallow in Phase 1 — let `GoogleSignInCanceledException` / `NoConnectionException` / generic propagate to the ViewModel (call `getGoogleServerAuthCode()` without a try/catch). Keep the Phase 2 `_authInProgressSubject` spinner; in its `catch (e)` block remove the `_authErrorSubject.add(...)` line and keep `log + rethrow`.
  - Remove the now-unused `GoogleSignInCanceledException` import if nothing else in the file uses it.

### Phase 3: Presentation mapping (the existing LoginError pipeline)

- [x] **Task 4: Add `LoginError` cases and map them in `LoginViewModel`** (depends on Task 1, Task 3)
  Files: `lib/User/Presentation/Login/Models/LoginState.dart`, `lib/User/Presentation/Login/LoginViewModel.dart`
  - Add `noConnection` and `googleSignInFailed` to `enum LoginError` (two cases only — no speculative additions).
  - In `LoginViewModel.loginWithGoogle()`: import `NoConnectionException`; replace the swallow body with mapping mirroring the OTP methods:
    - `on GoogleSignInCanceledException` → no-op (real cancel stays silent; now live code).
    - `on NoConnectionException` → `onErrorEvent?.call(LoginError.noConnection)`.
    - `catch (_)` → `onErrorEvent?.call(LoginError.googleSignInFailed)` (removes the stale "already published to authErrorStream" comment).

- [x] **Task 5: Add ARB keys and regenerate localizations** (depends on Task 4)
  Files: `packages/mind_l10n/lib/l10n/app_en.arb`, `packages/mind_l10n/lib/l10n/app_ru.arb`
  Add `loginNoConnectionError` (EN "No internet connection" / RU "Нет подключения к интернету") and `loginGoogleSignInError` (EN "Google sign-in failed" / RU "Не удалось войти через Google"), following the existing `loginSendCodeError` entry style. Regenerate `AppLocalizations` (run `flutter gen-l10n` or `flutter pub get` in `packages/mind_l10n` per project l10n setup) so `app_localizations.dart` / `app_localizations_en.dart` / `app_localizations_ru.dart` expose the new getters.

- [x] **Task 6: Extend both screen switches to map the new cases → l10n** (depends on Task 4, Task 5)
  Files: `lib/User/Presentation/Login/OnboardingScreen.dart`, `lib/User/Presentation/Login/LoginScreen.dart`
  Add `LoginError.noConnection => l10n.loginNoConnectionError` and `LoginError.googleSignInFailed => l10n.loginGoogleSignInError` to the exhaustive `switch (error)` in **both** files (they must be updated together — the build fails until both handle the new cases). Keep the existing OTP cases untouched.

### Phase 4: Delete the redundant channel

- [x] **Task 7: Remove `authErrorStream` from `GlobalListeners`** (depends on Task 3)
  Files: `lib/Core/GlobalUI/GlobalListeners.dart`
  Remove the `authErrorStream` field, the `_authErrorSubscription`, its `initState` `listen`, and its `dispose` `cancel`. Update the class doc comment to drop the "Auth errors via authErrorStream" line. Keep `sessionExpiredStream`, the `'Сессия истекла'` snackbar, and all `globalSnackBarNotifierProvider` plumbing intact.

- [x] **Task 8: Remove the `authErrorStream` argument in `App.dart`** (depends on Task 7)
  Files: `lib/Core/App.dart`
  Remove the `authErrorStream: App.shared.userNotifier.authErrorStream,` argument (line ~302) from the `GlobalListeners(...)` construction, keeping `sessionExpiredStream`.

- [x] **Task 9: Remove obsolete `authErrorStream` tests and update doc reference** (depends on Task 3)
  Files: `test/User/UserNotifier_test.dart`, `docs/core/global-listeners.md`
  Delete the entire `group('authErrorStream', ...)` block (the three tests reference the deleted getter and will not compile). Do not touch the OTP / `completePasswordlessSignIn` test groups. In `docs/core/global-listeners.md`, remove the `authErrorStream` row from the events table (keep `sessionExpiredStream`), matching the language of the existing doc.

## Commit Plan
- **Commit 1** (after tasks 1-2): "Add NoConnectionException and translate GMS network errors in GoogleAuthProvider"
- **Commit 2** (after tasks 3-6): "Route Google Sign-In errors through the LoginError pipeline"
- **Commit 3** (after tasks 7-9): "Delete the redundant authErrorStream channel"
