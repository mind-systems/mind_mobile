# Code Review: Fix — breath phase instruction timestamped at send time, not at phase start

**Scope reviewed:** `git diff HEAD` — changes to
`lib/BreathModule/Core/BreathModuleInstructionStream.dart`,
`lib/BreathModule/Core/BreathModuleStateChannel.dart`, and
`test/BreathModule/breath_module_state_channel_test.dart`.
(Plan/JSON/plan-review files in the diff are artifacts, not code — not reviewed.)

## Summary

The change is correct, minimal, and matches the plan and spec note 104 exactly. It
captures the wall-clock transition time once in `_handleInstruction` (after the
`phaseChanged` guard) and threads it through both the direct and pending/flush paths
via a new `int timestampMs` parameter on `sendSample`, replacing the internal
`DateTime.now()` stamp. No findings.

## Verification

- **`sendSample` signature + payload** (`BreathModuleInstructionStream.dart`):
  `'timestamp'` now reads the passed `timestampMs` (`int`). Both consumers of the
  payload — `_emit` (`payload['timestamp'] as int`) and `flushBuffer`
  (`sample['timestamp'] as int`) — read it back as `int`, so the type is consistent
  end to end. The rate-limit buffer path therefore also preserves event-time, not
  just the direct emit.

- **Rate limiting untouched:** `_canSendNow()` / `_lastSendTime` still use
  `DateTime.now()` for send pacing, independent of the sample timestamp — correct,
  this is send-rate logic, not the sample clock. Scope guard respected.

- **Record type for `_pendingInstruction`** (`BreathModuleStateChannel.dart`):
  changed to `({BreathSessionState state, int ts})?`. All references updated
  consistently — store (line 101), flush (lines 108–111), `reset()` null-clear
  (line 121). The `_flushPending` duration expression correctly uses the `.state`
  indirection (`pending.state.currentPhaseTotalDuration * pending.state.currentIntervalMs`),
  which was the single easy-to-miss mechanical detail. Assigning `null` to a nullable
  record is valid Dart.

- **`ts` capture point:** placed after `if (!phaseChanged) return;`, so it is read
  only on a confirmed transition and is reused for both the immediate-send and
  buffered cases. Subsequent (non-buffered) phases now read the clock a few
  microseconds earlier than before (in `_handleInstruction` rather than inside
  `sendSample`) — functionally identical, no regression, and now uniform across both
  paths so future buffering cannot reintroduce the skew.

- **Test fake** (`_FakeInstructionStream.sendSample`): override signature updated to
  match; still records the 3-tuple `(sessionId, phase, durationMs)`, so all existing
  `expect(...)` assertions compile and pass unchanged. No new test cases — consistent
  with `Testing: no`.

## Runtime / breakage check

- No type mismatches: `int` flows from capture → param → payload → `InstructionSample`.
- No migrations, schema, or proto changes involved.
- No race condition introduced: `ts` is a local captured synchronously at detection;
  the pending record holds it until `_flushPending` runs on the `activity:start`
  round-trip, which is the intended deferral.
- No other call sites of `sendSample` exist outside the two updated paths and the
  test fake (confirmed by grep).

## Observation (non-blocking)

- No automated test locks in the fix behavior (that the buffered `ts` is reused
  rather than re-read at flush). This is consistent with the plan's `Testing: no`
  setting and the manual `session_stream_samples` verification step. If desired
  later, recording the 4-tuple in the fake and asserting the flush path reuses the
  buffered timestamp would guard the regression cheaply. Not required for this change.

REVIEW_PASS
