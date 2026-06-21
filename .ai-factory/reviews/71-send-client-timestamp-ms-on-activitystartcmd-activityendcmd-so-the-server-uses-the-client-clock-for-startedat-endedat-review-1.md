# Code Review: Send `client_timestamp_ms` on `ActivityStartCmd`/`ActivityEndCmd`

## Scope reviewed
- `proto/module_state.proto` (copied from mind_api)
- `lib/Core/Grpc/generated/module_state.pb.dart`, `module_state.pbjson.dart` (regenerated)
- `lib/Core/Grpc/ModuleStateChannel.dart`
- `lib/BreathModule/Core/BreathModuleStateChannel.dart`
- `lib/MeditationModule/Core/MeditationModuleStateChannel.dart`

## Verification performed
- **Proto fidelity:** `diff mind_api/proto/module_state.proto mind_mobile/proto/module_state.proto` → identical. No hand-authoring/symlink; copied verbatim per the proto-ownership rule. Field numbers (`= 4` on Start, `= 1` on End) and `optional` markers match the source of truth.
- **Generated constructor semantics:** `ActivityStartCmd`/`ActivityEndCmd` factories use `if (clientTimestampMs != null) result.clientTimestampMs = clientTimestampMs;` — so passing `null` from the channel correctly leaves the field unset (presence-tracked via `hasClientTimestampMs()`). The `clientTimestampMs != null ? Int64(...) : null` ternary in `ModuleStateChannel` therefore maps correctly to "omit field" on the wire, preserving backward-compat (absent → server `now()`).
- **Call-site coverage:** the only callers of `start`/`end` are the breath and meditation channels; both updated. The new params are optional named args, so no other call site breaks.
- **`Int64` encoding:** matches the established pattern (`ModuleInstructionStream.dart:186`); `fixnum` import added. Epoch millis (~1.7e12) is well within Int64 range.

## Correctness analysis

**Breath start** — `clientTimestampMs: _originWallClock!.millisecondsSinceEpoch`, with `_originWallClock = DateTime.now()` set on the line directly above. The `!` assertion is safe. ✓

**Breath end** — `clientTimestampMs: _wireTimestamp(_stopwatch.elapsedMilliseconds)` = `_originWallClock + elapsedMs`. This is the same origin/clock as the phase `offsetMs` markers, satisfying the "single end-instant source" requirement. The stopwatch is started at session start and only stopped in `reset()` (never paused), so `origin + elapsed ≈ real wall-clock now` at completion. `endedAt >= startedAt` holds (elapsed ≥ 0). `millisecondsSinceEpoch` is UTC-epoch and timezone-independent, matching the server's expectation. ✓

**Meditation start/end** — both use `DateTime.now().millisecondsSinceEpoch` (same clock), yielding a correct `durationMs`. Lifecycle-only, no offset axis needed. Re-arm logic untouched. ✓

**Untouched as required** — `pause`/`unpause`/`stop` and pause/resume markers (`_emitMarker`) are unchanged.

## Observations (non-blocking)

1. **Diagnostic log changes vs. plan wording.** Plan Task 3 / note 137 said to "leave the existing diagnostic logs exactly as they are," assuming `session complete at offset=…` and `phase=… offset=…` already existed at HEAD. They did not — HEAD had `session end` and no phase log. The implementation modifies the end log to `session complete at offset=Xms — sending end` and adds the `phase=… ex=… offset=…` line in `_handleInstruction`. This is **correct and beneficial**, not a defect:
   - The old `session end` message and the (rejected) `… (server stamps endedAt on receipt)` wording would now be *misleading*, since the server no longer stamps `endedAt` on receipt — it uses the client timestamp.
   - The new logs are exactly what note 137's Verification section calls for (comparing client `offset=X` to server `durationMs`).
   No action required; flagging only as a deviation from the literal plan text.

## Conclusion
No correctness, security, or runtime defects found. Proto sync is verbatim, generated code handles optional-field presence correctly, timestamps are monotonic and on a single clock, backward-compat is preserved, and all call sites compile. The one deviation (log wording) is an improvement consistent with the milestone's verification intent.

REVIEW_PASS
