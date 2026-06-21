# Migrate Google Sign-In onto the existing LoginError pipeline + delete the redundant auth-error channel

**Date:** 2026-06-21
**Source:** conversation context

## Key Findings

- **We were about to reinvent an existing mechanism.** The passwordless/OTP login already implements the exact "typed error → enum → localized display" pipeline:
  - **Anti-corruption at the API boundary** — `lib/User/AuthApi.dart:35` translates a gRPC server error into a domain exception: `if (e.code == StatusCode.resourceExhausted) throw const OtpLockedException();` (also `OtpSendCooldownException`).
  - **ViewModel maps exception → `LoginError` enum** — `LoginViewModel.sendPasswordlessSignInLink`/`verifyCode` catch the domain exceptions and call `onErrorEvent?.call(LoginError.x)`.
  - **Screen maps `LoginError` → l10n** — `OnboardingScreen` and `LoginScreen` each have an exhaustive `switch (error) { LoginError.x => l10n.loginXError }` → `AppAlert.show(context, title: l10n.error, description: message)`. Already localized, using the screen's `BuildContext`.
- **Why bare errors flowed for Google:** the Google path was wired to a *separate, cruder* channel that bypasses the above. `UserNotifier._authErrorSubject` is a `PublishSubject<String>` pushing a hardcoded `'Failed to sign in with Google'`; `GlobalListeners` shows it as a global snackbar with hardcoded RU; and `LoginViewModel.loginWithGoogle` just `catch (_) {}` (swallow, comment "already published to authErrorStream"). Offline → ambiguous swallow → no feedback.
- **The global snackbar (`GlobalListeners`) is for context-less errors** (e.g. session-expired `'Сессия истекла'`, fired from anywhere with no UI context). Google Sign-In runs **in the login screen** — full access to `BuildContext`, `AppAlert`, and `AppLocalizations` — so it must use the screen-local `LoginError`/`onErrorEvent` path, not the global channel.
- **`authErrorStream` exists solely for Google Sign-In** — the only consumer is `GlobalListeners`, the only producers are the two Google emit sites in `UserNotifier`. Migrating Google off it makes the whole channel dead code → delete it. `GlobalListeners` keeps `sessionExpiredStream` (its legitimate context-less role).
- **Decision (user):** reuse `LoginError` (enum, not a new `AuthError`). Two new cases, network carved out from generic. l10n comes free via the existing screen switch — no `GlobalListeners` localization, no `rootScaffoldMessengerKey.currentContext` gotcha. Net result is **one atomic milestone that removes a parallel mechanism** rather than adding one.

## Details

### Anti-corruption + deterministic offline fix — `lib/User/Infrastructure/GoogleAuthProvider.dart`

Mirror the `AuthApi`/`OtpLockedException` precedent: only **our** types cross out of this class (`GoogleSignInCanceledException`, `NoConnectionException`, or a generic `Exception`); no `GoogleSignInException`/`PlatformException` escapes.

- `getServerAuthCode()`: catch `GoogleSignInException`.
  - Network error → log + `throw NoConnectionException()` and **do not** fall back to `_browserFlow()`. (Determinism root cause: when GMS fails on no-network, the browser fallback also needs network and returns non-deterministically — usually `PlatformException(CANCELED)` → swallowed as a fake user-cancel, occasionally `NO_BROWSER`. Skipping the fallback on network errors is what makes feedback deterministic; this is inseparable from the network-case handling.)
  - Else (GMS genuinely unavailable, e.g. no Play Services) → log + `_browserFlow()` as today.
  - Trailing generic `catch (e)` → log + `_browserFlow()` (preserves the MissingPluginException/other path that legitimately needs the browser).
- `_isNetworkError(GoogleSignInException e)` helper: code is `unknownError` (not network-specific), so match `e.description` (lowercased) containing `'network error'` or `'[7]'` (status 7 = `NETWORK_ERROR`). The only string-matching seam; keep contained + commented.
- `_browserFlow()`: keep `PlatformException(CANCELED) → GoogleSignInCanceledException`; for other `PlatformException` (e.g. `NO_BROWSER`) and unexpected errors, add detailed logging (`code`/`message`/`details`) and rethrow generically (only reached on the genuine no-GMS path now).
- Add step logging (`_gmsFlow`, `_browserFlow`) — only offline-visible diagnostics (OTLP→Loki needs network).

### New domain exception — `lib/User/Models/NoConnectionException.dart`

`class NoConnectionException implements Exception` with a `toString()`. Mirrors `OtpLockedException`/`GoogleSignInCanceledException` (pure Dart, `lib/User/Models/`). Infra→domain transport for the no-network case.

### Domain stays pure — `lib/User/UserNotifier.dart`

Make `loginWithGoogle` structurally identical to `completePasswordlessSignIn` — **no error typing, no publish, just rethrow**:

- Delete `_authErrorSubject` (field, `authErrorStream` getter, `.add(...)` calls, `.close()` in `dispose`).
- `loginWithGoogle`: Phase 1 (`getGoogleServerAuthCode`) — do **not** catch anything; let `GoogleSignInCanceledException` / `NoConnectionException` / generic propagate to `LoginViewModel`. Phase 2 (`authenticateWithGoogle`) — keep the `_authInProgressSubject` spinner; `catch (e)` → log + `rethrow` (LoginViewModel maps). The notifier no longer knows about `LoginError` or display.

### Enum + ViewModel mapping (the existing mechanism)

- `lib/User/Presentation/Login/Models/LoginState.dart`: add `noConnection` and `googleSignInFailed` to `enum LoginError`.
- `lib/User/Presentation/Login/LoginViewModel.dart` `loginWithGoogle()`: import `NoConnectionException`; map like the OTP methods:
  - `on GoogleSignInCanceledException` → no-op (real cancel; now live code, was a dead "safety net").
  - `on NoConnectionException` → `onErrorEvent?.call(LoginError.noConnection)`.
  - `catch (_)` → `onErrorEvent?.call(LoginError.googleSignInFailed)` (replaces the swallow + stale comment).

### Screen mapping → l10n (already exists, just extend)

- `packages/mind_l10n/lib/l10n/app_en.arb` + `app_ru.arb`: add `loginNoConnectionError` (RU "Нет подключения к интернету" / EN "No internet connection") and `loginGoogleSignInError` (RU "Не удалось войти через Google" / EN "Google sign-in failed"), matching the `loginSendCodeError` naming. Regenerate `AppLocalizations`.
- `lib/User/Presentation/Login/OnboardingScreen.dart` **and** `lib/User/Presentation/Login/LoginScreen.dart`: add the two cases to each exhaustive `switch (error)` → `l10n.loginNoConnectionError` / `l10n.loginGoogleSignInError`. (Exhaustive switch forces this — the build fails until both screens handle the new cases.)

### Delete the redundant channel

- `lib/Core/GlobalUI/GlobalListeners.dart`: remove the `authErrorStream` field, the `_authErrorSubscription`, its `initState` listen, and its `dispose` cancel. Keep `sessionExpiredStream` and the snackbar plumbing intact (the global snackbar's legitimate context-less role).
- `lib/Core/App.dart` (~line 302): remove the `authErrorStream:` argument to `GlobalListeners`.

### Two isolations achieved (via the existing pipeline)

- **Google ↔ our domain**: `GoogleAuthProvider` translates SDK failures to our exceptions — same pattern as `AuthApi`→`OtpLockedException`.
- **Business logic ↔ display/l10n**: domain rethrows; `LoginViewModel` maps to `LoginError`; the screen owns the localized text.

### Guards

- Do **not** change the OTP methods, `OtpLockedException`/`OtpSendCooldownException`, or the cancel semantics (real cancel stays silent).
- Do **not** repurpose or delete `GlobalListeners.sessionExpiredStream` / the snackbar mechanism — only the auth-error string channel goes.
- Both screen switches must be updated together (exhaustive `switch`).
- Two `LoginError` cases only — no speculative additions.

### Verification

1. Offline, tap Google → **every** attempt shows `AppAlert` "Нет подключения к интернету" (RU) / "No internet connection" (EN) on the login screen; logcat: `GMS failed with network error … skipping browser fallback`.
2. Online, complete GMS sign-in → works (no regression).
3. Online, cancel GMS picker / real cancel → silent, no alert.
4. Generic Google failure → localized `loginGoogleSignInError` alert.
5. `grep authErrorStream lib/` returns nothing; `flutter analyze` clean (exhaustive switches compile).

## Decisions (settled — do not re-open)

- The two ARB strings are **final, use verbatim** — `loginNoConnectionError`: RU "Нет подключения к интернету", EN "No internet connection"; `loginGoogleSignInError`: RU "Не удалось войти через Google", EN "Google sign-in failed". Do not paraphrase or invent alternatives.
