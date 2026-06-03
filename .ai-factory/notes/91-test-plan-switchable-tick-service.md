# SwitchableTickService — Test Plan

**Date:** 2026-06-03
**Source:** roadmap-test-coverage agent

## Source Overview

SwitchableTickService is a decorator over two tick sources (ClockTickService for timer-based ticks, HeartRateTickService for heart-rate-based ticks). It implements ITickService and manages switching between sources, auto-fallback when heart rate becomes unavailable, and multiplexing tick emissions through a broadcast stream.

## Instantiation

```dart
final clock = ClockTickService();
final heart = HeartRateTickService(activeRrSource: mockActiveRrSource);
final service = SwitchableTickService(clock: clock, heart: heart);
```

**Mocks/Fakes needed:**
- `ActiveRrSource`: Mock with `hasActiveSource` property and `hasActiveSourceStream` getter
- `ClockTickService` and `HeartRateTickService`: Can be mocked. Key: `tickStream`, `hasActiveSource`, `hasActiveSourceStream`

## Existing Coverage

None.

## Test Cases

### Constructor & Initialization

- **should start with timer source as active when constructed**
  - Method: Constructor, `source` getter
  - Verify: `source == TickSource.timer`

- **should listen to clock tick stream immediately on construction**
  - Method: Constructor, `tickStream` getter
  - Verify: Ticks from clock forwarded to subscribers

- **should subscribe to heart hasActiveSourceStream on construction**
  - Method: Constructor (internal subscription)
  - Verify: Mock confirms subscription created

### tickStream & source Getters

- **should return a broadcast stream for tickStream**
  - Method: `tickStream` getter
  - Verify: Multiple subscribers work independently

- **should forward ticks from active source through tickStream**
  - Method: `tickStream` getter (forwarding)
  - Verify: Subscribers receive exact TickData objects

- **should return current active source**
  - Method: `source` getter
  - Verify: Matches `_activeSource` internal state

### trySwitchTo — Happy Path

- **should return true when switching to heartbeat and heart has active source**
  - Method: `trySwitchTo(TickSource.heartbeat)`
  - Verify: Return true, state updates

- **should return true when switching to timer (always available)**
  - Method: `trySwitchTo(TickSource.timer)`
  - Verify: Return true

- **should switch tick subscription from clock to heart when switching to heartbeat**
  - Method: `trySwitchTo(TickSource.heartbeat)` → `_switchInternal`
  - Verify: Ticks after switch come from heart

- **should switch tick subscription from heart to clock when switching to timer**
  - Method: `trySwitchTo(TickSource.timer)` → `_switchInternal`
  - Verify: Ticks after switch come from clock

### trySwitchTo — Error Path

- **should return false when switching to heartbeat and heart has no active source**
  - Method: `trySwitchTo(TickSource.heartbeat)`
  - Setup: Mock heart with `hasActiveSource = false`
  - Verify: Return false, state unchanged

- **should not change internal state when switch fails**
  - Method: `trySwitchTo` with unavailable heart
  - Verify: `source` getter still returns initial value

### trySwitchTo — No-Op

- **should return true when switching to already-active source (heartbeat)**
  - Method: `trySwitchTo(TickSource.heartbeat)` when already on heartbeat
  - Verify: Return true

- **should return true when switching to already-active source (timer)**
  - Method: `trySwitchTo(TickSource.timer)` when already on timer
  - Verify: Return true

- **should not re-subscribe or emit sourceChanges on no-op switch**
  - Method: `trySwitchTo` + `sourceChanges` getter
  - Verify: No emission to `sourceChanges`

### sourceChanges Stream

- **should emit new source each time an active switch occurs**
  - Method: `sourceChanges` getter + `_switchInternal`
  - Verify: Subscriber receives new source

- **should return a broadcast stream for sourceChanges**
  - Method: `sourceChanges` getter
  - Verify: Multiple subscribers receive independently

- **should emit heartbeat when switching from timer to heartbeat**
  - Method: `sourceChanges` getter via `trySwitchTo`
  - Verify: Emission value is `TickSource.heartbeat`

- **should emit timer when switching from heartbeat to timer**
  - Method: `sourceChanges` getter via `trySwitchTo`
  - Verify: Emission value is `TickSource.timer`

### Auto-Fallback on Heart Loss

- **should auto-switch to timer when heart loses active source**
  - Method: Constructor (internal `_healthSub`), `_switchInternal`
  - Setup: Switch to heartbeat, emit `false` from heart's `hasActiveSourceStream`
  - Verify: `source` getter returns `TickSource.timer`

- **should cancel heart subscription and activate clock when heart loses source**
  - Method: Constructor (internal subscription) via heart's `hasActiveSourceStream`
  - Verify: Clock subscription active, heart subscription cancelled

- **should emit sourceChanges when auto-fallback triggers**
  - Method: Constructor (internal `_healthSub`)
  - Verify: Subscriber receives `TickSource.timer`

- **should not auto-fallback when on timer and heart becomes unavailable**
  - Method: Constructor (internal `_healthSub`) condition check
  - Setup: Start on timer, heart sends `false`
  - Verify: No auto-switch (already on timer)

### dispose

- **should cancel active subscription**
  - Method: `dispose()`
  - Verify: Subscribers don't receive ticks after dispose

- **should cancel health monitoring subscription**
  - Method: `dispose()` (cancels `_healthSub`)
  - Verify: No auto-fallback after dispose

- **should close tickStream StreamController**
  - Method: `dispose()`
  - Verify: Subscriber receives done event

- **should close sourceChanges StreamController**
  - Method: `dispose()`
  - Verify: Subscriber receives done event

- **should dispose clock service**
  - Method: `dispose()` → calls `_clock.dispose()`
  - Verify: Clock's `dispose()` was called

- **should dispose heart service**
  - Method: `dispose()` → calls `_heart.dispose()`
  - Verify: Heart's `dispose()` was called

### Subscription Management & Edge Cases

- **should handle multiple subscribers to tickStream independently**
  - Method: `tickStream` getter (broadcast)
  - Verify: Remaining subscribers unaffected by one cancelling

- **should not leak subscriptions on failed switch attempt**
  - Method: `trySwitchTo` when switch fails
  - Verify: No subscription count growth on repeated failures

- **should properly handle rapid switches between sources**
  - Method: `trySwitchTo` + `_switchInternal` (cancellation logic)
  - Verify: Only one subscription active, ticks from current source

- **should cancel previous subscription before subscribing to new source**
  - Method: `_switchInternal` (order: cancel, then subscribe)
  - Verify: Only new source ticks received after switch

- **should not emit sourceChanges on heart's same-value transition**
  - Method: Constructor (internal `_healthSub`)
  - Setup: Switch to heartbeat, emit `true` then `true` again
  - Verify: No second auto-fallback or emission

## Gotchas

1. **Stream subscription lifecycle**: Constructor subscribes to clock and heart immediately. Both must be cancelled in `dispose()` or tests hang. Use `addTearDown()` or explicit cleanup.

2. **Broadcast streams**: Both `tickStream` and `sourceChanges` are broadcast. Late subscribers won't see historical emissions. Test multi-subscriber scenarios carefully.

3. **Auto-fallback condition**: Only triggers if `_activeSource == TickSource.heartbeat` AND heart emits `false`. If on timer, heart going silent is a no-op.

4. **No-op switch**: `trySwitchTo` with already-active source returns `true` but does NOT emit `sourceChanges`. Don't expect emissions in that scenario.

5. **Constructor state**: On construction, `_activeSource` is `TickSource.timer` and clock subscription is immediately active. Mock clock's `tickStream` to avoid real ticks.

6. **Disposal order**: `dispose()` cancels subs, closes controllers, then disposes clock and heart. Ensure mocks' `dispose()` methods don't error.

7. **Heart availability race**: If heart's `hasActiveSource` flips between `trySwitchTo` check and actual switch, check happens at call time (not atomic).

8. **Timer in ClockTickService**: `simulateTick()` starts a repeating timer. Constructor doesn't call it, so clock won't emit unless explicitly started. Use mocks to avoid side effects.
