# Task Spec — Distinguish OTP lockout (`RESOURCE_EXHAUSTED`) from wrong code on the interactive login path

**Date:** 2026-05-31
**Roadmap:** ROADMAP.md Phase 27
**Provenance:** note 45 (mind_api Phase 27 cross-project requirement)

## Current state
`lib/User/AuthApi.dart` `verifyCode`/`sendCode` call the gRPC stubs and let any `GrpcError` propagate raw; `LoginViewModel.verifyCode` catches everything → `LoginError.codeInvalidOrExpired`, and `sendPasswordlessSignInLink` catches everything → `LoginError.sendCodeFailed`. The enum `LoginError` (`lib/User/Presentation/Login/Models/LoginState.dart`) has only those two values, mapped to messages in `LoginScreen.dart:33` and `OnboardingScreen.dart:32`.

## Backend change (mind_api Phase 27)
After 5 wrong codes the email is locked for 15 min → `VerifyCode` returns gRPC **`RESOURCE_EXHAUSTED`** (distinct from the wrong-code `UNAUTHENTICATED`). The existing `SendCode` 60s cooldown also returns `RESOURCE_EXHAUSTED`. Proto unchanged — no stub regen.

## Target
1. Add typed exceptions `OtpLockedException` and `OtpSendCooldownException` in `lib/User/Models/` (mirrors `GoogleSignInCanceledException` boundary pattern).
2. In `AuthApi`, wrap the two RPCs in `try/catch (GrpcError e)`:
   - `verifyCode`: `if (e.code == StatusCode.resourceExhausted) throw const OtpLockedException(); rethrow;`
   - `sendCode`: same but `throw const OtpSendCooldownException();`
   - The typed exception propagates cleanly — `UserRepository` awaits, `UserNotifier.completePasswordlessSignIn` catches→publishes→**rethrows**, `LoginService` awaits.
3. Add `LoginError.tooManyAttempts` + `LoginError.sendCodeCooldown` to the enum.
4. In `LoginViewModel.verifyCode` map `on OtpLockedException → LoginError.tooManyAttempts` else `codeInvalidOrExpired`; in `sendPasswordlessSignInLink` map `on OtpSendCooldownException → LoginError.sendCodeCooldown` else `sendCodeFailed`.
5. Map both new enum values to new l10n strings in BOTH `LoginScreen.dart` and `OnboardingScreen.dart` error switches; add keys to `packages/mind_l10n` ARB (EN: "Too many attempts. Request a new code and try again in a few minutes." / "Please wait a moment before requesting another code." — RU equivalents).

## Guards
- Distinguish strictly by gRPC status code, never by message text.
- Do NOT auto-resend a code on lockout — that defeats the server's brute-force control (note 45). The `tooManyAttempts` copy guides the user to request a fresh code; the `sendCodeCooldown` path then covers the 60s wait gracefully.
- Atomic: exception + enum values + VM mapping + l10n must ship together to be observable.
- The magic-link/deeplink path is a SEPARATE concern — note 59.

## Files
- new `lib/User/Models/OtpLockedException.dart`, `OtpSendCooldownException.dart`
- `lib/User/AuthApi.dart`
- `lib/User/Presentation/Login/Models/LoginState.dart`
- `lib/User/Presentation/Login/LoginViewModel.dart`
- `lib/User/Presentation/Login/LoginScreen.dart`, `OnboardingScreen.dart`
- `packages/mind_l10n` ARB files
