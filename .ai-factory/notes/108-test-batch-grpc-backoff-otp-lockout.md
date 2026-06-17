# GrpcConnectionManager Backoff + OTP Lockout — Test Batch

**Date:** 2026-06-17
**Source:** roadmap-decompose

## Key Findings

- Two auth/infra test areas that can be written in one pass: `GrpcConnectionManager` backoff (new file) and OTP lockout paths in `AuthCodeDeeplinkHandler` + `LoginViewModel` (extend existing + new file).
- `GrpcConnectionManager` now accepts injectable `BackoffConfig` and `TimerFactory` (added in Test Infra phase) — no further refactor needed. Use a timer spy to capture scheduled delays without real timers.
- `AuthCodeDeeplinkHandler` now accepts injectable `onError` callback (added in Test Infra phase); the existing test file already exercises it. This batch extends it with the OTP lockout vs generic-error distinction.
- Both have zero test coverage for the specific logic in scope.

## Details

### File 1: `test/Core/Grpc/grpc_connection_manager_backoff_test.dart` (new)

**Source:** `lib/Core/Grpc/GrpcConnectionManager.dart`
**Research note:** `.ai-factory/notes/95-test-plan-grpc-backoff.md`

Instantiation:
```dart
GrpcConnectionManager(
  authStream: authCtrl.stream,
  connectivityStream: connectCtrl.stream,
  resumeStream: resumeCtrl.stream,
  backoffConfig: BackoffConfig(
    initialDelay: Duration(milliseconds: 10),
    maxDelay: Duration(milliseconds: 100),
    random: Random(0),
  ),
  timerFactory: (d, cb) { timers.add((delay: d, callback: cb)); return FakeTimer(); },
)
```

Emit `AuthenticatedState` on `authCtrl` before calling `scheduleReconnect()` so `_isAuthenticated == true`.

Key test groups (summary — full spec in note 95):
1. **Delay progression** — after 0–8 `scheduleReconnect()` calls, captured `timers[i].delay` values are monotonically non-decreasing up to 100 ms cap; attempt 6 == attempt 7 (exponent cap at `min(attempt, 6)`); no delay is negative.
2. **Overflow guard** — 100 consecutive `scheduleReconnect()` calls complete without exception.
3. **`confirmConnected()` reset** — after 4 attempts, `confirmConnected()` resets counter; next `scheduleReconnect()` delay equals attempt-0 value.
4. **No schedule when unauthenticated** — `scheduleReconnect()` while unauthenticated does not add a timer to the spy.

---

### Files 2a + 2b: Extend existing + new OTP lockout tests

**Source:** `lib/Core/Handlers/AuthCodeDeeplinkHandler.dart`, `lib/User/LoginViewModel.dart`
**Research note:** `.ai-factory/notes/97-test-plan-otp-lockout.md`

**File 2a: Extend `test/Core/Handlers/auth_code_deeplink_handler_test.dart` (existing)**

The file already tests the happy path and generic error. Add to the `error handling` group:
- Configure `FakeUserRepository.completePasswordlessSignIn` to throw `OtpLockedException`.
- Call `handler.handle(validUri)` with injected `onError` capture.
- Assert: returns `true`; captured event carries `loginTooManyAttemptsError`.
- Assert: generic `Exception` still produces `loginCodeInvalidError` (existing test covers this, but run as a regression check).

**File 2b: `test/User/login_view_model_lockout_test.dart` (new)**

Target: `LoginViewModel.verifyCode()` OTP lockout and generic-error paths.
Fake: `_FakeLoginService` implementing `ILoginService`, injectable `Exception?` to throw.

Test groups:
1. **OTP lockout** — `_FakeLoginService` throws `OtpLockedException`; assert `isLoading = false` and `onErrorEvent` fires with `LoginError.tooManyAttempts`.
2. **Generic error** — throws `Exception('boom')`; assert `onErrorEvent` fires with `LoginError.codeInvalidOrExpired`.
