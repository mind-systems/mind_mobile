# Code Review: Migrate Google Sign-In onto LoginError/onErrorEvent + delete authErrorStream

**Branch:** dev · **Scope:** 9 source/doc/test files + l10n regeneration
**Verdict:** No correctness, security, or runtime-breaking issues found.

## What was reviewed

Read in full and cross-checked: `GoogleAuthProvider.dart`, `NoConnectionException.dart`, `UserNotifier.dart`, `LoginViewModel.dart`, `LoginState.dart`, `OnboardingScreen.dart`, `LoginScreen.dart`, `GlobalListeners.dart`, `App.dart`, the four l10n files, and `UserNotifier_test.dart`. Traced the full propagation chain and grepped for orphaned references.

## Correctness verification

- **Exception ordering in `GoogleAuthProvider.getServerAuthCode()` is correct.** `on GoogleSignInException catch (e)` precedes the trailing generic `catch (e)`, so the network branch is reachable. `throw NoConnectionException()` is raised *inside* the `on GoogleSignInException` block; Dart does not route exceptions thrown from one catch clause into a sibling catch clause, so `NoConnectionException` propagates out cleanly rather than being re-swallowed into the browser fallback. Confirmed.
- **Propagation chain is intact and lossless:** `GoogleAuthProvider` (translates) → `UserRepository.getGoogleServerAuthCode` (pure pass-through, `UserRepository.dart:79`) → `UserNotifier.loginWithGoogle` (Phase 1 now called outside any try/catch, so cancel/no-connection/generic all reach the caller; Phase 2 keeps the spinner and rethrows) → `LoginService.loginWithGoogle` (await pass-through, `LoginService.dart:27`) → `LoginViewModel.loginWithGoogle` (maps).
- **`LoginViewModel` catch ordering is correct:** `on GoogleSignInCanceledException` (silent) → `on NoConnectionException` → `catch (_)`. Distinct types, specific-before-generic. Maps to the right enum cases.
- **Exhaustive switches updated in both screens together** (`OnboardingScreen.dart:36-37`, `LoginScreen.dart:37-38`) with identical case→key mapping. Build cannot compile with one missing, so the two-case enum extension is fully covered.
- **l10n is internally consistent:** both ARB files, the abstract `app_localizations.dart`, and both `_en`/`_ru` implementations declare `loginNoConnectionError` and `loginGoogleSignInError`. The generated files match the hand-written ARB values; no missing override would throw at runtime.
- **Dead channel fully removed, no dangling references:** `_authErrorSubject`, `authErrorStream` getter, its `.close()`, the `GlobalListeners` field/subscription/`initState` listen/`dispose` cancel, and the `App.dart` constructor argument are all gone. A repo grep for `authErrorStream` over `lib/` and `test/` returns nothing. The obsolete `group('authErrorStream', …)` test block is deleted with no other test referencing it.
- **Guards honored:** OTP methods, `OtpLockedException`/`OtpSendCooldownException`, the `'Сессия истекла'` snackbar, and `sessionExpiredStream` plumbing are all untouched. Cancel stays silent. Exactly two enum cases added.
- **No surviving test depends on the changed behavior:** the `UserNotifier_test` fake's `getGoogleServerAuthCode` returns success and there is no remaining `loginWithGoogle` test, so the Phase-1 try/catch removal breaks nothing. `UserRepository_test` still asserts `getGoogleServerAuthCode` propagates `GoogleSignInCanceledException`, which the new code still does.

## Minor observations (non-blocking)

1. **GMS-level user cancel still bounces through the browser flow.** In `google_sign_in` 7.x a user dismissing the GMS sheet throws `GoogleSignInException(code: canceled)`; `_isNetworkError` returns false, so the `else` branch runs `_browserFlow()` and the user must cancel a second time before `GoogleSignInCanceledException` is produced. This is **pre-existing** behavior (previously *any* GMS exception fell to the browser) and out of scope for this milestone. Optional future cleanup: short-circuit `GoogleSignInExceptionCode.canceled` to `throw GoogleSignInCanceledException()`.

2. **`_isNetworkError` depends on `description` substring matching** (`'network error'` / `'[7]'`). This is acknowledged in the code comment and confined to a single helper. The `[7]` status token (Android `NETWORK_ERROR`) is the more durable anchor; the human-readable string could drift across plugin versions. Acceptable as the documented single string-matching seam.

3. **Determinism fix assumes offline surfaces as a thrown `GoogleSignInException`, not a null return.** If `authorizeServer` ever returned `null` while offline, `_gmsFlow` throws a generic `Exception` that hits the trailing `catch` → `_browserFlow()`, reintroducing the ambiguous-cancel path for that case. Per the verified SDK behavior (network failure → `GoogleSignInException(unknownError)`) this does not occur, so it is a low-confidence edge note only.

None of the above changes behavior incorrectly or breaks the build.

REVIEW_PASS
