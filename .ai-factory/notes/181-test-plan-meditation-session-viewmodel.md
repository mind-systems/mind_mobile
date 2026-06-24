# MeditationSessionViewModel — Test Plan

**Date:** 2026-06-24
**Source:** roadmap-test-coverage agent  
**Status:** 0 existing tests (test/ directory empty)

---

## Source Overview

**File:** `packages/meditation_module/lib/src/MeditationSession/MeditationSessionViewModel.dart`

The `MeditationSessionViewModel` is a Riverpod `Notifier<MeditationSessionState>` that manages a meditation session lifecycle. It exposes:

- **`elapsedSeconds`:** `ValueNotifier<int>` — wall-clock elapsed time, computed as `_clock().difference(_startedAt).inSeconds` (resets to 0 on `start()`)
- **`stream`:** `Stream<MeditationSessionState>` — emits state changes (status: `idle` ↔ `active`)
- **`build()`:** initializes state to `MeditationSessionState.initial(poseId: poseId)`, sets up disposal callbacks
- **`start()`:** sets `_startedAt = _clock()`, arms 1-second periodic timer, resets `elapsedSeconds.value = 0`, sets status to `active`
- **`stop()`:** cancels timer, clears `_startedAt`, sets status to `idle` (does NOT reset `elapsedSeconds`)

**Key timer mechanism (lines 48–51):**
```dart
_startedAt = _clock();  // line 48
elapsedSeconds.value = 0;  // line 49
_timer = _timerFactory(const Duration(seconds: 1), (_) {  // line 50
  elapsedSeconds.value = _clock().difference(_startedAt!).inSeconds;  // line 51
});
```

This recomputes elapsed time on every tick as a **wall-clock delta**, not an accumulator.

**State model:** `MeditationSessionState` holds two fields:
- `status: MeditationSessionStatus` (enum: `idle`, `active`)
- `poseId: String`

---

## Instantiation

The ViewModel is instantiated via Riverpod:

```dart
final meditationSessionViewModelProvider =
    NotifierProvider<MeditationSessionViewModel, MeditationSessionState>(() {
  throw UnimplementedError('must be overridden via ProviderScope');
});
```

For testing, we inject via `ProviderScope` or mock the provider. Constructor (lines 12–17):

```dart
MeditationSessionViewModel({
  required this.poseId,
  DateTime Function() clock = DateTime.now,
  Timer Function(Duration, void Function(Timer)) timerFactory = Timer.periodic,
})
```

**Dependencies injected explicitly:** Three parameters—`poseId` (required), `clock` (injectable with default), and `timerFactory` (injectable with default). NO service dependency.

---

## Existing Coverage

**None.** The meditation_module test/ directory does not exist. Must create `packages/meditation_module/test/` and `packages/meditation_module/test/meditation_session_viewmodel_test.dart`.

---

## Test Cases

All tests require `flutter_test` and `fake_async` package. `fake_async` is in the root pubspec.yaml (v1.3.3) but must be added to `packages/meditation_module/pubspec.yaml` as a dev dependency. Create `packages/meditation_module/test/meditation_session_viewmodel_test.dart`.

### Group 1: Initialization & Disposal

#### Test 1.1: should initialize state to idle with poseId
**Setup:**
- Instantiate `MeditationSessionViewModel(poseId: 'test-pose')`
- Call `build()`

**Assertion:**
- `state.status == MeditationSessionStatus.idle`
- `state.poseId == 'test-pose'`
- `elapsedSeconds.value == 0`
- `_timer == null`

**Gotcha:** No injection needed; straightforward.

---

#### Test 1.2: should dispose stream controller and cancel timer on dispose
**Setup:**
- Instantiate and build
- Call `start()` (arms timer)
- Call `ref.onDispose()` callback

**Assertion:**
- `_stateController.isClosed == true`
- `_timer == null` (or cancelled)
- No exception when disposing `elapsedSeconds`

**Gotcha:** Requires Riverpod `ProviderContainer` to trigger disposal callbacks. Use `ProviderContainer` in a tear-down fixture.

---

### Group 2: Wall-Clock Elapsed Delta (Core Regression Guard)

This group directly addresses the silent-failure risk: if a future dev accidentally reverts `elapsedSeconds.value = DateTime.now().difference(_startedAt!).inSeconds` back to an ++ accumulator, only wall-clock gap tests catch it.

#### Test 2.1: should compute elapsedSeconds as wall-clock delta (now − startedAt)
**Setup:**
- Use `FakeAsync` from `package:fake_async`
- Instantiate and build
- Inside `fakeAsync`, call `start()` at time T=0
- Advance clock by 2500ms (2.5 seconds)

**Assertion:**
- `elapsedSeconds.value == 2` (timer has fired twice: at T=1s and T=2s)

**Code template:**
```dart
testWidgets('should compute elapsedSeconds as wall-clock delta', (tester) async {
  fakeAsync((async) {
    final vm = MeditationSessionViewModel(poseId: 'test-pose');
    vm.build();
    
    vm.start();
    async.elapse(const Duration(milliseconds: 2500));
    
    expect(vm.elapsedSeconds.value, 2);
    
    async.flushMicrotasks();
  });
});
```

**Critical:** This test **must use `FakeAsync`** to verify the relationship `elapsedSeconds = now − startedAt`. If the code is later changed to an accumulator (e.g., `elapsedSeconds.value++`), real-time tests might not fail for hours, but a wall-clock gap test will fail immediately.

---

#### Test 2.2: should catch up correctly after process suspension (simulated as clock jump)
**Setup:**
- Use `FakeAsync`
- Call `start()` at T=0
- Advance to T=5s (timer fires; elapsedSeconds = 5)
- Simulate suspension by NOT calling timer for 10 seconds
- Advance clock to T=15s (timer re-fires)

**Assertion:**
- After T=15s, `elapsedSeconds.value == 15` (not 5+1=6)
- No stutter or backslide in elapsed time

**Rationale:** The wall-clock delta mechanism handles gaps naturally; an accumulator would require explicit "resume" logic.

---

### Group 3: Stop/Start Re-Arming

#### Test 3.1: should clear _startedAt and reset elapsedSeconds to 0 on stop()
**Setup:**
- Call `start()`
- Advance time to T=3s (elapsedSeconds = 3)
- Call `stop()`

**Assertion:**
- `elapsedSeconds.value == 3` (value persists in the notifier)
- `_timer == null` (no active timer)
- `_startedAt == null` (cleared)

**Note:** The test confirms that `stop()` cancels the timer but does NOT reset `elapsedSeconds` to 0. That's a design choice (the last measured value persists). If the spec changes to reset on stop, update this assertion.

---

#### Test 3.2: should re-arm timer and reset elapsed to 0 when start() called after stop()
**Setup:**
- Call `start()`
- Advance to T=3s
- Call `stop()`
- Call `start()` again at T=10s (wall-clock time)
- Advance to T=12s

**Assertion:**
- `elapsedSeconds.value == 2` (reset to 0 and counted up 2 seconds since the second start())
- Timer is active
- `_startedAt` is set to the new `DateTime.now()` (the restart time)

**Code template:**
```dart
testWidgets('should re-arm timer on restart after stop', (tester) async {
  fakeAsync((async) {
    final vm = MeditationSessionViewModel(poseId: 'test-pose');
    vm.build();
    
    vm.start();
    async.elapse(const Duration(seconds: 3));
    
    vm.stop();
    expect(vm.elapsedSeconds.value, 3); // persists
    
    vm.start();
    async.elapse(const Duration(seconds: 2));
    
    expect(vm.elapsedSeconds.value, 2); // reset and recounted
  });
});
```

---

#### Test 3.3: should transition status idle ↔ active on start/stop
**Setup:**
- Build (status = idle)
- Call `start()` (status should change to active)
- Call `stop()` (status should change to idle)

**Assertion:**
- After `start()`: `state.status == MeditationSessionStatus.active`
- After `stop()`: `state.status == MeditationSessionStatus.idle`
- Each state change is emitted to `stream`

---

### Group 4: UI Refresh Cadence

#### Test 4.1: should emit state changes to stream
**Setup:**
- Listen to `stream`
- Call `start()`
- Call `stop()`

**Assertion:**
- `stream` emits state with `status == active` after `start()`
- `stream` emits state with `status == idle` after `stop()`

**Code template:**
```dart
test('should emit state changes to stream', () {
  final vm = MeditationSessionViewModel(poseId: 'test-pose');
  vm.build();
  
  final states = <MeditationSessionState>[];
  vm.stream.listen(states.add);
  
  vm.start();
  vm.stop();
  
  expect(states, [
    isA<MeditationSessionState>().having((s) => s.status, 'status', MeditationSessionStatus.active),
    isA<MeditationSessionState>().having((s) => s.status, 'status', MeditationSessionStatus.idle),
  ]);
});
```

---

#### Test 4.2: should NOT emit duplicate states
**Setup:**
- Listen to stream
- Call `start()` → `start()` again without stopping

**Assertion:**
- No duplicate `active` states emitted (or clarify spec if duplicates are expected)

**Note:** Current code calls `state = state.copyWith(status: active)` every time `start()` is called. Verify whether duplicates should be filtered.

---

### Group 5: Accumulator Regression Guard (Critical Test)

This is the **highest-priority regression test**. It exists because `DateTime.now().difference(_startedAt!).inSeconds` is the only way to catch an accidental revert to `elapsedSeconds.value++`.

#### Test 5.1: REGRESSION — elapsedSeconds must NOT use accumulator pattern
**Setup:**
- Use `FakeAsync` (this is required)
- Call `start()`
- Advance 1 second
- Manually set `elapsedSeconds.value = 99` (simulate external interference)
- Advance 1 more second (timer fires again)

**Assertion:**
- `elapsedSeconds.value == 2` (computed from wall-clock delta, not `99 + 1 = 100`)

**Rationale:** If the code is changed to `elapsedSeconds.value++`, it would compute `100` instead of `2`. This test forces the wall-clock-delta behavior to be explicit.

**Code template:**
```dart
testWidgets('REGRESSION: elapsedSeconds must use wall-clock delta, not accumulator', (tester) async {
  fakeAsync((async) {
    final vm = MeditationSessionViewModel(poseId: 'test-pose');
    vm.build();
    
    vm.start();
    async.elapse(const Duration(seconds: 1));
    expect(vm.elapsedSeconds.value, 1);
    
    // Simulate external interference: set value to garbage
    vm.elapsedSeconds.value = 99;
    
    // Timer fires again; if code uses accumulator (++), it becomes 100.
    // If code uses wall-clock delta, it becomes 2.
    async.elapse(const Duration(seconds: 1));
    
    expect(vm.elapsedSeconds.value, 2, 
      reason: 'elapsedSeconds must be computed as DateTime.now().difference(_startedAt).inSeconds, not an accumulator');
  });
});
```

---

## Gotchas

### Status: DateTime.now() IS ALREADY INJECTED

**RESOLVED (no action needed):** Lines 14–16 show `DateTime` and `Timer` are already injectable:
```dart
MeditationSessionViewModel({
  required this.poseId,
  DateTime Function() clock = DateTime.now,  // line 14 — injectable with default
  Timer Function(Duration, void Function(Timer)) timerFactory = Timer.periodic,  // line 15 — injectable
})
```

**Current code uses `_clock()`** on line 48 (not hardcoded `DateTime.now()`). The "Critical Blocker" section from the initial test plan was based on code that has already been refactored. No further refactoring needed.

**Tests 2.1, 2.2, and 5.1 can now:**
1. Inject a fake clock directly in the constructor without subclassing
2. Example: `MeditationSessionViewModel(poseId: 'test', clock: () => fakeTime)`
3. Still use `FakeAsync` for advanced scenarios (e.g., timer callback ordering verification)

---

### Secondary Gotcha: StreamController.isClosed may not reflect true state

In test 1.2, verifying `_stateController.isClosed` requires direct access to the ViewModel. Use a Riverpod `ProviderContainer` and call `container.dispose()` to trigger `ref.onDispose()` callbacks.

**Code template:**
```dart
testWidgets('should dispose stream controller on dispose', (tester) async {
  final container = ProviderContainer();
  
  // Build the provider
  final state = container.read(meditationSessionViewModelProvider);
  
  // Trigger disposal
  container.dispose();
  
  // Verify stream is closed (may need reflection or a test helper)
});
```

---

### Tertiary Gotcha: stop() does NOT reset elapsedSeconds to 0

The current design preserves the last elapsed value after `stop()`. If the spec changes, update Test 3.1 and 3.2 assertions accordingly.

---

## Recommendation

**Implement in this order:**

1. **Refactor DateTime.now() injection** (Option A or B above) — **do this before writing tests**
2. **Write all tests with FakeAsync** (tests 2.1, 2.2, 5.1)
3. **Add integration tests** for full session lifecycle: start → active → (pause?) → stop → restart
4. **Add listener verification** for `elapsedSeconds.value` notifier changes (listeners fire on every tick)

---

## Refactor Status: ALREADY COMPLETE

**No refactoring needed.** The constructor (lines 12–17) already has injectable `clock` and `timerFactory` parameters with sensible defaults.

**Current API (already supports testing):**
```dart
MeditationSessionViewModel({
  required this.poseId,
  DateTime Function() clock = DateTime.now,
  Timer Function(Duration, void Function(Timer)) timerFactory = Timer.periodic,
})
```

**What test implementers get (already available):**
- Pass a fake clock function: `MeditationSessionViewModel(poseId: 'test', clock: () => DateTime(2026, 6, 24, 12, 0, 0))`
- Pass a fake timer factory to control callback timing without real 1-second waits
- Can verify `elapsedSeconds = now − _startedAt` (wall-clock delta) by controlling clock advance independent of timer callback firing
- Key regression guard: advance fake clock by 30 s but fire only 5 timer callbacks → `elapsedSeconds` must be 30 (wall-clock), not 5 (accumulator)

**No IMeditationSessionService in constructor.** The ViewModel is self-contained for session timing; it does not depend on an external service.
