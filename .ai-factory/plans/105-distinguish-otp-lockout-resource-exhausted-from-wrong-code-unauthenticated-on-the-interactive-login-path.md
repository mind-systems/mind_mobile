# Plan: Distinguish OTP lockout (`RESOURCE_EXHAUSTED`) from wrong code (`UNAUTHENTICATED`) on the interactive login path

## Context
Maps the new `VerifyCode` `RESOURCE_EXHAUSTED` brute-force lockout (and the `SendCode` 60s cooldown) to typed exceptions and dedicated `LoginError` recovery copy on the interactive login path, distinguishing strictly by gRPC status code and never auto-resending.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Domain exceptions

- [x] **Task 1: Add typed OTP exceptions**
  Files: `lib/User/Models/OtpLockedException.dart`, `lib/User/Models/OtpSendCooldownException.dart`
  Create two `Exception` classes mirroring the boundary pattern of `lib/User/Models/GoogleSignInCanceledException.dart` (const-constructible, doc comment explaining the meaning, `toString()` override). `OtpLockedException` represents the verify-code lockout after 5 wrong attempts (gRPC `RESOURCE_EXHAUSTED` on `VerifyCode`); `OtpSendCooldownException` represents the 60s send-code cooldown (gRPC `RESOURCE_EXHAUSTED` on `SendCode`). Both must support a `const` constructor so they can be thrown as `const`.

### Phase 2: API mapping

- [x] **Task 2: Translate `RESOURCE_EXHAUSTED` to typed exceptions in `AuthApi`** (depends on Task 1)
  Files: `lib/User/AuthApi.dart`
  Add `import 'package:grpc/grpc.dart';` (source of `GrpcError` / `StatusCode`, same as `lib/Core/Grpc/GrpcAuthInterceptor.dart`) and import the two new exception classes. Wrap the body of `verifyCode` in `try { ... } on GrpcError catch (e) { if (e.code == StatusCode.resourceExhausted) throw const OtpLockedException(); rethrow; }`. Do the same in `sendCode`, throwing `const OtpSendCooldownException()` instead. Distinguish strictly by `e.code` — never inspect `e.message` text. All other status codes (including `UNAUTHENTICATED` for a wrong code) must `rethrow` unchanged so existing fallback behavior is preserved. The typed exception then propagates cleanly through `UserRepository` (awaits) → `UserNotifier.completePasswordlessSignIn` (catches, publishes to error stream, rethrows) → `LoginService` (awaits) → `LoginViewModel`; no changes are needed in those intermediate layers.

### Phase 3: Presentation mapping

- [x] **Task 3: Extend the `LoginError` enum** (depends on Task 1)
  Files: `lib/User/Presentation/Login/Models/LoginState.dart`
  Add two values to the `LoginError` enum: `tooManyAttempts` (verify-code lockout) and `sendCodeCooldown` (send-code cooldown). Keep the existing `sendCodeFailed` and `codeInvalidOrExpired`.

- [x] **Task 4: Map typed exceptions to `LoginError` in the ViewModel** (depends on Task 2, Task 3)
  Files: `lib/User/Presentation/Login/LoginViewModel.dart`
  Import the two new exception classes. In `verifyCode`, replace the single generic `catch (e)` with a typed `on OtpLockedException { ... onErrorEvent?.call(LoginError.tooManyAttempts); }` branch followed by a generic `catch (_)` that still calls `LoginError.codeInvalidOrExpired`. In `sendPasswordlessSignInLink`, add `on OtpSendCooldownException { ... onErrorEvent?.call(LoginError.sendCodeCooldown); }` before the generic `catch (_)` that still calls `LoginError.sendCodeFailed`. Preserve the existing `state = state.copyWith(isLoading: false)` reset in every branch. Do NOT trigger any resend on lockout.

- [x] **Task 5: Add localized strings for the new errors** (depends on Task 3)
  Files: `packages/mind_l10n/lib/l10n/app_en.arb`, `packages/mind_l10n/lib/l10n/app_ru.arb`
  Add two keys next to the existing `loginSendCodeError` / `loginCodeInvalidError` entries.
  - `loginTooManyAttemptsError` — EN: "Too many attempts. Request a new code and try again in a few minutes." / RU: "Слишком много попыток. Запросите новый код и попробуйте через несколько минут."
  - `loginSendCodeCooldownError` — EN: "Please wait a moment before requesting another code." / RU: "Подождите немного перед повторным запросом кода."
  After editing the ARB files, regenerate localizations so `AppLocalizations` exposes the new getters (`flutter pub run build_runner build` is not used for l10n; run the project's localization generation — `/usr/local/bin/flutter gen-l10n` within `packages/mind_l10n`, or `flutter pub get` if the package is wired to generate on resolve).

- [x] **Task 6: Wire the new errors into both screen error switches** (depends on Task 3, Task 5)
  Files: `lib/User/Presentation/Login/LoginScreen.dart`, `lib/User/Presentation/Login/OnboardingScreen.dart`
  In each screen's `onErrorEvent` `switch (error)` block, add `LoginError.tooManyAttempts => l10n.loginTooManyAttemptsError` and `LoginError.sendCodeCooldown => l10n.loginSendCodeCooldownError`. Both switches are exhaustive over the enum, so all four cases must be present. No other behavior changes — the existing `AppAlert.show(...)` call surfaces the message.

## Commit Plan
- **Commit 1** (after tasks 1-2): "Map OTP RESOURCE_EXHAUSTED to typed auth exceptions"
- **Commit 2** (after tasks 3-6): "Surface OTP lockout and send-cooldown recovery copy on login"
