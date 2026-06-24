# SmoothedRrSource + HeartRateTickService — Test Plan

**Date:** 2026-06-24
**Source:** roadmap-test-coverage agent

## Source Overview

### SmoothedRrSource
- **File:** `lib/Biometrics/SmoothedRrSource.dart`
- **Role:** Always-on App singleton that maintains a 3-beat SMA of RR intervals
- **Key behavior:** 
  - Subscribes to `ActiveRrSource.stream` on construction
  - Silently skips artifacts (already logged by `ActiveRrSource`)
  - Maintains a rolling window of non-artifact samples
  - Emits SMA via `BehaviorSubject` (unseeded until first non-artifact arrives)
  - `smoothedIntervalMs` returns null before first value; after that returns current SMA
  - Does not dispose the `ActiveRrSource` (owned by App)

### HeartRateTickService
- **File:** `lib/BreathModule/HeartRateTickService.dart`
- **Role:** Free-running metronome tick source that uses SmoothedRrSource cadence
- **Key behavior:**
  - Constructed with `SmoothedRrSource` and optional `timerFactory`
  - Started by explicit `start()` call (mirrors `ClockTickService`), no prime tick emitted
  - Seeds `_effectiveActive` BehaviorSubject from `smoothedRrSource.hasActiveSource`
  - Tracks `_droppedReplay` to distinguish warm-path replay from genuine emissions
  - Emits ticks via `_tickController` broadcast stream
  - Real heartbeats only update `_currentPeriodMs` and reset 10s `_graceWindow`
  - Grace expiry flips `_effectiveActive` to false (SwitchableTickService auto-falls back to ClockTickService)
  - Clamps period to [250–3000] ms to prevent busy-loop
  - Does not dispose SmoothedRrSource (shared with other consumers)

## Instantiation

### SmoothedRrSource
```dart
final smoothed = SmoothedRrSource(
  activeRrSource,
  window: 3,  // default
);
```

### HeartRateTickService
```dart
final heartTicks = HeartRateTickService(
  smoothedRrSource: smoothed,
  timerFactory: (duration, callback) => Timer(duration, callback),  // injected for testing
);
heartTicks.start();  // must call to begin metronome
```

## Existing Coverage

**File:** `test/BreathModule/switchable_tick_service_test.dart`

**Status:** Written before Jun-20 rewrite — **does NOT exercise SmoothedRrSource or the new HeartRateTickService interface directly.**

**What it tests:** 
- SwitchableTickService behavior (task 6–8 in the test file)
- Uses `_FakeHeartRateTickService` fake that does not implement the real construction, `start()` call, or heartbeat subscription flow
- Fake only implements the public `ITickService` methods + `hasActiveSource` / `hasActiveSourceStream`
- No coverage of: grace window, replay-dropping logic, period clamping, free-running metronome rescheduling

**Gap:** The fake does not construct a real HeartRateTickService, so the metronome initialization, grace timer, and smoothed-stream subscription paths are never exercised.

---

## Test Cases

### SmoothedRrSource

#### Instantiation & Initial State
1. **should start with null smoothedIntervalMs before any intervals arrive**
   - Method: `smoothedIntervalMs` getter
   - Setup: Create instance, don't send intervals
   - Verify: `smoothedIntervalMs == null`, `_subject.hasValue == false`

2. **should not dispose the input ActiveRrSource on dispose**
   - Method: `dispose()`
   - Setup: Create instance, call dispose
   - Verify: Owned ActiveRrSource is still usable by other consumers
   - Note: Use a real or fake ActiveRrSource and verify it remains subscribed

#### Non-Artifact Intervals
3. **should compute SMA of last 3 non-artifact intervals**
   - Method: `_onInterval()` → `smoothedIntervalMs` getter
   - Setup: Send 3 non-artifact intervals [500, 600, 700]
   - Verify: `smoothedIntervalMs == 600` (sum 1800 / 3)

4. **should emit on smoothedIntervalStream each time a non-artifact interval arrives**
   - Method: `smoothedIntervalStream` stream
   - Setup: Subscribe to stream before sending intervals
   - Send: 3 non-artifact intervals [500, 600, 700]
   - Verify: Stream emits [600] (after interval 3; SMA settles)
   - Note: First emit is after the 3rd sample when window fills

5. **should drop the oldest sample when window fills (size > 3)**
   - Method: `_onInterval()` → `smoothedIntervalMs` getter
   - Setup: Send 4 non-artifact intervals [500, 600, 700, 800]
   - Verify: `smoothedIntervalMs == 700` (new SMA of [600, 700, 800])

6. **should replay the last smoothedIntervalMs to new subscribers (BehaviorSubject)**
   - Method: `smoothedIntervalStream` (BehaviorSubject replay)
   - Setup: Send 1 interval [500], then subscribe
   - Verify: New subscriber immediately receives [500]

#### Artifact Filtering
7. **should silently skip intervals where isArtifact == true**
   - Method: `_onInterval()` → `smoothedIntervalMs` getter
   - Setup: Send [500 non-artifact, 9999 artifact, 600 non-artifact, 700 non-artifact]
   - Verify: `smoothedIntervalMs == 600` (artifact not in window; only [500, 600, 700])

8. **should not emit when only artifact intervals arrive**
   - Method: `smoothedIntervalStream`
   - Setup: Subscribe, send 5 artifact intervals
   - Verify: No emissions, `smoothedIntervalMs == null`

#### Pass-Through Availability
9. **should expose hasActiveSource from input ActiveRrSource**
   - Method: `hasActiveSource` getter
   - Setup: Create with ActiveRrSource that has `hasActiveSource == true`
   - Verify: SmoothedRrSource.hasActiveSource == true

10. **should forward hasActiveSourceStream transitions**
    - Method: `hasActiveSourceStream`
    - Setup: Subscribe to stream, trigger ActiveRrSource to emit false
    - Verify: Stream receives false

#### Edge Cases
11. **should handle SMA calculation with fewer than 3 samples before window fills**
    - Method: `_onInterval()` → `smoothedIntervalMs` getter
    - Setup: Send 1 interval [500]
    - Verify: `smoothedIntervalMs == 500` (SMA of [500])
    - Then send 2 more [600, 700]
    - Verify: `smoothedIntervalMs == 600` (SMA of [500, 600])

12. **should handle window == 1 (edge case custom window)**
    - Method: `_onInterval()` → `smoothedIntervalMs` getter
    - Setup: Create with `window: 1`, send [500, 600, 700]
    - Verify: Always reflects the latest: [500], then [600], then [700]

---

### HeartRateTickService (free-running metronome)

#### Instantiation & Startup
1. **should seed _effectiveActive from smoothedRrSource.hasActiveSource at construction (warm path with active source)**
   - Method: `_effectiveActive` internal via `hasActiveSource` getter
   - Setup: Create with smoothedRrSource.hasActiveSource == true
   - Verify: `hasActiveSource == true` before start() is called
   - Note: Grace timer is armed at construction

2. **should seed _effectiveActive from smoothedRrSource.hasActiveSource at construction (cold path without active source)**
   - Method: `_effectiveActive` internal via `hasActiveSource` getter
   - Setup: Create with smoothedRrSource.hasActiveSource == false
   - Verify: `hasActiveSource == false` before start() is called
   - Note: Grace timer is not armed until first genuine beat

3. **should pre-mark _droppedReplay=true on cold path (no prior value in BehaviorSubject)**
   - Method: `_onSmoothed()` logic (internal, verify via tick behavior)
   - Setup: Create with smoothedRrSource.smoothedIntervalMs == null
   - Send: First SMA emission [500]
   - Verify: Tick is emitted (not dropped as replay); period is updated
   - Note: Constructor checks `smoothedRrSource.smoothedIntervalMs != null` to set flag

4. **should pre-mark _droppedReplay=false on warm path (value exists in BehaviorSubject)**
   - Method: `_onSmoothed()` logic (internal, verify via tick behavior)
   - Setup: Create with smoothedRrSource.smoothedIntervalMs == 500 (already warmed)
   - Verify: First subscription to smoothedIntervalStream receives replay, but tick is NOT emitted (dropped)
   - Then send genuine beat [600]
   - Verify: Tick is emitted (not dropped)

5. **should seed _currentPeriodMs from smoothedRrSource.smoothedIntervalMs (warm path)**
   - Method: `_currentPeriodMs` field (internal, verify via tick timing)
   - Setup: Create with smoothedRrSource.smoothedIntervalMs == 600
   - Call: start()
   - Verify: First tick fires at ~600 ms, not 1000 ms (the fallback default)

6. **should seed _currentPeriodMs to 1000 when smoothedRrSource.smoothedIntervalMs == null (cold path)**
   - Method: `_currentPeriodMs` field (internal)
   - Setup: Create with smoothedRrSource.smoothedIntervalMs == null
   - Verify: Constructor sets field to 1000

#### Metronome Lifecycle (no pause/prime ticks)
7. **should emit no ticks until start() is called**
   - Method: `start()` call gate
   - Setup: Create, do NOT call start(), subscribe to tickStream
   - Send: SMA emissions [600, 700]
   - Verify: No ticks emitted (metronome never scheduled)

8. **should emit no prime/immediate tick when start() is called (mirrors ClockTickService)**
   - Method: `start()` override
   - Setup: Create, subscribe to tickStream, call start()
   - Verify: No tick emitted at construction or start() time
   - Wait ~1000 ms
   - Verify: First tick arrives (after metronome period)

9. **should schedule the metronome at _currentPeriodMs (clamped to [250–3000])**
   - Method: `_scheduleNext()` → `_onMetronomeFire()`
   - Setup: Create with custom timerFactory that captures the Duration
   - Call: start()
   - Verify: timerFactory called with Duration matching clamped _currentPeriodMs
   - Advance: Simulate timer fire
   - Verify: Tick emitted with intervalMs == clamped period

10. **should clamp period to 250 ms floor when SMA is near-zero**
    - Method: `_scheduleNext()` clamping
    - Setup: Create, seed SmoothedRrSource with 100 ms SMA (via fake), call start()
    - Verify: timerFactory called with Duration(milliseconds: 250)

11. **should clamp period to 3000 ms ceiling when SMA is very large**
    - Method: `_scheduleNext()` clamping
    - Setup: Create, seed SmoothedRrSource with 5000 ms SMA (via fake), call start()
    - Verify: timerFactory called with Duration(milliseconds: 3000)

12. **should reschedule the metronome after each fire using the current _currentPeriodMs**
    - Method: `_onMetronomeFire()` → `_scheduleNext()` → self-reschedule
    - Setup: Create with timerFactory capturing calls, call start()
    - Send: SMA update [600]
    - Advance: First timer fires
    - Verify: Tick emitted, timerFactory called again (rescheduled)

#### Real Heartbeat Subscription (period update + grace reset, no tick emission)
13. **should update _currentPeriodMs when a genuine (non-replay) heartbeat arrives**
    - Method: `_onSmoothed()` genuine beat path
    - Setup: Create on cold path, call start(), subscribe to tickStream, inject timerFactory capturing Durations
    - Send: SMA [600]
    - Verify: Tick intervalMs == 600 (metronome uses new period)

14. **should not emit a tick when heartbeat arrives (only metronome emits)**
    - Method: `_onSmoothed()` genuine beat path
    - Setup: Create, call start(), subscribe to tickStream
    - Send: SMA [600]
    - Verify: No tick emitted by _onSmoothed; tick only arrives when metronome fires

15. **should rearm grace timer when genuine heartbeat arrives**
    - Method: `_armGrace()` call from `_onSmoothed()`
    - Setup: Create with mocked timerFactory
    - Send: SMA [600], then wait 5 seconds, send SMA [700]
    - Verify: _graceTimer is cancelled and re-armed twice
    - Note: Test via mocking or observing no grace-expiry during heartbeat stream

#### Grace Window Expiry (coast-grace auto-fallback)
16. **should flip _effectiveActive to false when grace window expires (10 seconds)**
    - Method: `_onGraceExpired()` → `_effectiveActive.add(false)`
    - Setup: Create with mocked timerFactory tracking grace timer, call start()
    - Simulate: Let grace timer fire (no heartbeats for 10s)
    - Verify: `hasActiveSource` transitions to false, emits on `hasActiveSourceStream`

17. **should NOT stop the metronome when grace expires (coasts at last known period)**
    - Method: `_onGraceExpired()` — does NOT call `_metronome.cancel()`
    - Setup: Create, call start(), send SMA, wait for grace to expire, observe tick emission continues
    - Verify: Ticks still arrive even after `hasActiveSource == false`
    - Note: This is critical for SwitchableTickService to auto-fallback without losing sync

18. **should reactivate (flip _effectiveActive true) when heartbeat returns after grace expiry**
    - Method: `_onSmoothed()` genuine beat path → `_effectiveActive.add(true)`
    - Setup: Create, call start(), let grace expire, send new SMA
    - Verify: `hasActiveSource` transitions to true

#### Stream & Disposal
19. **should expose tickStream as a broadcast stream (multiple independent subscribers)**
    - Method: `tickStream` getter
    - Setup: Subscribe twice
    - Verify: Both subscribers receive ticks

20. **should cancel metronome timer on dispose**
    - Method: `dispose()` → `_metronome?.cancel()`
    - Setup: Create, call start(), then dispose()
    - Verify: No more ticks emitted
    - Note: Verify using mocked timerFactory that cancel() was called

21. **should cancel grace timer on dispose**
    - Method: `dispose()` → `_graceTimer?.cancel()`
    - Setup: Create, call start(), then dispose()
    - Verify: Grace timer is cancelled (no pending expiry)

22. **should cancel smoothedIntervalStream subscription on dispose**
    - Method: `dispose()` → `_smoothedSub?.cancel()`
    - Setup: Create, dispose()
    - Verify: No response to subsequent SMA emissions
    - Note: Check `hasActiveSource` does not change after dispose if SMA changes

23. **should close tickStream (subscribers receive done)**
    - Method: `dispose()` → `_tickController.close()`
    - Setup: Create, call start(), subscribe to tickStream, dispose()
    - Verify: Subscriber receives done event

24. **should close hasActiveSourceStream (subscribers receive done)**
    - Method: `dispose()` → `_effectiveActive.close()`
    - Setup: Create, subscribe to hasActiveSourceStream, dispose()
    - Verify: Subscriber receives done event

25. **should NOT dispose the input SmoothedRrSource on dispose**
    - Method: `dispose()` comment + code review
    - Setup: Create, dispose()
    - Verify: SmoothedRrSource is still usable by other consumers

#### ITickService Interface
26. **should implement source property returning TickSource.heartbeat**
    - Method: `source` getter
    - Verify: Always returns `TickSource.heartbeat`

27. **should implement nominalIntervalMs property returning 1000**
    - Method: `nominalIntervalMs` getter
    - Verify: Always returns 1000 (nominal clock interval, not current SMA)

28. **should implement sourceChanges as empty stream (no switching allowed)**
    - Method: `sourceChanges` getter
    - Verify: Always returns `Stream.empty()`

29. **should implement trySwitchTo returning false (immutable source)**
    - Method: `trySwitchTo(target)`
    - Verify: Always returns false regardless of target

---

## Gotchas & Injection Points

### Timer Injection for Testing
- **Inject via `timerFactory` constructor parameter** (already present)
- Mock timer to capture Duration and callback, fire manually in test
- Example:
  ```dart
  final timerCalls = <(Duration, void Function())>[];
  final service = HeartRateTickService(
    smoothedRrSource: smoothed,
    timerFactory: (duration, callback) {
      timerCalls.add((duration, callback));
      return MockTimer(callback);  // or custom fake that records fire
    },
  );
  ```

### SmoothedRrSource Fake/Mock
- Need to emit `RrInterval` objects with `isArtifact` field
- Inject fake `ActiveRrSource` that allows manual emission via:
  ```dart
  class FakeActiveRrSource implements ActiveRrSource {
    final _stream = StreamController<RrInterval>();
    void emitInterval(RrInterval rr) => _stream.add(rr);
    bool hasActiveSource = false;  // mutable
    Stream<RrInterval> get stream => _stream.stream;
    Stream<bool> get hasActiveSourceStream => /* BehaviorSubject or similar */;
  }
  ```

### Replay Dropping Logic
- **Cold path** (no prior value in BehaviorSubject):
  - Constructor sees `smoothedIntervalMs == null`
  - Sets `_droppedReplay = true`
  - First SMA emission is treated as genuine, triggers tick + grace reset
  
- **Warm path** (prior value exists):
  - Constructor sees `smoothedIntervalMs != null`
  - Sets `_droppedReplay = false`
  - First subscription receives immediate replay (via BehaviorSubject)
  - First emission in `_onSmoothed` callback sets flag to true and returns (drops the replay)
  - Second emission is treated as genuine, triggers tick + grace reset

- **Test this by:**
  - Warm path: Pass SmoothedRrSource with existing value, verify first tick is dropped
  - Cold path: Pass SmoothedRrSource without value, verify first tick is emitted

### Grace Window Edge Cases
- Grace timer is armed at **construction** only if `smoothedRrSource.hasActiveSource == true` (warm sensor)
- Grace timer is armed on **first genuine beat** if initially false (cold sensor)
- Arming cancels any existing timer, so repeated beats reset the 10s window
- If grace expires and source never recovers, `hasActiveSource` stays false but metronome coasts

### SMA Window Size Edge Case
- Window size = 3 is hardcoded in SmoothedRrSource
- SMA can return values from [1, 3) samples during warmup (1 sample → SMA of [500], 2 samples → SMA of [500, 600], etc.)
- Do not assume exactly 3 items; test partial-window behavior

### No Pause/Prime Ticks
- `HeartRateTickService` has no pause/resume lifecycle (mirrors `ClockTickService`)
- The fake in `switchable_tick_service_test.dart` defines `void start()` as a no-op — the real implementation must start the metronome
- Old test file won't fail (fake is compatible), but it never exercises the real constructor logic

## Refactor Required

**Status:** Already implemented. `HeartRateTickService` constructor already has:
```dart
HeartRateTickService({
  required SmoothedRrSource smoothedRrSource,
  Timer Function(Duration, void Function()) timerFactory = Timer.new,
  Duration graceWindow = const Duration(seconds: 10),
})  : _timerFactory = timerFactory,
      _graceWindow = graceWindow { ... }
```

**No refactor needed.** The `graceWindow` parameter is already injected (named, optional, default 10s), and field is correctly named `_graceWindow`.

**What the test implementer gets:** Pass `graceWindow: Duration(milliseconds: 50)` for fast grace-expiry tests that verify `_effectiveActive` → false → `SwitchableTickService` auto-fallback without 10 s real waits. `timerFactory` is already injectable — no additional change needed.
