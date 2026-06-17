## Plan Review: GrpcConnectionManager backoff and OTP lockout tests

**Plan:** `38-grpcconnectionmanager-backoff-and-otp-lockout-tests.md`
**Scope:** Test-only (3 spec files), no production changes
**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md** — WARN (none): test-only plan, no production code or module boundaries touched. No alignment issues.
- **RULES.md** — PASS: rules target Module Service statelessness, App.dart purity, and constructor injection. The plan adds no production code and uses the already-injected seams (`BackoffConfig` + `TimerFactory`, `onError`, `ILoginService`), consistent with the constructor-injection rule.
- **ROADMAP_TESTS.md** — PASS: the plan maps 1:1 to the roadmap item "GrpcConnectionManager backoff and OTP lockout tests" (line 21), matching the prescribed `BackoffConfig(10ms, 100ms, Random(0))` + TimerFactory spy, the three file targets, and the two error paths. Good linkage.

### Verification Against Codebase

All assumptions were checked against source:

- **`GrpcConnectionManager`** — constructor signature (`authStream`, `connectivityStream`, `resumeStream`, `backoffConfig`, `timerFactory`), `scheduleReconnect()`, `confirmConnected()`, `dispose()`, and the `_nextDelay()` math (`min(attempt,6)`, clamp to `maxDelay`, ±25% jitter, `clamp(0, maxDelay)`, attempt increment *after* compute) all match the plan exactly. ✔
- The plan's claim that `AuthenticatedState` triggers a synchronous `connect()` with **no** timer is correct — `connect()` never touches `_timerFactory`, so it will not pollute the `timers` spy. ✔
- `_scheduleReconnectInternal()` returns early when `!_isAuthenticated` — Task 4's "no schedule when unauthenticated" assertions are valid. ✔
- **`TimerFactory`** typedef is `Timer Function(Duration, void Function())` — the plan's `timerFactory: (d, cb) {...}` signature and `FakeTimer implements Timer` stub are correct. ✔
- **`AuthCodeDeeplinkHandler`** — `OtpLockedException` → `loginTooManyAttemptsError`, generic `catch` → `loginCodeInvalidError`, `onError` callback emitting `SnackBarEvent.error`. The existing test file already contains both error-handling cases (`OTP lockout shows loginTooManyAttemptsError snackbar`, `generic error shows loginCodeInvalidError snackbar`) asserting `type == SnackBarType.error` and the exact messages. Task 5's "verify, don't duplicate" instruction is correct and the cases already pass. ✔
- **`LoginViewModel.verifyCode()`** — `OtpLockedException` → `LoginError.tooManyAttempts`, generic → `LoginError.codeInvalidOrExpired`, success sets `isLoading=false` with no error. The `LoginError` enum has both values. `ILoginService` interface methods (`observeAuthState`, `observeAuthInProgress`, `completePasswordlessSignIn`, `sendPasswordlessSignInLink`, `loginWithGoogle`) match the planned `_FakeLoginService`. ✔
- `loginViewModelProvider` is a `NotifierProvider<LoginViewModel, LoginState>`; `overrideWith(() => vm)` + `read(...notifier)` to trigger `build()` is the correct Riverpod wiring. `const Stream.empty()` is a valid const factory for the fake's stream getters. ✔
- **`OtpLockedException`** has a `const` constructor — `const OtpLockedException()` in Task 6 is valid. ✔
- No existing `LoginViewModel`/`verifyCode` test exists, so `test/User/login_view_model_lockout_test.dart` does not duplicate anything. `test/User/Presentation/` is empty. ✔

### Minor Notes (non-blocking)

1. **Task 1 jitter monotonicity** — "non-decreasing delay sequence across attempts 0–8" is not strictly guaranteed by the production code. With ±25% jitter, the attempt-3 band (nominal 80ms → [60,100]) overlaps the attempt-4 band (nominal 100ms clamped → [75,100]), so a literal `timers[i] >= timers[i-1]` assertion could be flaky even with `Random(0)`. The plan already flags this ("within jitter tolerance", "Assert on ranges/ordering, not exact ms"), so the intent is sound — the implementer must assert per-attempt jitter *bands* (or a tolerance), not raw pairwise ordering. `Random(0)` is deterministic so values are reproducible regardless. Keep this caveat front-of-mind when writing Task 1.

2. **File placement (cosmetic)** — `test/User/login_view_model_lockout_test.dart` sits directly under `test/User/` rather than mirroring source layout (`test/User/Presentation/Login/`). The roadmap prescribes this exact path, so it's intentional and consistent — no change needed.

3. **Task 3 reset assertion** — comparing the post-`confirmConnected()` delay to the very first delay: both are attempt-0 nominally (10ms) but draw *different* jitter values because `Random(0)` advances on each `_nextDelay()` call. The plan correctly says to assert band membership, not equality. Good.

### Positive Notes

- Excellent pre-flight diligence: the "Shared Setup Notes" section pre-solves the two real footguns (async stream delivery requiring `await Future.delayed(Duration.zero)` before `scheduleReconnect`, and the `FakeTimer` needing a safe `cancel()`), which are exactly the issues that would otherwise surface during implementation.
- Correctly identifies that no production refactor is needed — all seams already exist — keeping the change test-only.
- Task 5 explicitly guards against duplicating already-passing cases, which is the right call given the existing file already covers both error paths.
- Teardown discipline (dispose manager + close all controllers; dispose container) is specified, preventing leaked subscriptions across tests.

PLAN_REVIEW_PASS
