# BehaviorSubject Replay Poisons `_previousPhase` — Fix for First Instruction Drop

**Date:** 2026-06-05
**Source:** conversation context

## Key Findings

- `BreathModuleStateChannel` subscribes to a BehaviorSubject in its constructor; the subject **synchronously replays** its current value before the constructor returns, setting `_previousPhase` and `_previousExerciseIndex` to the pre-session state.
- When the session actually starts, the phase is the same as the replayed value, so `phaseChanged = false` and `rest` is never sent — the gRPC instruction stream is never opened.
- Because the stream is never opened at T=0, `inhale` (at T=15s) becomes the **first message on a new stream** and hits the gRPC race condition (server not yet subscribed to the Subject) — inhale is lost too.
- Fix: reset `_previousPhase = null` and `_previousExerciseIndex = null` inside `_handleLifecycle` at the exact moment `_started` transitions to `true`. This causes `rest` to be detected as a phase change, opens the stream at T=0, and by the time `inhale` arrives 15 seconds later the server has long since subscribed — inhale is received correctly.
- The null fix does NOT fix `rest` itself — `rest` is still the first message on the stream and still hits the gRPC race condition. To store `rest` correctly, a separate probe/ACK mechanism is also needed.

## Details

### Variable Lifecycle: Healthy Scenario (no BehaviorSubject replay poisoning)

```
Object created → _previousPhase = null, _previousExerciseIndex = null

Session starts → state machine emits first active state (phase=rest, exerciseIndex=0)
  _onState called:
    _handleLifecycle → _started = true
    _handleInstruction:
      phaseChanged = (rest != null) = true  ✓
      → instruction queued / sent
    _previousPhase = rest
    _previousExerciseIndex = 0

Tick 2 → state machine emits (phase=rest, exerciseIndex=0) [same, still in rest phase]
  _handleInstruction:
    phaseChanged = (rest != rest) = false  ✓ correct skip
```

### Variable Lifecycle: Poisoned Scenario (BehaviorSubject replay, NO fix)

```
Object created → _previousPhase = null, _previousExerciseIndex = null

Constructor executes: _stateSub = stateStream.listen(_onState)
  BehaviorSubject SYNCHRONOUSLY replays current value:
    Current state: status=pause, phase=rest, exerciseIndex=0
    _onState called INSIDE THE CONSTRUCTOR:
      _handleLifecycle → status=pause, _previousStatus=null → wasPaused=true, isActive=false
        → no action (session not started)
      _handleInstruction → isActive=false → early return
      _previousPhase = rest     ← POISONED
      _previousExerciseIndex = 0 ← POISONED

Object construction completes. _previousPhase is already 'rest'.

Session starts → state machine emits (status=breath/rest, phase=rest, exerciseIndex=0)
  _onState called:
    _handleLifecycle → _started = true
    _handleInstruction:
      phaseChanged = (rest != rest) = false  ✗ WRONG — silently drops first instruction
    _previousPhase = rest (unchanged)
```

### Variable Lifecycle: Fixed Scenario (null reset on `_started` transition)

```
Constructor executes: stateStream.listen(_onState)
  BehaviorSubject replays → _previousPhase = rest, _previousExerciseIndex = 0 (poisoned, same as before)

Session starts → state machine emits (status=breath/rest, phase=rest, exerciseIndex=0)
  _onState called:
    _handleLifecycle:
      wasPaused && isActive → !_started → _started = true
      _previousPhase = null      ← RESET HERE (fix applied)
      _previousExerciseIndex = null ← RESET HERE
    _handleInstruction:
      phaseChanged = (rest != null) = true  ✓ instruction sent
    _previousPhase = rest
    _previousExerciseIndex = 0
```

### Why the Reset Is in `_handleLifecycle`, Not `_handleInstruction`

`_onState` calls `_handleLifecycle` first, then `_handleInstruction`. The null reset must happen in `_handleLifecycle` so that by the time `_handleInstruction` evaluates `phaseChanged`, `_previousPhase` is already null.

If the reset were placed at the top of `_handleInstruction`, it would also work — but `_handleLifecycle` is the semantically correct place: the null reset is about session lifecycle state, not instruction detection logic.

### Why This Only Affects the First Instruction of the Session

`_previousPhase` and `_previousExerciseIndex` are set at the end of every `_onState` call. After the first tick, they always reflect the last real state the state machine emitted. The BehaviorSubject replay only happens once — when the constructor subscribes — and only poisons the pre-session values. After the session starts and `_onState` runs for the first time with an active state, the values are correctly populated.

The null reset runs only when `!_started` — i.e., exactly once per `BreathModuleStateChannel` lifetime, at the start of the first session.

### What Exactly Was Fixed — The Full Chain

**Before fix (original broken behaviour):**
- T=0: `rest` → `phaseChanged = (rest != rest) = false` → dropped, stream never opened
- T=15s: `inhale` → `phaseChanged = true` → `emit()` called → `_streamSink == null` → **opens stream for the first time** → `inhale` is the first message on a new gRPC stream → server race condition (async JWT interceptor, Subject not yet subscribed) → **inhale lost**
- T=20s: `exhale` → stream already open, server already subscribed → **received and stored**
- Logs confirmed this: `sending inhale` → `opening stream for first sample: breath_phase` → server `recv: inhale` at T=15s with `total=2` (session_started was push #1, inhale push #2 — rest was never pushed)

**After null fix only (no probe/ACK):**
- T=0: `rest` → `phaseChanged = (rest != null) = true` ← fix applied → `emit()` called → **opens stream for the first time** → `rest` is the first message on a new gRPC stream → server race condition → **rest lost**
- T=15s: `inhale` → stream already open (opened 15s ago), server has long since subscribed → **received and stored**
- T=20s: `exhale` → **received and stored**
- DB result: inhale + exhale present, rest missing. Confirmed in session `318adc59`.

**After null fix + probe/ACK:**
- T=0: `rest` buffered → probe (`stream_ready`) sent as first message → server ACKs probe → `rest` flushed → **rest received and stored** (with duration=-15 due to separate `currentIntervalMs=-1` bug)
- T=15s: `inhale` → **stored**. T=20s: `exhale` → **stored**
- DB result: rest + inhale + exhale all present. Confirmed in session `a5aeffc0`.

**Key insight:** The null fix is valuable not because it "fixes rest" — rest still hits the race condition. It is valuable because it moves the stream-open call from T=15s to T=0, so that all subsequent instructions (inhale, exhale) arrive on a warmed-up stream where the race condition window has passed.

### Files Involved

| File | Change |
|------|--------|
| `lib/BreathModule/Core/BreathModuleStateChannel.dart` | Lines 68–69: `_previousPhase = null; _previousExerciseIndex = null;` added inside the `if (!_started)` branch of `_handleLifecycle` |

### How to Verify

Run a breath session. Check `session_stream_samples` in the DB. The row that contains `session_started` should also contain a `rest` instruction (or `rest` should appear in its own row immediately after). If `rest` is missing and `inhale` is the first instruction in the DB, the bug is not fixed.

## Open Questions

- `currentIntervalMs` is `-1` in the state emitted at session start transition (state machine resets it before the first tick). The formula `currentPhaseTotalDuration * currentIntervalMs = 15 * (-1) = -15` gives a wrong negative duration for `rest`. This is a separate bug not addressed by the null reset fix. The fix: `final intervalMs = state.currentIntervalMs > 0 ? state.currentIntervalMs : 1000;` in `_flushPending` and `_handleInstruction` send sites.
- The `rest` instruction reaching the server still depends on the gRPC bidirectional stream not having a race condition on first message delivery (separate bug: NestJS async JWT interceptor vs first DATA frame).
