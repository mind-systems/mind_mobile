# ActiveRrSource — Test Plan

**Date:** 2026-06-03
**Source:** roadmap-test-coverage agent

## Source Overview

`ActiveRrSource` implements a **preferred-with-fallback** multiplexer for beat-to-beat RR interval streams. It maintains a static list of `IRrIntervalSource` implementations, subscribes to each, and forwards intervals from only the currently active (highest-priority, not silent) source downstream. When the active source falls silent past a watchdog window, it failovers to the next alive source; when all sources are silent, `hasActiveSource` becomes false and the output stream pauses.

## Instantiation

**Constructor:** `ActiveRrSource(List<IRrIntervalSource> sources)`
- Takes an immutable list of source implementations
- Immediately subscribes to all sources' `.rrStream` getters
- Sets up one `StreamSubscription<RrInterval>` per source

**Dependencies to mock/fake:**
- `IRrIntervalSource` — implement or use `MockIRrIntervalSource` with injectable `StreamController<RrInterval> rrStream`
- `DateTime` — use `DateTime.now()` naturally; tests can manipulate wall-clock advances via Timer mocks or fakes
- `Timer` — Dart's test harness provides `Timer.run()` and `Timer()` naturally; use `fakeAsync()` and `tick()` for deterministic control
- `StreamController<RrInterval>` — owned internally; safe from outside
- `BehaviorSubject<bool>` (from rxdart) — owned internally; tests observe via `.hasActiveSourceStream`

## Existing Coverage

None.

## Test Cases

### Instantiation & Setup

**should subscribe to all sources on construction**
- Method: constructor
- Verify: `_subs.length == sources.length`
- Setup: Create 3 mock sources; construct; check listener count on each mock's `rrStream`

**should initialize hasActiveSource to false**
- Method: constructor
- Verify: `instance.hasActiveSource == false` immediately after construction
- Setup: Create instance, check getter

**should initialize _activeIndex to null (no active source yet)**
- Method: constructor (via private field)
- Verify: First emission should not trigger until an interval arrives
- Setup: Create instance, verify no intervals emitted from `.stream` before input

---

### Single Source Emission

**should emit intervals from source[0] when it is the only source**
- Method: `_onInterval()`
- Input: source[0] emits `RrInterval(intervalMs=800, timestamp=now, isArtifact=false, source=neiry)`
- Verify: `instance.stream` receives that interval
- Setup: 1 mock source; listen to `.stream`; emit from mock; assert received

**should set _activeIndex to 0 when first interval arrives**
- Method: `_onInterval()`
- Verify: Subsequent intervals from source[1] are ignored (not forwarded)
- Setup: 2 sources; emit from source[0]; then emit from source[1]; verify source[1] intervals don't appear on output

**should update _lastSeenAt[index] on every interval**
- Method: `_onInterval()`
- Verify: Timestamp in `_lastSeenAt[0]` matches interval receipt time (or is very recent)
- Setup: Emit, read private `_lastSeenAt` or infer from watchdog behavior

**should update _lastIntervalMs on every interval from active source**
- Method: `_onInterval()`
- Verify: Next watchdog window uses this value; e.g., 800 ms interval → 1600 ms window
- Setup: Emit 800 ms interval; wait for watchdog; verify timeout duration

---

### Artifact Handling

**should forward artifacts as-is (not filtered)**
- Method: `_onInterval()`
- Input: `RrInterval(..., isArtifact=true)`
- Verify: artifact interval appears on output stream
- Setup: Emit artifact; listen to `.stream`; assert received

**should log artifact with source name**
- Method: `_onInterval()`
- Input: artifact from source[0] (neiry)
- Verify: `logPrint()` called with "artifact from source[0] (neiry)"
- Setup: Mock `logPrint()`; emit artifact; verify call

---

### Priority & Preemption

**should prefer lower-index (higher-priority) source**
- Method: `_onInterval()`
- Input: source[1] active, then source[0] emits
- Verify: `_activeIndex` flips to 0; output switches to source[0]
- Setup: 2 sources; emit from source[1]; then emit from source[0]; verify output carries source[0] interval

**should log priority switch**
- Method: `_onInterval()`
- Verify: `logPrint('ActiveRrSource: active source = 0 (neiry)')` when switching to source[0]
- Setup: Mock `logPrint()`; trigger priority switch; verify call with index and source name

**should not emit intervals from non-active sources**
- Method: `_onInterval()`
- Input: source[0] active; source[1] emits
- Verify: `_intervalController` does not receive source[1] intervals
- Setup: 2 sources, both emitting; verify only source[0] appears on `.stream`

---

### Watchdog & Silence Detection

**should restart watchdog on every active-source interval**
- Method: `_restartWatchdog()`
- Verify: previous timer is cancelled; new timer scheduled
- Setup: fakeAsync; emit interval; tick past first window; verify no silence triggered; emit again; tick; still no silence
- Pattern: Emit, tick (window - delta), emit again, tick (window), verify no silence

**should compute window as max(lastIntervalMs * 2.0, 2 seconds)**
- Method: `_restartWatchdog()`
- Test case A: 800 ms interval → 1600 ms window
  - Verify: Emit 800 ms; silence doesn't fire until 1600 ms have passed
- Test case B: 500 ms interval → 1000 ms window, but floor is 2000 ms, so 2000 ms window
  - Verify: Emit 500 ms; silence doesn't fire until 2000 ms have passed
- Test case C: 1200 ms interval → 2400 ms window (exceeds floor)
  - Verify: Emit 1200 ms; silence fires at 2400 ms, not 2000 ms
- Setup: fakeAsync; emit intervals; tick precise durations; verify silence fires at expected time

**should use 1000 ms as default if _lastIntervalMs is null**
- Method: `_restartWatchdog()`
- Input: watchdog triggered before any interval (edge case)
- Verify: Window = max(1000 * 2.0, 2000) = 2000 ms
- Setup: Construct, do not emit, verify watchdog would use 2000 ms (or just check the code flow)

**should trigger _onSilence when active source does not emit within window**
- Method: `_restartWatchdog()` + `_onSilence()`
- Input: emit interval (800 ms); wait 1600+ ms
- Verify: `_onSilence()` is called; `_activeIndex` changes or becomes null
- Setup: fakeAsync; emit; tick(1600); verify side effects

---

### Failover Logic

**should failover to next-priority source if it has emitted recently**
- Method: `_onSilence()`
- Input: source[0] active, goes silent; source[1] has emitted within 2 seconds
- Verify: `_activeIndex` flips to 1; watchdog restarted
- Setup: fakeAsync; emit from source[0] (800 ms); tick(100); emit from source[1]; tick(1600+); verify active = 1

**should skip sources that have never emitted**
- Method: `_onSilence()`
- Input: source[0] active, goes silent; source[1] has never emitted
- Verify: `_activeIndex` remains null (or moves further, if source[2] has emitted)
- Setup: 3 sources; emit only from source[0]; silence triggers; verify source[1] skipped

**should skip sources that are too stale (not within 2-second floor)**
- Method: `_onSilence()`
- Input: source[0] active, goes silent; source[1] emitted >2 seconds ago
- Verify: source[1] skipped; `_activeIndex` becomes null
- Setup: fakeAsync; emit from source[0]; emit from source[1]; tick(2100+); silence triggers; verify source[1] rejected

**should walk the list in priority order (lowest index first)**
- Method: `_onSilence()`
- Input: source[0] silent; both source[1] and source[2] are fresh
- Verify: failover to source[1], not source[2]
- Setup: fakeAsync; emit all three; source[0] active; silence; verify active = 1

**should log failover event**
- Method: `_onSilence()`
- Verify: `logPrint('ActiveRrSource: failover 0 → 1')`
- Setup: Mock logPrint; trigger failover; verify call

**should log when all sources are silent**
- Method: `_onSilence()`
- Input: source[0] active, goes silent; no other sources are fresh
- Verify: `logPrint('ActiveRrSource: all sources silent')`
- Setup: Mock logPrint; emit only from source[0]; silence; verify call

---

### hasActiveSource State

**should emit true on hasActiveSourceStream when first interval arrives**
- Method: `_ensureHasActive()`
- Verify: `hasActiveSourceStream` transitions from `false` → `true`
- Setup: Construct; listen to `hasActiveSourceStream`; emit interval; verify `true` emitted

**should emit false on hasActiveSourceStream when all sources silent**
- Method: `_ensureHasActive()` (called from `_onSilence()`)
- Verify: `hasActiveSourceStream` transitions from `true` → `false`
- Setup: fakeAsync; emit; silence; verify `false` emitted

**should not emit redundant values to hasActiveSourceStream**
- Method: `_ensureHasActive()`
- Input: emit interval; emit another interval (both keep hasActiveSource = true)
- Verify: `hasActiveSourceStream` receives only one `true`, not duplicates
- Setup: Listen to hasActiveSourceStream; emit two intervals in quick succession; count emissions

**should serve BehaviorSubject semantics (late subscriber gets current value)**
- Method: constructor (BehaviorSubject.seeded(false))
- Verify: Subscribe after construction, before any emit → receive `false`; subscribe after first emit → receive `true`
- Setup: Construct; late subscribe to `hasActiveSourceStream`; verify immediate `false` received

---

### Disposal & Cleanup

**should cancel all subscriptions on dispose**
- Method: `dispose()`
- Verify: Each mock source's stream subscription is cancelled
- Setup: Construct with 2 sources; dispose; verify `cancel()` called on both subs

**should cancel watchdog on dispose**
- Method: `dispose()`
- Setup: fakeAsync; emit (starts watchdog); dispose; tick(2100); verify `_onSilence` not called (watchdog was cancelled)

**should close _intervalController on dispose**
- Method: `dispose()`
- Verify: Further emissions to `.stream` fail or are ignored; listeners receive done
- Setup: Construct; listen to `.stream`; dispose; verify listener receives completion

**should close _hasActiveController on dispose**
- Method: `dispose()`
- Verify: Further updates to `hasActiveSourceStream` fail; listeners receive done
- Setup: Construct; listen to `hasActiveSourceStream`; dispose; verify listener receives completion

**should be awaitable (returns Future<void>)**
- Method: `dispose()`
- Verify: `await instance.dispose()` completes without error
- Setup: Call dispose; await it

---

### Edge Cases & Invariants

**should handle empty sources list**
- Input: `ActiveRrSource([])`
- Verify: Constructs successfully; no subscriptions; `.stream` is a broadcast stream but silent; `hasActiveSource = false`
- Setup: Construct with empty list; listen to both streams; emit nothing; verify no errors

**should handle rapid successive emissions from same source**
- Input: source[0] emits 10 intervals in quick succession
- Verify: All 10 forwarded to `.stream`; watchdog restarted after each; no crashes
- Setup: fakeAsync; emit burst; tick between emits; verify all received and watchdog doesn't stall

**should handle rapid source switching**
- Input: source[0], source[1], source[0] emit in quick succession (millis apart)
- Verify: Output carries intervals from active source at each moment; no race conditions or dropped intervals
- Setup: fakeAsync; manual timeline of emissions; verify output order and completeness

**should survive emitting after watchdog fires but before source switched**
- Input: source[0] active; watchdog fires (all silent); source[1] scheduled to emit in background
- Verify: If source[1] emits before `_onSilence()` fully completes, output is consistent (no double-emit, no contradiction)
- Setup: fakeAsync; careful timing of emit and silence callback

**should not crash if a source emits invalid (null or extremely large) intervalMs**
- Input: `RrInterval(intervalMs=0 or 999999, ...)`
- Verify: Forwarded as-is (no validation in this class); watchdog computes window correctly
- Setup: Emit extreme values; tick; verify watchdog fires at expected wall-clock time

**should maintain _lastSeenAt after failover**
- Verify: After switching from source[0] to source[1], `_lastSeenAt[0]` is still preserved (used for next silence decision)
- Setup: 3 sources, all emitting; source[0] goes silent, switch to source[1]; later source[1] silent, verify source[0] rejected if too stale

---

## Gotchas

1. **Timer lifecycle in fakeAsync:**
   - `Timer(duration, callback)` in real code becomes synchronous in `fakeAsync` test.
   - Must use `tick()` to advance time and trigger callbacks.
   - Forgetting to `tick()` means silence never fires in tests.

2. **Private fields:**
   - `_activeIndex`, `_lastIntervalMs`, `_lastSeenAt`, `_watchdog` are private.
   - Tests cannot directly read them; must infer state from observable outputs (`.stream`, `.hasActiveSourceStream`, behavior).
   - Alternatively, use reflection or test-friendly helpers (e.g., a getter exposed in tests only).

3. **BehaviorSubject seeding:**
   - `_hasActiveController = BehaviorSubject<bool>.seeded(false)` means late subscribers immediately receive `false`.
   - Tests subscribing after construction must account for this initial emission.

4. **Broadcast stream semantics:**
   - `_intervalController = StreamController<RrInterval>.broadcast()` allows multiple concurrent listeners.
   - Tests must manage listener lifecycle carefully (cancel subscriptions in tearDown to avoid resource leaks).

5. **Fire-and-forget async in dispose:**
   - `dispose()` is async and awaitable; cancelling subscriptions may have side effects.
   - Always `await dispose()` in test tearDown; do not omit the await.

6. **Watchdog cancellation edge case:**
   - Calling `_restartWatchdog()` while a timer is pending does call `_watchdog.cancel()` first.
   - If `_watchdog` is null, `.cancel()` would crash (it is checked: `_watchdog?.cancel()`).
   - But there is no guard against calling `_restartWatchdog()` after `dispose()`; if `_watchdog` is non-null but the underlying Timer infrastructure is closed, errors may occur (low risk in practice, but document as limitation).

7. **Timestamp precision:**
   - `_lastSeenAt[index] = DateTime.now()` records wall-clock time.
   - Tests using `DateTime.now()` may have microsecond jitter; use `fakeAsync` and mock `DateTime.now()` if millisecond-level precision is required.
   - Alternatively, treat `_lastSeenAt` comparisons as "approximately recent", not exact.

8. **Source list immutability:**
   - `_sources = List.unmodifiable(sources)` ensures the list cannot be modified after construction.
   - Tests cannot inject new sources at runtime; they must be provided upfront.

9. **Watchdog window computation edge case:**
   - If `_lastIntervalMs == null`, window defaults to `Duration(milliseconds: 2000)` (1000 * 2.0, max'ed with floor).
   - This only happens if watchdog fires before any interval (unusual, but possible in edge-case timing).
   - Tests should handle this gracefully or document as "requires at least one interval before watchdog can fire".

10. **hasActiveSourceStream vs. hasActiveSource getter:**
    - `.hasActiveSourceStream` is a broadcast stream (from `BehaviorSubject`); multiple listeners can subscribe.
    - `.hasActiveSource` is a synchronous getter to the current value.
    - Tests must choose the right one: use the getter for instant state queries, stream for monitoring transitions.

## Refactor Required

`DateTime.now()` is called directly in `_onInterval` and `_onSilence`; `Timer(...)` is constructed inline in `_restartWatchdog`. Both make time-based tests dependent on wall-clock delays.

**What to refactor:** Add two constructor parameters:
- `DateTime Function() clock` — defaults to `DateTime.now`; used everywhere `DateTime.now()` currently appears
- `Timer Function(Duration, void Function()) timerFactory` — defaults to `Timer.new`; used in `_restartWatchdog` instead of `Timer(...)`

**Post-refactor API:**
```dart
ActiveRrSource(
  List<IRrIntervalSource> sources, {
  DateTime Function() clock = DateTime.now,
  Timer Function(Duration, void Function()) timerFactory = Timer.new,
})
```

In tests, pass a `FakeClock.now` and a spy timer factory so silence windows can be triggered synchronously without `fakeAsync` or real delays. The production call site (`App.initialize`) passes no overrides and gets the current defaults.
