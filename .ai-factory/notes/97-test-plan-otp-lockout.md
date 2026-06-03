# OTP Lockout Code Distinction — Test Plan

**Date:** 2026-06-03
**Source:** roadmap-test-coverage agent

## Source Overview

The codebase has two paths for passwordless sign-in: (1) **interactive login** via `LoginViewModel.verifyCode()` which calls `ILoginService.completePasswordlessSignIn()`, and (2) **magic-link deeplink** via `AuthCodeDeeplinkHandler.handle()` which calls `UserNotifier.completePasswordlessSignIn()`. Both paths eventually call `AuthApi.verifyCode()`, which catches gRPC `RESOURCE_EXHAUSTED` status code and throws a domain-specific `OtpLockedException`. The two handlers distinguish this exception from other failures and emit different error signals: the deeplink handler shows a localized snackbar ("loginTooManyAttemptsError"), while LoginViewModel notifies the UI with `LoginError.tooManyAttempts`.

## Instantiation

### OtpLockedException
```dart
const OtpLockedException()
```

### FakeUserRepository Setup
Extend the existing `FakeUserRepository` in the test file to support throwable exceptions:

```dart
class FakeUserRepository implements UserRepository {
  Exception? exceptionToThrow;
  
  @override
  Future<User> completePasswordlessSignIn(String code, {String? language}) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    // ... happy path
  }
}
```

Alternatively, create a `FakeAuthApi` that throws `OtpLockedException` on `verifyCode()`:

```dart
class FakeAuthApi implements IAuthApi {
  Exception? exceptionToThrow;
  
  @override
  Future<User> verifyCode({required String email, required String code, String? language}) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return User(...);
  }
}
```

## Existing Coverage

The existing `auth_code_deeplink_handler_test.dart` covers:
- Valid URI parsing (https and custom scheme)
- Invalid host rejection
- Invalid path rejection
- Missing code parameter
- Empty code parameter
- Happy path: valid URI with valid code, passes code to UserNotifier and returns `true`

**What is NOT covered:**
- OtpLockedException thrown during `completePasswordlessSignIn()`
- Snackbar display on lockout
- Code distinction between lockout and other errors (currently only the happy path is tested)

## Test Cases

### Deeplink Handler Path (`AuthCodeDeeplinkHandler`)

#### Group: OTP Lockout on Deeplink

**Test 1: should show "loginTooManyAttemptsError" snackbar and return true when completePasswordlessSignIn throws OtpLockedException**
- **Exercises:** `AuthCodeDeeplinkHandler.handle()` (line 28–32)
- **Setup:**
  - FakeUserRepository configured to throw `OtpLockedException` on `completePasswordlessSignIn(code)`
  - Provide a valid deeplink URI: `https://dev.mind-awake.life/deeplink-auth?code=123456`
  - Mock `rootScaffoldMessengerKey.currentState` to capture snackbar calls
- **Assertion:**
  - Handler returns `true`
  - `rootScaffoldMessengerKey.currentState?.showSnackBar()` was called exactly once
  - The SnackBarEvent passed is an error event
  - The error message is the localized "loginTooManyAttemptsError" string
- **Note:** Tests the catch clause at line 30–32; ensures lockout is visually distinct from other errors (line 33–35).

**Test 2: should show "loginCodeInvalidError" snackbar when completePasswordlessSignIn throws generic Exception (not OtpLockedException)**
- **Exercises:** `AuthCodeDeeplinkHandler.handle()` (line 33–35)
- **Setup:**
  - FakeUserRepository configured to throw a generic `Exception("Some other error")`
  - Valid deeplink URI
  - Mock snackbar as above
- **Assertion:**
  - Handler returns `true`
  - The error message is the localized "loginCodeInvalidError" string (not lockout message)
- **Note:** Confirms that non-lockout exceptions are handled differently; validates the code path distinction.

---

### Interactive Login Path (`LoginViewModel`)

#### Group: OTP Lockout on Interactive Verify Code

**Test 3: should set isLoading to false and emit LoginError.tooManyAttempts when verifyCode throws OtpLockedException**
- **Exercises:** `LoginViewModel.verifyCode()` (line 64–77, specifically line 70–72)
- **Setup:**
  - ILoginService mock configured to throw `OtpLockedException` on `completePasswordlessSignIn(code)`
  - LoginViewModel with mocked service
  - Attach listener to `onErrorEvent` callback
  - Call `verifyCode("some-code")`
- **Assertion:**
  - Before exception: `state.isLoading` is `true`
  - After exception: `state.isLoading` is `false`
  - `onErrorEvent` callback was invoked exactly once with `LoginError.tooManyAttempts`
  - State is not changed to error-on-auth-state; only the callback fires (no error persistence in state)
- **Note:** The error is communicated via callback, not state mutation; the UI layer handles the snackbar separately.

**Test 4: should set isLoading to false and emit LoginError.codeInvalidOrExpired when verifyCode throws generic Exception (not OtpLockedException)**
- **Exercises:** `LoginViewModel.verifyCode()` (line 73–76)
- **Setup:**
  - ILoginService mock configured to throw a generic `Exception("Invalid code")`
  - LoginViewModel with mocked service
  - Attach listener to `onErrorEvent` callback
  - Call `verifyCode("some-code")`
- **Assertion:**
  - After exception: `state.isLoading` is `false`
  - `onErrorEvent` callback was invoked exactly once with `LoginError.codeInvalidOrExpired`
- **Note:** Confirms that non-lockout errors map to a different `LoginError` enum variant, enabling distinct UI messaging.

---

## Gotchas

### Double-Snackbar Guard
- **Problem:** Both the deeplink handler and any UI layer listening to LoginViewModel could show a snackbar if both paths catch the same exception.
- **Mitigation:** The deeplink handler invokes `completePasswordlessSignIn()` directly on `UserNotifier`, bypassing the `ILoginService` layer used by LoginViewModel. They are separate code paths and should not execute simultaneously. However, if the magic link arrives while the login screen is already showing an error, ensure the deeplink handler's snackbar doesn't stack on top.
- **Test strategy:** Use a mock `rootScaffoldMessengerKey` to verify only one snackbar is shown per handler invocation.

### DeeplinkRouter vs Direct Handler Invocation
- **Problem:** The deeplink handler is typically invoked by a `DeeplinkRouter` or similar routing layer, not directly by the login screen.
- **Mitigation:** Test the handler in isolation (as existing tests do), not as part of full navigation. If integration tests exist, verify that the snackbar is shown and navigation does not occur (or occurs correctly if lockout has auto-retry logic).

### Global Snackbar vs Login-Screen-Local Error
- **Problem:** The deeplink handler uses `rootScaffoldMessengerKey` to show a snackbar globally, while LoginViewModel communicates via a callback (which the UI then uses to show a local snackbar/dialog).
- **Mitigation:** These are intentionally different UX patterns:
  - Deeplink: User is not on the login screen, so a global snackbar is appropriate.
  - Login screen: User is actively typing a code, so a local error message (above the input or in a dialog) is more prominent.
- **Test strategy:** Mock the global key for deeplink tests; use a callback listener for LoginViewModel tests. Do not mix them.

### State Cleanup on Multiple Lockouts
- **Possible edge case:** If a user is locked out, the `isLoading` flag is set to `false`. If they click "Verify" again immediately, `isLoading` is set to `true` again before the next failure. Ensure state transitions are consistent.
- **Test strategy:** Call `verifyCode()` twice in a row and verify that error handling does not leave `isLoading` in an invalid state.

### AuthApi Translation Layer
- **Context:** `AuthApi.verifyCode()` (line 29–37 in AuthApi.dart) catches `GrpcError` and translates `StatusCode.resourceExhausted` to `OtpLockedException`. This translation happens once and is not mocked in LoginViewModel tests.
- **Test strategy:** For LoginViewModel tests, mock `ILoginService.completePasswordlessSignIn()` to throw `OtpLockedException` directly; do not test the gRPC layer translation in the ViewModel tests. If testing the full stack (AuthApi + ViewModel), use a mock `AuthServiceClient` or a fake gRPC stub.

## Refactor Required

`AuthCodeDeeplinkHandler._showLocalizedSnackBar` accesses `rootScaffoldMessengerKey` (a module-level global) directly. Tests cannot assert which error message was shown without spinning up a real widget tree with that key.

**What to refactor:** Add an optional `void Function(SnackBarEvent event) onError` constructor parameter:

```dart
class AuthCodeDeeplinkHandler {
  final UserNotifier userNotifier;
  final void Function(SnackBarEvent) _onError;

  AuthCodeDeeplinkHandler({
    required this.userNotifier,
    void Function(SnackBarEvent)? onError,
  }) : _onError = onError ?? _defaultOnError;

  static void _defaultOnError(SnackBarEvent event) {
    rootScaffoldMessengerKey.currentState?.showSnackBar(...);
  }
}
```

In tests, pass `onError: (event) => capturedEvents.add(event)` and assert on `capturedEvents`. The existing call site in `DeeplinkRouter` (or wherever the handler is constructed) passes no override, so production behavior is unchanged.
