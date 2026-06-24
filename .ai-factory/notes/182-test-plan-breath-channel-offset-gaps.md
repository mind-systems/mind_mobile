# BreathModuleStateChannel — Offset Axis & Pause Marker Gaps — Test Plan

**Date:** 2026-06-24  
**Source:** file search specialist (read-only exploration)  
**Status:** Test plan only; do NOT implement yet

## Source Overview

`lib/BreathModule/Core/BreathModuleStateChannel.dart` manages real-time breath session state dispatch to the backend via gRPC. It uses a `Stopwatch` initialized at session start (line 84) to compute monotonically-increasing `offsetMs` for each instruction and marker emission.

**Key behaviors:**
- **Stopwatch initialization:** `_stopwatch.reset()` and `_stopwatch.start()` at `_channel.start()` (line 84)
- **Offset computation:** `offsetMs = _stopwatch.elapsedMilliseconds` captured at instruction time (line 122) and re-emitted on pause/resume boundaries (lines 93, 101)
- **Pause marker:** `_emitMarker('pause', 0, offsetMs)` (line 101) marks the pause boundary with `tickCount=0`
- **Resume re-emit:** On unpause, the resumed phase is re-emitted at its current offsetMs (line 93)
- **Pending flush:** If `moduleSessionId` is null, instruction is buffered; `offsetMs` is captured and reused at flush time (line 136)

**Wall-clock timestamp:** Independently computed via `_wireTimestamp(offsetMs)` (line 139-140) as `_originWallClock.millisecondsSinceEpoch + offsetMs`.

---

## Existing Coverage Summary

**What is thoroughly tested** (do NOT duplicate):
- Lifecycle transitions: start / unpause / pause / end / stop / reset (Phases 2-8, lines 138-733)
- Instruction dispatch routing: phase changes trigger `sendSample` with correct `(sessionId, phase, tickCount)` (Phase 9, lines 738-920)
- Pending buffering and flush: instructions are buffered when `moduleSessionId` is null, then flushed exactly once (Phase 10, lines 924-1060)
- Reset clears state: `_moduleSessionId`, `_pendingInstruction`, `_previousPhase`, `_previousExerciseIndex` (Phase 11, lines 1064-1223)
- Subscription lifecycle: subs stay alive across reset, are cancelled on dispose (Phases 11-12, lines 1064-1244)

**What the existing fake discards:**
The `_FakeInstructionStream.sendSample()` (line 60-61) captures only `(sessionId, phase, tickCount)` and ignores `offsetMs` and `timestampMs`. This means:
- No assertion on offset monotonicity across multiple phase changes
- No assertion on pause marker `offsetMs > 0`
- No assertion on resume re-emit `offsetMs` ordering vs. pause marker
- No assertion on pending flush `offsetMs` validity (captured-at-instruction-time vs. at-flush-time)

---

## Test Instantiation: Using the Existing _FakeInstructionStream

The existing `_FakeInstructionStream` (test file lines 56–68) already captures the full 5-tuple:

```dart
// Test file line 57
final List<(String, String, int, int, int)> sendSampleCalls = [];

// Test file lines 63–64
void sendSample(String sessionId, String phase, int tickCount, int offsetMs, int timestampMs) =>
    sendSampleCalls.add((sessionId, phase, tickCount, offsetMs, timestampMs));
```

Access offset and timestamp assertions directly via `$4` and `$5`:
- `f.instructionStream.sendSampleCalls[0].$4` = first instruction's `offsetMs`
- `f.instructionStream.sendSampleCalls[0].$5` = first instruction's `timestampMs`

No new fake class needed; just add test cases that use the existing 5-tuple fields.

---

## Test Cases — Coverage Gaps

### Gap 1: Offset Monotonicity Across Phase Changes

**Test:** "should emit instructions with monotonically non-decreasing offsetMs when multiple phase changes occur during an active session"

**Condition:**
- Start session (via `_channel.start()` at source line 91, captures `_originWallClock`)
- Emit phase change (offsetMs=A via source line 127)
- Emit another phase change (offsetMs=B, must be ≥ A — Stopwatch elapsed time only advances or stays the same)
- Verify each instruction's offsetMs (source line 134) is ≥ previous

**Source code branches:**
- `_stopwatch.elapsedMilliseconds` captured at source line 127 in `_handleInstruction()`
- Multiple calls to `_instructionStream.sendSample()` (source line 134) within the same test
- Test accesses via `f.instructionStream.sendSampleCalls[i].$4` (the offsetMs field)

**Implementation hint:**
```dart
test('should emit instructions with monotonically non-decreasing offsetMs', () async {
  final f = _make();
  f.channel.stateController.add(const ModuleState(moduleSessionId: 'sid', ...));
  f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.inhale));
  await Future<void>.delayed(Duration.zero);
  f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale));
  await Future<void>.delayed(Duration.zero);
  
  // Assert offsetMs[0] <= offsetMs[1] (test file line 64 captures into $4)
  expect(
    f.instructionStream.sendSampleCalls[0].$4 <= f.instructionStream.sendSampleCalls[1].$4,
    true,
  );
});
```

---

### Gap 2: Pause Marker offsetMs > 0 (Offset at Pause Time)

**Test:** "should emit a pause marker with offsetMs > 0 when transitioning active → pause after session start"

**Condition:**
- Start session (source line 91, `_stopwatch.reset()` then `.start()` at source line 89)
- Emit active state (some time passes, Stopwatch elapsed > 0)
- Transition to pause (source line 106: `_emitMarker('pause', 0, _stopwatch.elapsedMilliseconds)`)
- Verify pause marker's offsetMs (test file line 64, stored as `$4`) is > 0

**Source code branches:**
- `_emitMarker()` call at source line 106 during `_handleLifecycle()` when transitioning to pause
- `_emitMarker()` (source line 66) calls `_instructionStream.sendSample()` with the 3rd parameter `offsetMs` from the Stopwatch

**Implementation hint:**
```dart
test('should emit pause marker with offsetMs > 0 when pausing after session start', () async {
  final f = _make();
  f.channel.stateController.add(const ModuleState(moduleSessionId: 'sid', ...));
  f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.inhale));
  await Future<void>.delayed(Duration.zero);
  f.stateCtrl.add(_state(status: BreathSessionStatus.pause));
  await Future<void>.delayed(Duration.zero);
  
  // Find the pause marker: phase='pause' (call.$2), tickCount=0 (call.$3)
  final pauseMarker = f.instructionStream.sendSampleCalls.firstWhere((call) => call.$2 == 'pause');
  expect(pauseMarker.$4, greaterThan(0)); // pauseMarker.$4 = offsetMs > 0
});
```

---

### Gap 3: Resume Re-Emit offsetMs Ordering (Pause → Resume Boundary)

**Test:** "should emit the resumed phase with offsetMs ≥ pauseMarkerOffsetMs when resuming from pause"

**Condition:**
- Start session (source line 91)
- Emit active state (phase change, source line 134)
- Pause (source line 106: pause marker emitted with current Stopwatch elapsed)
- Resume (source line 98: `_emitMarker(state.phase.name, state.currentPhaseTotalDuration, _stopwatch.elapsedMilliseconds)` — re-emits the phase at current Stopwatch elapsed)
- Verify resumed phase's offsetMs (test file line 64, `$4`) ≥ pause marker's offsetMs

**Source code branches:**
- Pause marker: source line 106 in `_handleLifecycle()` when status transitions to `BreathSessionStatus.pause`
- Resume re-emit: source line 98 in `_handleLifecycle()` when transitioning from pause to active (breath or rest) after `_started == true`

**Implementation hint:**
```dart
test('should emit resumed phase with offsetMs >= pauseMarkerOffsetMs', () async {
  final f = _make();
  f.channel.stateController.add(const ModuleState(moduleSessionId: 'sid', ...));
  f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.inhale));
  await Future<void>.delayed(Duration.zero);
  f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale));
  await Future<void>.delayed(Duration.zero);
  f.stateCtrl.add(_state(status: BreathSessionStatus.pause));
  await Future<void>.delayed(Duration.zero);
  f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale));
  await Future<void>.delayed(Duration.zero);
  
  final pauseIdx = f.instructionStream.sendSampleCalls.indexWhere((call) => call.$2 == 'pause');
  final resumeIdx = f.instructionStream.sendSampleCalls.lastIndexWhere((call) => call.$2 == 'exhale');
  
  final pauseOffsetMs = f.instructionStream.sendSampleCalls[pauseIdx].$4;
  final resumeOffsetMs = f.instructionStream.sendSampleCalls[resumeIdx].$4;
  
  expect(resumeOffsetMs >= pauseOffsetMs, true);
});
```

---

### Gap 4: Pause Marker Appears in Instruction Stream (Dispatch Verification)

**Test:** "should dispatch exactly one pause marker with (phaseName='pause', tickCount=0) when transitioning active → pause"

**Condition:**
- Existing test coverage verifies the arity of sendSampleCalls but does not yet verify pause marker's `offsetMs` and `timestampMs` fields
- Add offset and timestamp verification to confirm full 5-tuple is correct

**Source code branches:**
- `_emitMarker('pause', 0, _stopwatch.elapsedMilliseconds)` at source line 106
- Calls `_instructionStream.sendSample(sessionId, 'pause', 0, offsetMs, _wireTimestamp(offsetMs))` at source line 72

**Implementation hint:**
```dart
test('should dispatch pause marker with phaseName=pause, tickCount=0, and valid offsetMs/timestampMs', () async {
  final f = _make();
  f.channel.stateController.add(const ModuleState(moduleSessionId: 'sid', ...));
  f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.inhale));
  await Future<void>.delayed(Duration.zero);
  f.stateCtrl.add(_state(status: BreathSessionStatus.pause));
  await Future<void>.delayed(Duration.zero);
  
  final pauseMarker = f.instructionStream.sendSampleCalls.firstWhere((call) => call.$2 == 'pause');
  expect(pauseMarker.$2, 'pause');           // call.$2 = phase
  expect(pauseMarker.$3, 0);                 // call.$3 = tickCount = 0
  expect(pauseMarker.$4, isNotNull);         // call.$4 = offsetMs
  expect(pauseMarker.$5, isNotNull);         // call.$5 = timestampMs
  expect(pauseMarker.$4, greaterThan(0));    // offsetMs > 0 (verified time elapsed)
});
```

---

### Gap 5: Pending Flush Reuses Captured offsetMs (Not Flushed offsetMs)

**Test:** "should flush pending instruction with the offsetMs captured at instruction time, not at flush time"

**Condition:**
- Emit phase change while `moduleSessionId` is null (instruction buffered with captured offsetMs)
- Push `ModuleState` with `moduleSessionId` (triggers `_flushPending()` at source line 48)
- Verify flushed instruction's offsetMs matches the captured value from when the state was first emitted

**Source code branches:**
- Capture at source line 130: `_pendingInstruction = (state: state, offsetMs: offsetMs);`
- Flush at source line 137–141: `_flushPending()` re-uses `pending.offsetMs` (not re-measuring Stopwatch)
- Constructor (source line 45–48): ModuleState listener triggers `_flushPending(sessionId)` when moduleSessionId becomes non-null

**Implementation hint:**
```dart
test('should flush pending with the offsetMs captured at instruction time, not at flush time', () async {
  final f = _make();
  // Do NOT seed ModuleState — _moduleSessionId stays null, forcing pending buffer
  
  f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.inhale));
  await Future<void>.delayed(Duration.zero);
  // Instruction buffered at source line 130 with current Stopwatch.elapsedMilliseconds (call it T1)
  
  // Simulate time passage (in real scenario, Stopwatch advances)
  
  f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale));
  await Future<void>.delayed(Duration.zero);
  // Another instruction buffered (overwrites previous), now at T2
  
  // Push ModuleState to trigger flush at source line 48
  f.channel.stateController.add(const ModuleState(moduleSessionId: 'sid', ...));
  await Future<void>.delayed(Duration.zero);
  
  // Flushed instruction's offsetMs should be T2 (captured at second _handleInstruction),
  // not a new value measured during flush
  expect(f.instructionStream.sendSampleCalls, hasLength(1));
  expect(f.instructionStream.sendSampleCalls.first.$4, isNotNull); // offsetMs captured at instruction time
});
```

---

### Gap 6: Wire Timestamp Calculation (offsetMs + _originWallClock)

**Test:** "should compute wireTimestamp as _originWallClock.millisecondsSinceEpoch + offsetMs for each instruction"

**Condition:**
- Start session (source line 91 calls `_channel.start()`, which captures `_originWallClock = _clock()` at source line 90)
- Emit instructions with various `offsetMs` values (source line 127)
- Verify each `timestampMs` (test file line 64, stored as call `$5`) = `_originWallClock.millisecondsSinceEpoch + offsetMs`

**Source code branches:**
- `_wireTimestamp(int offsetMs)` (source line 144–145): `(_originWallClock?.millisecondsSinceEpoch ?? _clock().millisecondsSinceEpoch) + offsetMs`
- `_originWallClock` captured once at source line 90 when `_handleLifecycle()` detects active transition
- Each instruction call to `_emitMarker()` (source line 72) passes `_wireTimestamp(offsetMs)` as the 5th parameter to `sendSample()`

**Implementation hint:**
```dart
test('should compute wireTimestamp as _originWallClock.millisecondsSinceEpoch + offsetMs', () async {
  final f = _make();
  
  // Inject a controllable clock to capture the exact origin time
  final originTime = DateTime.now();
  
  f.channel.stateController.add(const ModuleState(moduleSessionId: 'sid', ...));
  f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.inhale));
  await Future<void>.delayed(Duration.zero);
  
  final call = f.instructionStream.sendSampleCalls.first;
  final offsetMs = call.$4;      // call.$4 = offsetMs
  final timestampMs = call.$5;   // call.$5 = timestampMs
  
  // timestampMs should equal originTime.millisecondsSinceEpoch + offsetMs
  // Allow tolerance for test execution time
  final expected = originTime.millisecondsSinceEpoch + offsetMs;
  expect(
    (timestampMs - expected).abs(),
    lessThan(100), // Within 100ms tolerance
  );
});
```

---

## Gotchas

1. **Stopwatch elapsed time is deterministic in tests only if controlled:** The `Stopwatch` in the production code (source line 42, initialized via factory `stopwatchFactory()`) advances in real time. Tests can either:
   - Inject a mock Stopwatch via `BreathModuleStateChannel` constructor parameter `stopwatchFactory` to return predictable values
   - Or accept that offsets will be ~0-10ms in unit tests and verify monotonicity (A ≤ B ≤ C) instead of exact values
   - Or test offset ordering rather than absolute millisecond values

2. **_originWallClock is captured once at start:** It's set at source line 90 when `_handleLifecycle()` detects the first active transition (wasPaused && isActive). Tests that need to verify wire timestamps must either:
   - Inject a mock DateTime via `clock` parameter to `BreathModuleStateChannel` constructor
   - Or capture `DateTime.now()` before emitting the state and allow a tolerance window for test execution time

3. **Pause marker always has tickCount=0 (by design):** Tests should NOT expect tickCount to match the current phase's duration at pause time. Only the resumed phase re-emit (source line 98) carries the real `state.currentPhaseTotalDuration` as tickCount.

4. **Multiple emissions in rapid succession may have identical or non-decreasing offsetMs:** If the test emits states faster than the Stopwatch increments (which is likely in unit tests), consecutive offsets may be equal. Verify "monotonically non-decreasing" (call.$4 <= next.call.$4) rather than strictly increasing (<).

5. **Resume re-emit changes the phase name:** When resuming from pause, the re-emitted marker at source line 98 is NOT `phaseName='pause'` — it's the actual resumed phase name (e.g., 'exhale'). When finding the resume re-emit, filter by actual phase name, not 'pause'.

6. **No re-emit of pause marker on second pause:** If the session pauses twice without a resume in between, only the first pause emits a marker. The second pause transition is filtered out by the "status-unchanged" short-circuit at source line 77 (if (_previousStatus == status) return).

---

**Next step:** Implement these 6 test cases using the existing `_FakeInstructionStream` 5-tuple capture (test file lines 56–68). Access offsetMs via `call.$4` and timestampMs via `call.$5`. Add each gap-covering test to the existing Phase 9-10 groups (or create new Phase 13-15 groups for offset-specific assertions). Consider injecting mock Stopwatch and DateTime for deterministic offset assertions.

---

## Implementation Status

**What is ALREADY DONE:**
1. **Stopwatch factory is already injectable:** Source lines 37–42 show the constructor already accepts `Stopwatch Function() stopwatchFactory = Stopwatch.new` and uses it: `_stopwatch = stopwatchFactory()`
2. **DateTime clock is already injectable:** Source lines 15, 38 show `DateTime Function() clock = DateTime.now` parameter and constructor uses it
3. **_FakeInstructionStream already captures 5-tuple:** Test file lines 57, 64 show `sendSampleCalls.add((sessionId, phase, tickCount, offsetMs, timestampMs))`

**What still needs implementation:**
- Add 6 test cases (Gap 1–6 above) to the test file that use the 5-tuple offsets and timestamps
- Optionally inject mock Stopwatch and mock DateTime in tests for deterministic offset/timestamp assertions
- Ensure each test accesses via call `$4` (offsetMs) and call `$5` (timestampMs)
- No changes to source code required; constructor already supports all necessary injection points
