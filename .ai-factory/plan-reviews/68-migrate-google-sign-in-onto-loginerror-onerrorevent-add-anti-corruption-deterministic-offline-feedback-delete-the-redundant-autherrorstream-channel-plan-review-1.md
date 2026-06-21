# Plan Review: Migrate Google Sign-In onto LoginError/onErrorEvent + delete authErrorStream

**Plan:** `68-migrate-google-sign-in-onto-loginerror-onerrorevent-...md`
**Risk Level:** 🟢 Low — accurate, well-scoped, line references verified

## Verification Summary

Every file path, line number, and API assumption in the plan was checked against the live codebase. All are correct:

- `UserNotifier.dart` — `_authErrorSubject` (line 19), `authErrorStream` getter (line 39), `.close()` (line 119), the Phase 1 `on GoogleSignInCanceledException { return; }` swallow (lines 68–70), and the Phase 2 `_authErrorSubject.add(...)` (line 80) all exist exactly as described.
- `App.dart:302` — `authErrorStream: App.shared.userNotifier.authErrorStream` present.
- `GlobalListeners.dart` — field/subscription/listen/dispose + doc-comment line ("Auth errors via [authErrorStream]") all present.
- `LoginViewModel.dart:85–87` — the stale "already published to authErrorStream" comment exists; the file already imports `GoogleSignInCanceledException`, `OtpLockedException`, `OtpSendCooldownException` (so adding `NoConnectionException` is consistent).
- Both screens use an **exhaustive** `switch (error)` with no `default` (Onboarding 31–36, Login 32–37) — confirming the plan's note that both must be updated together or the build breaks.
- ARB files: `loginSendCodeError` family present in both `app_en.arb`/`app_ru.arb` at the referenced style.
- Test file: `group('authErrorStream', ...)` is a self-contained block (lines 195–234); all three tests reference `userNotifier.authErrorStream` and would fail to compile after the getter is deleted — deletion is correct, and they do not overlap the `completePasswordlessSignIn`/OTP groups.
- `docs/core/global-listeners.md:20` — the `authErrorStream` table row exists.
- **No orphaned consumers:** a full repo grep for `authErrorStream` / `_authErrorSubject` returns only the sites the plan touches. `NoConnectionException` does not yet exist anywhere (Task 1 introduces it cleanly).

**`google_sign_in` API assumptions confirmed** (`^7.2.0`, platform-interface 3.1.0):
- `GoogleSignInException` exists with `code` (`GoogleSignInExceptionCode`), `description` (`String?`), and `details`.
- `GoogleSignInExceptionCode.unknownError` exists — the plan is correct that the network case surfaces as `unknownError` (not a network-specific code), justifying the `description` string match.
- The enum's own doc explicitly warns codes are non-exhaustive and clients "should always include a default/fallback" — the plan's trailing generic `catch` honors this.

## Context Gates

- **Architecture (`ARCHITECTURE.md`):** WARN (non-blocking) — the rule "ViewModel must NOT import domain models" does not apply here. The `User` feature lives in `lib/`, not as an extracted package (unlike `breath_module`), and the ViewModel already imports domain exceptions from `lib/User/Models/`. Adding `NoConnectionException` follows the established pattern. No violation.
- **Rules (`RULES.md`):** PASS — no module-Service state added; `App.dart` change is a pure removal (does not add module state); DI/construction untouched.
- **Roadmap (`ROADMAP.md`):** WARN — this is fix/refactor work but the plan declares no ROADMAP milestone linkage. Consider adding a phase entry for traceability (consistent with how prior fixes like notes 69/70/82 are logged).

## Critical Issues

None. The plan is implementable as written.

## Minor Observations (non-blocking)

1. **`_isNetworkError` heuristic fragility (acknowledged).** Matching `description` on `'network error'` / `'[7]'` is a string seam. `description` is a human-readable SDK string and could in principle change across plugin versions; the `[7]` status token is the more durable signal (Android `GoogleSignInStatusCodes.NETWORK_ERROR == 7`). The plan already isolates this to one commented helper — acceptable. Worth keeping the `[7]` match as the primary anchor.

2. **GMS-level user cancel falls through to the browser flow.** In `google_sign_in` 7.x a user dismissing the GMS sheet throws `GoogleSignInException(code: canceled)`, not a `PlatformException`. Under the plan's branching, `canceled` is not network → the `else` branch runs `_browserFlow()`, so a GMS cancel re-opens the browser auth before the user can finally cancel there (→ `PlatformException CANCELED` → `GoogleSignInCanceledException`). This is **pre-existing behavior** (today *any* GMS exception falls to the browser), not a regression introduced by this plan, and is out of scope (network determinism). Optional future improvement: short-circuit `GoogleSignInExceptionCode.canceled` to `throw GoogleSignInCanceledException()` to avoid the browser bounce on cancel.

3. **Exception-ordering reminder for Task 2.** The `on GoogleSignInException catch (e)` clause must precede the trailing generic `catch (e)` in `getServerAuthCode()`, otherwise the network branch is unreachable. The plan implies this ordering; just ensure it during implementation.

## Positive Notes

- The error-propagation chain is sound end-to-end: `GoogleAuthProvider` (anti-corruption) → `UserRepository.getGoogleServerAuthCode` (pass-through) → `UserNotifier.loginWithGoogle` (rethrow, no Phase-1 try/catch) → `LoginService` (await pass-through) → `LoginViewModel` (`on`-clause mapping to `onErrorEvent`). Calling `getGoogleServerAuthCode()` outside the spinner try/catch correctly lets Phase-1 exceptions reach the ViewModel.
- Making `loginWithGoogle` structurally mirror `completePasswordlessSignIn`/`verifyCode` is the right convergence — it removes a bespoke global channel in favor of the screen-local pipeline already proven for OTP.
- Determinism fix (skip browser fallback on network error) targets the real root cause: the offline browser fallback returning an ambiguous `CANCELED` swallowed as a fake user-cancel.
- Two enum cases only (`noConnection`, `googleSignInFailed`) — no speculative surface. Commit plan is logically staged so each commit compiles.
- Task 9 correctly keeps `sessionExpiredStream` and the "Сессия истекла" snackbar intact while removing only the dead channel.

PLAN_REVIEW_PASS
