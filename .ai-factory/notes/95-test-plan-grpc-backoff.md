# GrpcConnectionManager Backoff — Test Plan

**Date:** 2026-06-03
**Source:** roadmap-test-coverage agent

## Source Overview

GrpcConnectionManager maintains a gRPC connection to a backend service with exponential backoff on reconnection failures. It tracks reconnect attempts, schedules retry timers based on exponential backoff with jitter, and resets the backoff counter when streams are confirmed open via `confirmConnected()`. The backoff is capped at 30 seconds and uses a ±25% jitter to avoid thundering herd on the server.

## Instantiation

Constructor signature (current — `BackoffConfig` and `TimerFactory` are now injectable):
```dart
GrpcConnectionManager({
  required Stream<AuthState> authStream,
  required Stream<List<ConnectivityResult>> connectivityStream,
  required Stream<void> resumeStream,
  BackoffConfig? backoffConfig,
  TimerFactory? timerFactory,   // TimerFactory = Timer Function(Duration, void Function())
})
```

For unit tests, **all three streams plus two injectable params** must be controlled:
- `authStream`: A `StreamController<AuthState>` emitting `AuthenticatedState` or `GuestState`. Emit `AuthenticatedState` to make `_isAuthenticated = true` (required before `scheduleReconnect()` fires a timer).
- `connectivityStream`: A `StreamController<List<ConnectivityResult>>` emitting connectivity states.
- `resumeStream`: A `StreamController<void>` for app lifecycle resume events.
- `backoffConfig`: Inject `BackoffConfig(initialDelay: Duration(milliseconds: 10), maxDelay: Duration(milliseconds: 100), random: Random(0))` for deterministic, fast delays.
- `timerFactory`: Inject a spy `List<({Duration delay, void Function() callback})> timers = []` so tests can capture scheduled delays and fire callbacks manually — avoids real `Timer` delays entirely.

**Recommended approach:** inject a `TimerFactory` spy. Call `scheduleReconnect()` (public wrapper for `_scheduleReconnectInternal()`), then inspect `timers.last.delay` to assert the scheduled duration. Fire `timers.last.callback()` to simulate a timer firing. This avoids `fake_async` complexity while giving full control over timing.

## Existing Coverage

None for backoff logic. Backoff logic is entirely untested.

## Test Cases

### Backoff Calculation (_nextDelay)

- **should return 1s on first attempt when attempt=0**
  - Exercises: `_nextDelay()` at start
  - Setup: `_reconnectAttempt = 0` (initial state)
  - Expected: `1000ms ± 250ms` (jitter range)
  - Notes: Jitter is ±25% = ±250ms on 1000ms base

- **should double delay on each attempt up to exponent=6 (cap)**
  - Exercises: `_nextDelay()` across attempts 1–6
  - Setup: Inline calls to `_nextDelay()` with `_reconnectAttempt` incrementing
  - Expected: 1s → 2s → 4s → 8s → 16s → 32s (clamped to 30s max)
  - Notes: Exponent is capped to 6 via `math.min(_reconnectAttempt, 6)`, so attempt=7+ still returns ≈30s

- **should apply ±25% jitter to the base delay**
  - Exercises: `_nextDelay()` jitter calculation
  - Setup: Call `_nextDelay()` multiple times; statistical test
  - Expected: Jitter ∈ [−250ms, +250ms] for 1000ms base; min total delay ≥ 750ms, max ≤ 1250ms
  - Notes: Jitter uses `(math.Random().nextDouble() * 2 - 1)` for uniform [−1, 1], then scaled by ±25%

- **should clamp final delay to 30s maximum**
  - Exercises: `_nextDelay()` clamping logic
  - Setup: Advance `_reconnectAttempt` to 6+
  - Expected: Delay ≈ 30s regardless of attempt count (capping at exponent 6 ensures base ≤ 32s, clamped to 30s)
  - Notes: Even at attempt=100, final delay is capped at 30s max (actual max ≈ 30,250ms with jitter)

- **should ensure total delay ≥ 0ms (clamp lower bound)**
  - Exercises: `_nextDelay()` lower clamp
  - Setup: Artificially set `_reconnectAttempt = 0` and ensure jitter can produce negative intermediate result
  - Expected: `Duration(milliseconds: ms).clamp(0, _maxDelay)` ensures ≥ 0
  - Notes: Jitter subtraction could theoretically go negative; clamp(0, _maxDelay) prevents that

### Backoff Reset (confirmConnected)

- **should reset backoff counter to 0 after confirmConnected() is called**
  - Exercises: `confirmConnected()` → `_resetBackoff()`
  - Setup: Call `_scheduleReconnectInternal()` multiple times to increment `_reconnectAttempt` to 3+; then call `confirmConnected()`
  - Expected: Next call to `_nextDelay()` returns ≈1s (attempt 0 + jitter)
  - Notes: `confirmConnected()` is idempotent; first call after stream open should reset

- **should reset backoff even if called during pending reconnect timer**
  - Exercises: `confirmConnected()` canceling timer implicitly
  - Setup: Schedule a reconnect (timer active), then call `confirmConnected()`
  - Expected: `_reconnectAttempt` is 0; next attempt uses 1s base delay
  - Notes: This tests a potential race: if a stream opens while a reconnect is pending, backoff should reset

### Reconnect Scheduling (_scheduleReconnectInternal)

- **should schedule a timer with delay from _nextDelay() when _isAuthenticated=true**
  - Exercises: `_scheduleReconnectInternal()`
  - Setup: Emit `AuthenticatedState` to set `_isAuthenticated = true`; call `_scheduleReconnectInternal()`
  - Expected: `_reconnectTimer` is not null; timer fires after calculated delay
  - Notes: Use `fake_async` to advance time and verify timer callback execution

- **should cancel any existing timer before scheduling a new one**
  - Exercises: `_scheduleReconnectInternal()` timer cancellation
  - Setup: Call `_scheduleReconnectInternal()` twice rapidly
  - Expected: First timer is canceled (checked via a spy/mock); only second timer is active
  - Notes: Prevents stacked reconnect attempts

- **should not schedule if _isAuthenticated=false (guest state)**
  - Exercises: `_scheduleReconnectInternal()` auth guard
  - Setup: Emit `GuestState` to set `_isAuthenticated = false`; call `_scheduleReconnectInternal()`
  - Expected: `_reconnectTimer` remains null; no timer scheduled
  - Notes: Prevents reconnect loops when not authenticated

### Integration: Backoff Across Lifecycle

- **should reset backoff counter when confirmConnected() is called during active reconnect**
  - Exercises: Full cycle of `_scheduleReconnectInternal()` → `confirmConnected()`
  - Setup: Call `scheduleReconnect()` (public API) multiple times (e.g., stream failures), then `confirmConnected()`
  - Expected: `_reconnectAttempt` is 0; next failure resets to 1s base
  - Notes: Simulates real scenario: stream fails multiple times, eventually succeeds, is confirmed, then fails again (should restart backoff at 1s)

- **should increment attempt counter with each _nextDelay() call**
  - Exercises: `_reconnectAttempt` lifecycle
  - Setup: Call `_scheduleReconnectInternal()` four times
  - Expected: `_reconnectAttempt` is 4 after fourth call
  - Notes: Verify side effect of `_nextDelay()` incrementing the counter

- **should survive 100+ reconnect attempts without overflow**
  - Exercises: `_nextDelay()` and clamping under extreme load
  - Setup: Call `_scheduleReconnectInternal()` 100 times in rapid succession
  - Expected: All delays calculated successfully; final delays ≈ 30s (clamped); no exceptions or overflow
  - Notes: Dart's `pow()` on int does not overflow, but verify clamping prevents any numeric issues

### State Transitions with Backoff

- **should transition to disconnected and cancel reconnect timer on disconnect()**
  - Exercises: `disconnect()` → timer cleanup
  - Setup: Schedule a reconnect; then call `disconnect()`
  - Expected: `_reconnectTimer` is null; `currentState` is `disconnected`
  - Notes: Ensures timers don't fire after disconnect

- **should not reconnect if connectivity is lost mid-backoff**
  - Exercises: Connectivity listener during backoff
  - Setup: Call `_scheduleReconnectInternal()`; before timer fires, emit `ConnectivityResult.none`
  - Expected: Timer is canceled; no `connect()` call; `currentState` is `disconnected`
  - Notes: Connectivity loss should abort pending reconnect

- **should reconnect immediately if app resumes while disconnected (not backoff)**
  - Exercises: App resume listener vs. backoff scheduler
  - Setup: Disconnect; timer pending; emit resume event
  - Expected: `connect()` is called directly (not waiting for backoff timer); state → `connecting` then `connected`
  - Notes: App resume is a "wake up" signal and should try immediately, but actual backoff behavior depends on whether `connect()` call happens before or after timer; clarify intent

### Edge Cases & Race Conditions

- **should handle rapid confirmConnected() calls (idempotent)**
  - Exercises: Race between multiple `confirmConnected()` calls
  - Setup: Call `confirmConnected()` 5 times in a row
  - Expected: `_reconnectAttempt` is still 0 (no errors); safe to call multiple times
  - Notes: `_resetBackoff()` is idempotent

- **should handle confirmConnected() called before any reconnect scheduled**
  - Exercises: `confirmConnected()` with `_reconnectAttempt = 0` (initial state)
  - Setup: Create manager; immediately call `confirmConnected()`
  - Expected: No exception; `_reconnectAttempt` remains 0
  - Notes: Confirms initial state is safe

- **should not schedule reconnect after disconnect() even if called again**
  - Exercises: Replay of `_scheduleReconnectInternal()` after `disconnect()`
  - Setup: `disconnect()`; set `_isAuthenticated = true`; call `_scheduleReconnectInternal()`
  - Expected: Timer is scheduled (because `_isAuthenticated` is true)
  - Notes: If the intent is to prevent reconnect after disconnect, guard would need to be added; currently it will reconnect if authenticated again

## Gotchas

1. **Timer-based reconnect logic is async:** Use `fake_async` package to control time; otherwise tests will timeout or race.

2. **_nextDelay() is private:** Cannot test directly without:
   - Making it internal (package-private with `_` prefix doesn't expose publicly, but can be tested if extracted to a separate file or if testing via public API)
   - Testing via `_scheduleReconnectInternal()` and observing timer delay (less direct)
   - **Recommendation:** Extract `_nextDelay()` to a standalone utility function to enable unit tests on backoff math alone

3. **Dart pow() on large exponents:** `math.pow(2, 6)` returns 64 as a double. Multiplying by Duration works, but verify that no exponent > 6 is ever used (cap via `math.min()` prevents this). The clamping logic is correct but easy to regress.

4. **Jitter uses Math.Random():** Each call produces a different delay (±0–25%). Tests must either:
   - Accept a range of acceptable outputs (e.g., "delay ∈ [750ms, 1250ms]")
   - Mock `math.Random()` (requires dependency injection or mocking)
   - **Recommendation:** Seed `Random` with a fixed value or use a mock to make tests deterministic

5. **confirmConnected() race with stream open:** If a stream is opening while `_reconnectTimer` is active, calling `confirmConnected()` resets backoff but does not cancel the timer. The timer will still fire and call `connect()`. This is safe (idempotent connect) but could cause redundant reconnects. Test this scenario.

6. **_isAuthenticated flag:** Disconnect does not reset this flag; reconnect logic depends on it being true. If auth state goes to `GuestState`, the flag is set to false, but calling `_scheduleReconnectInternal()` directly bypasses that check. Ensure tests verify that `_scheduleReconnectInternal()` honors the flag.

7. **Exponent cap is explicit (math.min):** The cap is intentional, but verify that regression tests ensure exponent never exceeds 6. If someone removes the `math.min()`, tests should fail.

## Refactor Required

`_nextDelay()` uses `math.Random()` inline — every call produces a different delay, making deterministic assertions impossible. `_initialDelay` and `_maxDelay` are `static const` values not overridable per-instance.

**What to refactor:** Extract a `BackoffConfig` value object and accept it as an optional constructor parameter:

```dart
class BackoffConfig {
  final Duration initialDelay;
  final Duration maxDelay;
  final Random random;
  const BackoffConfig({
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    Random? random,
  }) : random = random ?? const _DefaultRandom();
}

GrpcConnectionManager({
  required Stream<AuthState> authStream,
  required Stream<List<ConnectivityResult>> connectivityStream,
  required Stream<void> resumeStream,
  BackoffConfig backoffConfig = const BackoffConfig(),
})
```

In tests, pass `backoffConfig: BackoffConfig(initialDelay: Duration(milliseconds: 10), maxDelay: Duration(milliseconds: 100), random: Random(0))` to get fast, deterministic reconnect cycles. The production constructor passes no override and gets the current constants.
