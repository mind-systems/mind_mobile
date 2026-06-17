# Test Plan: GrpcConnectionManager backoff and OTP lockout tests

## Context
Two untested auth/infra areas: exponential-backoff scheduling in `lib/Core/Grpc/GrpcConnectionManager.dart`, and the `OtpLockedException` vs generic-error distinction in `lib/Core/Handlers/AuthCodeDeeplinkHandler.dart` and `lib/User/Presentation/Login/LoginViewModel.dart`. Both target classes already accept the injectable seams needed (`BackoffConfig` + `TimerFactory`, `onError` callback, `ILoginService`), so no production refactor is required — only tests.

## Settings
- Testing: yes
- Logging: minimal
- Docs: no

## Test Command
`/usr/local/bin/flutter test test/Core/Grpc/grpc_connection_manager_backoff_test.dart test/Core/Handlers/auth_code_deeplink_handler_test.dart test/User/login_view_model_lockout_test.dart`

## Target Spec Files
- `test/Core/Grpc/grpc_connection_manager_backoff_test.dart` (new)
- `test/Core/Handlers/auth_code_deeplink_handler_test.dart` (extend existing — likely already covered, verify first)
- `test/User/login_view_model_lockout_test.dart` (new)

---

## Shared Setup Notes (read before writing)

**GrpcConnectionManager**
- Constructor needs three streams plus the two injectable params:
  ```dart
  final authCtrl = StreamController<AuthState>.broadcast();
  final connectCtrl = StreamController<List<ConnectivityResult>>.broadcast();
  final resumeCtrl = StreamController<void>.broadcast();
  final timers = <({Duration delay, void Function() callback})>[];

  manager = GrpcConnectionManager(
    authStream: authCtrl.stream,
    connectivityStream: connectCtrl.stream,
    resumeStream: resumeCtrl.stream,
    backoffConfig: BackoffConfig(
      initialDelay: const Duration(milliseconds: 10),
      maxDelay: const Duration(milliseconds: 100),
      random: Random(0),
    ),
    timerFactory: (d, cb) { timers.add((delay: d, callback: cb)); return FakeTimer(); },
  );
  ```
- `FakeTimer` is a minimal `implements Timer` stub (`cancel()` no-op, `tick => 0`, `isActive => true`) so `_reconnectTimer?.cancel()` is safe.
- `_isAuthenticated` is set only by the auth-stream listener. Emit `AuthenticatedState` on `authCtrl` **and await `Future.delayed(Duration.zero)`** before calling `scheduleReconnect()`, because stream delivery is async. Emitting `AuthenticatedState` also calls `connect()` synchronously (no timer), so it does not pollute the `timers` spy.
- Inspect `timers[i].delay` to assert scheduled durations; `timers.length` to assert that nothing was scheduled.
- Computed expected delays with `initialDelay=10ms`, `maxDelay=100ms`: base = `10 * 2^min(attempt,6)` then clamped to ≤100, then ±25% jitter, then `clamp(0, 100)`. Nominal base per attempt before jitter: 0→10, 1→20, 2→40, 3→80, 4→100 (clamped), 5→100, 6→100, 7→100. Assert on ranges/ordering, not exact ms (jitter applies even with `Random(0)`).
- `dispose()` the manager and close all three controllers in `tearDown`.

**LoginViewModel** (Riverpod `Notifier<LoginState>`)
- Build a `_FakeLoginService implements ILoginService`:
  - `observeAuthState()` → `const Stream<AuthState>.empty()`
  - `observeAuthInProgress()` → `const Stream<bool>.empty()`
  - `completePasswordlessSignIn(code)` → records `code`; throws `exceptionToThrow` if set, else completes normally
  - `sendPasswordlessSignInLink` / `loginWithGoogle` → no-op
- Wire via `ProviderContainer(overrides: [loginViewModelProvider.overrideWith(() => vm)])`, then `container.read(loginViewModelProvider.notifier)` to trigger `build()`. Assign `vm.onErrorEvent = capturedErrors.add` (capture `List<LoginError>`). Read state via `container.read(loginViewModelProvider)`.
- `dispose()` the container in `tearDown`.

---

## Tasks

### Phase 1: GrpcConnectionManager — backoff scheduling (new file)

- [x] **Task 1: Delay progression**
  Files: `test/Core/Grpc/grpc_connection_manager_backoff_test.dart`
  Test cases:
  - `should schedule a non-decreasing delay sequence across attempts 0–8` (each captured `timers[i].delay` ≥ previous within jitter tolerance, trending up to the cap)
  - `should cap the exponent at 6 so attempt 6 and attempt 7 produce equal nominal delays` (both clamped to maxDelay)
  - `should clamp every scheduled delay to maxDelay when 100ms ceiling is reached` (no delay exceeds 100ms)
  - `should never schedule a negative delay` (every `timers[i].delay` ≥ Duration.zero)

- [x] **Task 2: Overflow guard**
  Files: `test/Core/Grpc/grpc_connection_manager_backoff_test.dart`
  Test cases:
  - `should complete 100 consecutive scheduleReconnect() calls without throwing` (loop 100×; assert no exception and all captured delays ≤ maxDelay)

- [x] **Task 3: confirmConnected() resets backoff**
  Files: `test/Core/Grpc/grpc_connection_manager_backoff_test.dart`
  Test cases:
  - `should reset the attempt counter so the next delay matches the attempt-0 delay after confirmConnected()` (call `scheduleReconnect()` 4×, record first delay; call `confirmConnected()`; call `scheduleReconnect()` again; assert new delay is within the attempt-0 jitter band, not the escalated value)

- [x] **Task 4: No schedule when unauthenticated**
  Files: `test/Core/Grpc/grpc_connection_manager_backoff_test.dart`
  Test cases:
  - `should not schedule a timer when scheduleReconnect() is called before any AuthenticatedState` (`timers` stays empty)
  - `should not schedule a timer after GuestState is emitted` (emit `AuthenticatedState`, then `GuestState`, await delivery, call `scheduleReconnect()`; assert no new timer added beyond what auth transitions produced)

### Phase 2: AuthCodeDeeplinkHandler — OTP lockout vs generic error (extend existing)

- [x] **Task 5: Verify / complete the `error handling` group**
  Files: `test/Core/Handlers/auth_code_deeplink_handler_test.dart`
  Note: the existing file's `error handling` group already contains both cases below (set `fakeRepo.exceptionToThrow`, assert captured `SnackBarEvent`). **Confirm they exist and pass; only add a case if one is missing — do not duplicate.**
  Test cases:
  - `should return true and emit loginTooManyAttemptsError when completePasswordlessSignIn throws OtpLockedException` (captured event `type == SnackBarType.error`, `message == AppLocalizationsEn().loginTooManyAttemptsError`)
  - `should return true and emit loginCodeInvalidError when completePasswordlessSignIn throws a generic Exception` (captured `message == AppLocalizationsEn().loginCodeInvalidError`)

### Phase 3: LoginViewModel — verifyCode lockout vs generic error (new file)

- [x] **Task 6: verifyCode error paths**
  Files: `test/User/login_view_model_lockout_test.dart`
  Test cases:
  - `should set isLoading=false and emit LoginError.tooManyAttempts when verifyCode throws OtpLockedException` (fake throws `const OtpLockedException()`; after `await vm.verifyCode('code')`, state.isLoading is false and `capturedErrors` == `[LoginError.tooManyAttempts]`)
  - `should set isLoading=false and emit LoginError.codeInvalidOrExpired when verifyCode throws a generic Exception` (fake throws `Exception('boom')`; `capturedErrors` == `[LoginError.codeInvalidOrExpired]`)
  - `should set isLoading=false and emit no error when verifyCode succeeds` (fake completes normally; state.isLoading false, `capturedErrors` is empty — covers the success branch at the start of the try block)
