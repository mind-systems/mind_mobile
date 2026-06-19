# Plan: Fix — breath phase instruction timestamped at send time, not at phase start

## Context
Breath phase instruction samples are stamped with `DateTime.now()` inside `sendSample`, so the buffered first (`rest`) phase lands ~1.2–1.5 s late after the `activity:start` round-trip. Capture the transition time when the phase change is detected and thread it through the direct and pending/flush paths so the sample carries true event time.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Event-time timestamp

- [x] **Task 1: Add `timestampMs` parameter to `sendSample`**
  Files: `lib/BreathModule/Core/BreathModuleInstructionStream.dart`
  Change the signature to `void sendSample(String sessionId, String phase, int durationMs, int timestampMs)`. In the payload map, set `'timestamp': timestampMs` and remove the internal `DateTime.now().millisecondsSinceEpoch` stamp (current line 26). Do not touch `_canSendNow()`, `_emit()`, the buffer path, or `durationMs` — `_lastSendTime`/`_canSendNow` keep using `DateTime.now()` (that is send-rate limiting, not the sample timestamp).

- [x] **Task 2: Capture transition time at phase-change detection and thread it through the pending/flush path** (depends on Task 1)
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  In `_handleInstruction`, after `phaseChanged` is confirmed (after the `if (!phaseChanged) return;` guard), capture `final ts = DateTime.now().millisecondsSinceEpoch` — the true transition time.
  - Direct path: pass `ts` as the new fourth argument to `sendSample`.
  - Pending path: change the `_pendingInstruction` field type from `BreathSessionState?` to a record carrying both state and timestamp (e.g. `(BreathSessionState state, int ts)?`), and store `_pendingInstruction = (state, ts)` instead of `_pendingInstruction = state`.
  - `_flushPending`: read `pending.state` for `phase`/`durationMs` and reuse `pending.ts` as the `timestampMs` argument rather than re-reading the clock.
  - `reset()`: keep clearing `_pendingInstruction = null` (no type change needed there).
  Do not alter the lifecycle logic, the `_canSendNow`/buffer behaviour, the readiness/eager-open flow, or the `currentPhaseTotalDuration * currentIntervalMs` duration computation.

- [x] **Task 3: Update the test fake signature so the suite keeps compiling** (depends on Task 1)
  Files: `test/BreathModule/breath_module_state_channel_test.dart`
  `_FakeInstructionStream.sendSample` (line 55) must match the new signature: add the `int timestampMs` parameter to the override. Keep recording the existing 3-tuple `(sessionId, phase, durationMs)` in `sendSampleCalls` so all existing `expect(...)` assertions on `('sid', 'phase', durationMs)` continue to pass unchanged. Do not add new test cases — this is signature maintenance only.

## Verification
- App compiles and existing tests pass (`flutter test`).
- Manual check per spec: the first `rest` row in `session_stream_samples` has a timestamp matching the Play moment (within sub-100 ms of session start), not delayed by the `activity:start` round-trip.
