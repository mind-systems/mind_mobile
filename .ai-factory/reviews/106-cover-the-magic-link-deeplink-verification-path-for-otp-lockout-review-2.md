# Code Review #2 — Cover the magic-link/deeplink verification path for OTP lockout

**Plan:** `106-cover-the-magic-link-deeplink-verification-path-for-otp-lockout.md`
**Changed source files:** `lib/User/UserNotifier.dart`, `lib/Core/Handlers/AuthCodeDeeplinkHandler.dart`, `test/User/UserNotifier_test.dart`, `docs/user/login-flow.md`
**Risk Level:** 🟢 Low

## Resolution of review #1 findings

- **Critical #1 (failing test) — RESOLVED.** `test/User/UserNotifier_test.dart:196` was rewritten from `emits error string when completePasswordlessSignIn fails` to `does NOT emit when completePasswordlessSignIn fails`, now asserting `errors` is empty with the correct rationale. The suite is green again — ran `flutter test test/User/UserNotifier_test.dart`: **All tests passed (17)**, including the three `authErrorStream` cases.
- **Minor #2 (stale doc) — RESOLVED.** `docs/user/login-flow.md:32` now accurately describes the new behavior: the deeplink failure path shows a localized snackbar directly via `AuthCodeDeeplinkHandler`/`rootScaffoldMessengerKey` (`loginTooManyAttemptsError` on lockout, `loginCodeInvalidError` otherwise), no longer routing through `authErrorStream`.
- **Cosmetic #3 (unused catch variable) — RESOLVED.** The `UserNotifier` catch is now `} catch (_) {`.

## Verification performed

- `flutter analyze` on all three changed source/test files: **No issues found.**
- `flutter test test/User/UserNotifier_test.dart`: **17/17 passed.**
- Re-confirmed the interactive path still surfaces its own localized message (`LoginViewModel.verifyCode` → `LoginService.completePasswordlessSignIn` → `UserNotifier`, errors rendered via `onErrorEvent`), so dropping the publish loses no user-facing message.
- `loginWithGoogle`'s separate `authErrorStream` publish is untouched; `GlobalListeners` remains its presenter.
- Deeplink handler: typed `on OtpLockedException` precedes the generic `catch (_)`; both swallow and return `true`, so nothing escapes to `DeeplinkRouter`'s un-try/caught `await`. Null-context guard is a real early-return, not a bang.

## Findings

None.

REVIEW_PASS
