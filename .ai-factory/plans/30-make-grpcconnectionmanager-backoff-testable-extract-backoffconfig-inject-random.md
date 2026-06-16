# Plan: Make `GrpcConnectionManager` backoff testable: extract `BackoffConfig` + inject `Random`

## Context
Make the reconnect backoff in `GrpcConnectionManager` deterministically testable by extracting a `BackoffConfig` value object (overridable `initialDelay`/`maxDelay` + injectable `Random`) and an injectable `TimerFactory`, all as optional constructor parameters that default to the current production values. No production behavior change.

## Settings
- Testing: no
- Logging: minimal

## Scope note
This milestone is the **refactor only** — it enables deterministic testing. Writing the actual backoff tests is a separate downstream milestone (`GrpcConnectionManager backoff tests` in `.ai-factory/ROADMAP_TESTS.md`, which lists this refactor as its prerequisite). Do **not** create test files here.

## Tasks

### Phase 1: Refactor for injectability

- [x] **Task 1: Create `BackoffConfig` value object + `TimerFactory` typedef**
  Files: `lib/Core/Grpc/BackoffConfig.dart`
  Create a new file declaring:
  - `typedef TimerFactory = Timer Function(Duration duration, void Function() callback);`
  - A `BackoffConfig` class with three final fields: `Duration initialDelay`, `Duration maxDelay`, `Random random`.
  - Constructor `BackoffConfig({Duration initialDelay = const Duration(seconds: 1), Duration maxDelay = const Duration(seconds: 30), Random? random})` that assigns `random = random ?? Random()` in the initializer list (defaults exactly match the current `static const _initialDelay`/`_maxDelay`).
  - The constructor cannot be `const` because `Random()` is not a const expression — that is intentional; consumers pass a seeded `Random(0)` in tests for deterministic jitter.
  Imports needed: `dart:async` (Timer), `dart:math` (Random). Keep the file pure Dart — no Flutter imports.

- [x] **Task 2: Wire `BackoffConfig` + `TimerFactory` into `GrpcConnectionManager`** (depends on Task 1)
  Files: `lib/Core/Grpc/GrpcConnectionManager.dart`
  - Import `BackoffConfig.dart`.
  - Remove the two `static const Duration _initialDelay` / `_maxDelay` fields (lines 32–33).
  - Add two final instance fields: `final BackoffConfig _backoffConfig;` and `final TimerFactory _timerFactory;`.
  - Add two **optional** named constructor parameters: `BackoffConfig? backoffConfig` and `TimerFactory? timerFactory`. Assign them in the initializer list (before the constructor body that sets up subscriptions): `_backoffConfig = backoffConfig ?? BackoffConfig(), _timerFactory = timerFactory ?? Timer.new`. Keep the three existing required stream params unchanged so the `App.dart` call site (line 200) and all callers remain source-compatible.
  - In `_nextDelay()`: replace `_initialDelay` → `_backoffConfig.initialDelay`, `_maxDelay` → `_backoffConfig.maxDelay` (both occurrences — the clamp and the final `.clamp(0, _maxDelay.inMilliseconds)`), and `math.Random().nextDouble()` → `_backoffConfig.random.nextDouble()`. Backoff math (exponent cap `math.min(_reconnectAttempt, 6)`, ±25% jitter, lower/upper clamp, `_reconnectAttempt++`) stays identical.
  - In `_scheduleReconnectInternal()`: replace the inline `Timer(delay, () { if (_isAuthenticated) connect(); })` with `_timerFactory(delay, () { if (_isAuthenticated) connect(); })`. The `_reconnectTimer?.cancel()` and `_reconnectTimer = ...` assignment behavior stays the same.
  - `dart:math as math` is still used by `_nextDelay()` (`math.min`, `math.pow`), so keep that import; `dart:async` is already imported for `Timer`.

### Phase 2: Verify no production behavior change

- [x] **Task 3: Confirm call site + analyzer** (depends on Task 2)
  Files: `lib/Core/App.dart`
  Verify the existing construction at `App.dart:200` still compiles unchanged (it passes only the three required streams; the new params default to production values). Run `flutter analyze` (use `/usr/local/bin/flutter`) on the changed files and confirm zero new warnings/errors. No code edits expected here unless the analyzer flags something.
