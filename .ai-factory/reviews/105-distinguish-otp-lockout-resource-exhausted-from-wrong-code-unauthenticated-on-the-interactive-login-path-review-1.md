# Code Review: Distinguish OTP lockout (`RESOURCE_EXHAUSTED`) from wrong code (`UNAUTHENTICATED`) on the interactive login path

**Scope reviewed:** `git diff HEAD` — `AuthApi.dart`, `OtpLockedException.dart`, `OtpSendCooldownException.dart`, `LoginViewModel.dart`, `LoginState.dart`, `LoginScreen.dart`, `OnboardingScreen.dart`, `mind_l10n` ARB + generated localizations.
**Verdict:** The changed code is correct and faithfully implements the plan. No blocking bugs. One non-blocking runtime observation (out of plan scope, deferred to note 59) is recorded below so it is not mistaken for clean single-message UX at QA time.

## Correctness verification

Traced the full runtime path end-to-end and confirmed:

- **Status-code discrimination is correct.** `AuthApi.verifyCode`/`sendCode` catch `GrpcError`, map only `StatusCode.resourceExhausted` to the typed exceptions, and `rethrow` everything else (including `UNAUTHENTICATED` for a wrong code). Strictly code-based, never message-text — matches the guard in the spec.
- **`try` placement is right.** In `verifyCode`, `_storage.write(...)` and `_mapUser(...)` only execute on a successful response, so the token write stays on the success path; on `RESOURCE_EXHAUSTED` the lockout exception is thrown before any storage mutation.
- **Propagation reaches the ViewModel.** `AuthApi` → `UserRepository.completePasswordlessSignIn` (awaits, line 72, no catch) → `UserNotifier.completePasswordlessSignIn` (catches, publishes, **rethrows** — line 58) → `LoginService` (awaits) → `LoginViewModel`. The typed exception survives because the notifier rethrows. Confirmed in source, not assumed.
- **ViewModel catch ordering is valid.** The `on OtpLockedException` / `on OtpSendCooldownException` clauses precede the generic `catch (_)`, so the typed branch wins; `isLoading: false` is reset in every branch. No auto-resend on lockout.
- **Both error switches are exhaustive and both updated.** `LoginScreen.dart:32` and `OnboardingScreen.dart:31` are the only two `switch (error)` sites; adding the two enum values forces compile-time coverage, and both now handle all four cases. No other consumer of `LoginError` exists.
- **`const` exceptions are valid** (field-less classes with `const` constructors) — `throw const OtpLockedException()` compiles.
- **Interceptor interaction is safe.** `GrpcAuthInterceptor._onUnauthenticatedError` only reacts to `StatusCode.unauthenticated`; `RESOURCE_EXHAUSTED` (code 8) is ignored, so a lockout does **not** spuriously trigger `triggerLogout()`. The wrong-code `UNAUTHENTICATED` → `triggerLogout()` path is pre-existing and a no-op during login (`clearSession` early-returns on `GuestState`).
- **l10n is consistent.** ARB keys, the abstract getters in `app_localizations.dart`, and both concrete subclasses (`_en`, `_ru`) were all regenerated and committed (this package uses `synthetic-package: false`), so `l10n.loginTooManyAttemptsError` / `loginSendCodeCooldownError` resolve at compile time. EN/RU copy matches the spec.
- **Cooldown path is genuinely single-message.** `UserNotifier.sendPasswordlessSignInLink` has no try/catch, so `OtpSendCooldownException` propagates without ever publishing to `authErrorStream` — the cooldown case yields exactly one localized alert.

## Findings

### Low — Raw exception string leaks to the user on the lockout path (out of plan scope; deferred to note 59)

On the **verify-code lockout** path only, the user sees **two** messages:

1. The intended localized `AppAlert` (`tooManyAttemptsError`) from `LoginViewModel.onErrorEvent`, and
2. A raw global snackbar from `GlobalListeners` (`GlobalListeners.dart:45`): `Ошибка входа: OtpLockedException: too many wrong OTP attempts, account temporarily locked`.

Mechanism: `UserNotifier.completePasswordlessSignIn` does `_authErrorSubject.add(e.toString())` before rethrowing (`UserNotifier.dart:57`), and that stream is rendered verbatim as a snackbar. Because `OtpLockedException.toString()` returns the class name + an English technical string, this leaks an untranslated, developer-facing message to end users alongside the polished alert.

Assessment:
- **Not introduced by this diff, and not a defect in the changed code.** The same double-display already exists today for the wrong-code (`codeInvalidOrExpired`) path — the new exception merely flows through the same unchanged publish-and-rethrow path. The diff carries the wart forward to the lockout case rather than creating it.
- The spec (note 58) explicitly scopes the `authErrorStream` suppression and double-snackbar fix to the **next** roadmap task (note 59: `if (e is! OtpLockedException) _authErrorSubject.add(e.toString())`). So this is a known, accepted limitation, not a plan deviation.
- Recorded here only so verify/QA does not expect a single clean localized message on lockout. If desired, note 59's one-line source suppression in `UserNotifier` could be folded forward, but that is a deliberate scope decision, not a correctness fix this task owes.

### Informational — Deeplink lockout remains uncaught (explicitly note 59's task)

`AuthCodeDeeplinkHandler.handle` (`AuthCodeDeeplinkHandler.dart:23`) awaits `completePasswordlessSignIn(code)` with no try/catch, so on lockout it now rethrows `OtpLockedException` (previously a raw `GrpcError`) up to `DeeplinkRouter`. This is no worse than the prior behavior (an uncaught error either way) and is the subject of the following roadmap task (note 59). No action required for this milestone.

## Notes

- No migrations, schema, or proto changes — consistent with the spec (proto contract unchanged, no stub regen).
- Exception placement, naming, `const` boundary pattern, and doc comments mirror the established `GoogleSignInCanceledException`.
- Commit split (boundary mapping vs. presentation/copy) is coherent and each commit is independently buildable.
