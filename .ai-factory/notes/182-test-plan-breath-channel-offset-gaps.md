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

## Test Instantiation: Extending _FakeInstructionStream

To capture `offsetMs` and `timestampMs`, extend the fake:

```dart
class _FakeInstructionStreamWithOffsets implements BreathModuleInstructionStream {
  /// Captures (sessionId, phase, tickCount, offsetMs, timestampMs)
  final List<(String, String, int, int, int)> sendSampleCalls = [];

  @override
  void sendSample(String sessionId, String phase, int tickCount, int offsetMs, int timestampMs) =>
      sendSampleCalls.add((sessionId, phase, tickCount, offsetMs, timestampMs));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

Use this in a new fixture or modify existing tests where offset assertions are needed.

---

## Test Cases — Coverage Gaps

### Gap 1: Offset Monotonicity Across Phase Changes

**Test:** "should emit instructions with strictly monotonically increasing offsetMs when multiple phase changes occur during an active session"

**Condition:**
- Start session (offsetMs=0)
- Emit phase change (offsetMs=A)
- Wait (simulated by advancing in test, or relying on Stopwatch elapsed time)
- Emit another phase change (offsetMs=B, must be > A)
- Verify no instruction has a lower or equal offsetMs than the previous

**Fields/branches:**
- `_stopwatch.elapsedMilliseconds` (line 122)
- Ordering of multiple `_handleInstruction()` calls across consecutive state emissions

**Implementation hint:**
```dart
test('should emit instructions with strictly monotonically increasing offsetMs', () async {
  // Use _FakeInstructionStreamWithOffsets
  final f = _make() with extended fake;
  f.channel.stateController.add(const ModuleState(moduleSessionId: 'sid', ...));
  f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.inhale));
  // Simulate time passage or manually manipulate Stopwatch (if testable)
  f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale, ...));
  
  // Assert offsetMs[0] < offsetMs[1]
  expect(f.instructionStream.sendSampleCalls[0].$4 < f.instructionStream.sendSampleCalls[1].$4, true);
});
```

---

### Gap 2: Pause Marker offsetMs > 0 (Offset at Pause Time)

**Test:** "should emit a pause marker with offsetMs > 0 when transitioning active → pause after session start"

**Condition:**
- Start session (at t=0, offsetMs=0)
- Emit an instruction (phase changes, offsetMs > 0)
- Transition to pause (pause marker offsetMs must be > 0)
- Verify pause marker's offsetMs is not zero

**Fields/branches:**
- `_emitMarker('pause', 0, _stopwatch.elapsedMilliseconds)` (line 101)
- Ensures the Stopwatch has actually elapsed time, not a race condition where pause arrives at offsetMs=0

**Implementation hint:**
```dart
test('should emit pause marker with offsetMs > 0 when pausing after session start', () async {
  final f = _make() with extended fake;
  f.channel.stateController.add(const ModuleState(moduleSessionId: 'sid', ...));
  f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.inhale));
  f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale, ...));
  f.stateCtrl.add(_state(status: BreathSessionStatus.pause));
  
  // Find the pause marker (phase='pause', tickCount=0)
  final pauseMarker = f.instructionStream.sendSampleCalls.firstWhere((call) => call.$2 == 'pause');
  expect(pauseMarker.$4, greaterThan(0)); // offsetMs > 0
});
```

---

### Gap 3: Resume Re-Emit offsetMs Ordering (Pause → Resume Boundary)

**Test:** "should emit the resumed phase with offsetMs > pauseMarkerOffsetMs when resuming from pause"

**Condition:**
- Start session
- Emit instructions (build up a positive offsetMs)
- Pause (pause marker at offsetMs=P)
- Resume (resumed phase re-emitted at offsetMs=R)
- Verify R > P (monotonicity across pause boundary)

**Fields/branches:**
- `_emitMarker(state.phase.name, state.currentPhaseTotalDuration, _stopwatch.elapsedMilliseconds)` (line 93)
- Ensures the resumed phase's offsetMs is recorded after the pause marker

**Implementation hint:**
```dart
test('should emit resumed phase with offsetMs > pauseMarkerOffsetMs', () async {
  final f = _make() with extended fake;
  f.channel.stateController.add(const ModuleState(moduleSessionId: 'sid', ...));
  f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.inhale));
  f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale, ...));
  f.stateCtrl.add(_state(status: BreathSessionStatus.pause)); // Emit pause marker
  f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale, ...)); // Resume
  
  final pauseIdx = f.instructionStream.sendSampleCalls.indexWhere((call) => call.$2 == 'pause');
  final resumeIdx = f.instructionStream.sendSampleCalls.lastIndexWhere((call) => call.$2 == 'exhale' && call.$4 > f.instructionStream.sendSampleCalls[pauseIdx].$4);
  
  expect(
    f.instructionStream.sendSampleCalls[resumeIdx].$4 > f.instructionStream.sendSampleCalls[pauseIdx].$4,
    true,
  );
});
```

---

### Gap 4: Pause Marker Appears in Instruction Stream (Dispatch Verification)

**Test:** "should dispatch exactly one pause marker with (phaseName='pause', tickCount=0) when transitioning active → pause"

**Condition:**
- The existing test at line 823-844 checks the arity (2 calls total) but doesn't verify the pause marker's `offsetMs` field. Add offset verification.

**Fields/branches:**
- `_emitMarker()` call path from `_handleLifecycle()` (line 101)
- Confirms pause is captured in the instruction stream with correct phase name and tick count

**Implementation hint:**
```dart
test('should include pause marker in sendSampleCalls with phaseName=pause and tickCount=0', () async {
  final f = _make() with extended fake;
  f.channel.stateController.add(const ModuleState(moduleSessionId: 'sid', ...));
  f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.inhale));
  f.stateCtrl.add(_state(status: BreathSessionStatus.pause, phase: BreathPhase.exhale));
  
  final pauseMarker = f.instructionStream.sendSampleCalls.firstWhere((call) => call.$2 == 'pause');
  expect(pauseMarker.$3, 0); // tickCount=0
  expect(pauseMarker.$4, isNotNull); // offsetMs is not null
  expect(pauseMarker.$5, isNotNull); // timestampMs is not null
});
```

---

### Gap 5: Pending Flush Reuses Captured offsetMs (Not Flushed offsetMs)

**Test:** "should flush pending instruction with the offsetMs captured at instruction time, not at flush time"

**Condition:**
- Emit phase change while `moduleSessionId` is null (instruction buffered with captured offsetMs=C)
- Wait (simulate time passage)
- Push `ModuleState` with `moduleSessionId` (triggers flush)
- Verify flushed `offsetMs` equals C, not a new value measured at flush time

**Fields/branches:**
- `_pendingInstruction = (state: state, offsetMs: offsetMs)` (line 125) — capture happens here
- `_flushPending()` (line 136) — reuse captured offsetMs
- Ensures the offset is frozen at instruction-capture time, not updated at flush time

**Implementation hint:**
```dart
test('should flush pending with the offsetMs from capture time, not flush time', () async {
  final f = _make() with extended fake;
  // No ModuleState seeded — _moduleSessionId stays null
  f.stateCtrl.add(_state(status: BreathSessionStatus.pause, phase: BreathPhase.inhale));
  
  // Record time before instruction (for debugging; Stopwatch would be advanced in real scenario)
  f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.exhale, ...));
  await Future<void>.delayed(Duration.zero);
  
  // At this point, instruction is buffered with some offsetMs (C)
  // Simulate a delay (in real test, you'd need to manually control Stopwatch or measure elapsed)
  
  // Now push ModuleState — triggers flush with the captured offsetMs
  f.channel.stateController.add(const ModuleState(moduleSessionId: 'sid', ...));
  
  // The flushed call's offsetMs should match the captured value
  // In a deterministic test, you can:
  // 1. Mock/spy the Stopwatch.elapsedMilliseconds to return predictable values
  // 2. Or manually verify the offsetMs in the flushed call is consistent
  
  expect(f.instructionStream.sendSampleCalls, hasLength(1));
  expect(f.instructionStream.sendSampleCalls.first.$4, isNotNull); // offsetMs exists
});
```

---

### Gap 6: Wire Timestamp Calculation (offsetMs + _originWallClock)

**Test:** "should compute wireTimestamp as _originWallClock.millisecondsSinceEpoch + offsetMs for each instruction"

**Condition:**
- Start session (capture `_originWallClock` at line 85)
- Emit instructions with various `offsetMs` values
- Verify each `timestampMs` = `_originWallClock + offsetMs`

**Fields/branches:**
- `_wireTimestamp(int offsetMs)` (line 139-140)
- `_originWallClock` is captured once at start (line 85)
- Each instruction call to `_emitMarker()` or direct `sendSample()` passes `_wireTimestamp(offsetMs)` as the 5th argument

**Implementation hint:**
```dart
test('should compute wireTimestamp as _originWallClock.millisecondsSinceEpoch + offsetMs', () async {
  final f = _make() with extended fake;
  final originTime = DateTime.now().millisecondsSinceEpoch;
  
  f.channel.stateController.add(const ModuleState(moduleSessionId: 'sid', ...));
  f.stateCtrl.add(_state(status: BreathSessionStatus.breath, phase: BreathPhase.inhale));
  
  final call = f.instructionStream.sendSampleCalls.first;
  final offsetMs = call.$4;
  final timestampMs = call.$5;
  
  // timestampMs should be approximately originTime + offsetMs
  // (allow small tolerance for test execution time)
  expect(
    (timestampMs - (originTime + offsetMs)).abs(),
    lessThan(100), // Within 100ms tolerance
  );
});
```

---

## Gotchas

1. **Stopwatch elapsed time is deterministic in tests only if controlled:** The `Stopwatch` in the production code advances in real time. Tests cannot easily control it without mocking. Consider:
   - Mock or spy the `_stopwatch` to return predictable values
   - Or accept that offsets will be ~0-10ms in unit tests and verify monotonicity instead of exact values
   - Or test the offset ordering (A < B < C) rather than absolute values

2. **_originWallClock is captured once at start:** It's set at line 85 when `_channel.start()` is called. Tests that need to verify wire timestamps must capture the wall-clock time before/after state emission and compare against the expected origin.

3. **Pause marker always has tickCount=0 (by design):** Tests should NOT expect tickCount to match the current phase's duration; only the resumed phase re-emit carries the real tickCount.

4. **Multiple emissions in rapid succession may have identical offsetMs:** If the test emits states faster than the Stopwatch increments (which is likely in unit tests), consecutive offsets may be equal. Verify "monotonically non-decreasing" (≤) rather than strictly increasing (<).

5. **Resume re-emit changes the phase name:** When resuming from pause, the re-emitted marker is NOT `phaseName='pause'` — it's the actual phase name (e.g., 'exhale'). Don't filter by phase='pause' when looking for the resume re-emit.

6. **No re-emit of pause marker on second pause:** If the session pauses twice without a resume in between, only the first pause emits a marker. The second pause is filtered out by the "status-unchanged" short-circuit at line 72.

---

**Next step:** Implement these test cases by extending `_FakeInstructionStream` to capture offsets, then add each gap-covering test to the existing groups (Phase 9-10) or create new groups for offset-specific assertions.


## Refactor Required

**What to refactor:** Two changes needed in `BreathModuleStateChannel`:

1. **Inject Stopwatch factory:**
```dart
BreathModuleStateChannel(
  IModuleStateChannel channel,
  IBreathModuleInstructionStream instructionStream,
  Stream<BreathSessionState> stateStream, {
  Stopwatch Function() stopwatchFactory = Stopwatch.new,
  DateTime Function() clock = DateTime.now,
})
// internal:
_stopwatch = stopwatchFactory();
_originWallClock = clock();
```

2. **Extend `_FakeInstructionStream` in the test file** to capture the full 5-tuple:
```dart
// before
void sendSample(String sessionId, String phase, int tickCount, int offsetMs, int timestampMs) =>
    sendSampleCalls.add((sessionId, phase, tickCount));

// after
void sendSample(String sessionId, String phase, int tickCount, int offsetMs, int timestampMs) =>
    sendSampleCalls.add((sessionId, phase, tickCount, offsetMs, timestampMs));
```
Update existing assertions in the test file from 3-tuple to 5-tuple (offsetMs/timestampMs already discarded = 0 for existing tests is fine; they just need to destructure the new shape).

**What the test implementer gets:**
- Inject a `FakeStopwatch` (controllable `elapsedMilliseconds`) to assert `offsetMs` values exactly.
- Inject a `FakeClock` to assert `_originWallClock` capture and `_wireTimestamp` computation.
- Assert pause marker `offsetMs > 0`; assert resume re-emit `offsetMs ≥ pause marker offsetMs`; assert captured timestamp stored at `_handleInstruction` time reused by `_flushPending`.
