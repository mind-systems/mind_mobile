# Plan: Stamp breath instructions on a monotonic offset axis; payload `{phase, tickCount, offsetMs}` (drop `durationMs`)

## Context
Replace the cross-clock `DateTime.now()` geometry axis and the negative-at-origin `durationMs` with a monotonic client-owned `offsetMs` axis; breath instruction samples carry `{phase, tickCount, offsetMs}` while the wire `int64 timestamp` is demoted to a reconstructed wall-clock stamp for sort/bookkeeping only.

## Settings
- Testing: no new test files — but the existing `breath_module_state_channel_test.dart` suite MUST stay green (the `sendSample` arity change breaks its fake and ~15 assertions; Task 4 fixes them). `/aif-verify` runs `flutter test`.
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Instruction payload contract

- [x] **Task 1: Rework `sendSample` to the offset-axis payload**
  Files: `lib/BreathModule/Core/BreathModuleInstructionStream.dart`
  Change the method signature from `sendSample(String sessionId, String phase, int durationMs, int timestampMs)` to `sendSample(String sessionId, String phase, int tickCount, int offsetMs, int timestampMs)`. Build `data = {'phase': phase, 'tickCount': tickCount, 'offsetMs': offsetMs}` (drop `durationMs`). Keep emitting `InstructionSample` with `sessionId`, `moduleId: 'breath'`, `instructionType: 'breath_phase'`, and `timestamp: timestampMs` (the reconstructed wall-clock passed in by the caller). No proto edit, no other field changes.

### Phase 2: Monotonic offset origin in the state channel

- [x] **Task 2: Add the stopwatch + wall-clock origin and reset it with the session** (depends on Task 1)
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  Add fields `final Stopwatch _stopwatch = Stopwatch();` and `DateTime? _originWallClock;`. In `_handleLifecycle`, inside the `if (!_started)` start branch (around line 64-69, the same place `_channel.start(...)` is called — this runs before `_handleInstruction` in the same `_onState` pass), do `_stopwatch..reset()..start();` and `_originWallClock = DateTime.now();`. In `reset()` add `_stopwatch..stop()..reset();` and `_originWallClock = null;`. Do NOT stop the stopwatch on `pause` — `offsetMs` must keep advancing across a pause (matches the old `DateTime.now()` behavior and the continuous-axis contract that follow-up notes 123/124 depend on). Do NOT touch the readiness gate or the `_pendingInstruction` parking logic.

- [x] **Task 3: Stamp instructions with `offsetMs` and reconstruct the wire timestamp** (depends on Task 2)
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  Change the `_pendingInstruction` record type from `({BreathSessionState state, int ts})?` to `({BreathSessionState state, int offsetMs})?`. In `_handleInstruction`, replace `final ts = DateTime.now().millisecondsSinceEpoch;` with `final offsetMs = _stopwatch.elapsedMilliseconds;`. When `sessionId == null`, park `(state: state, offsetMs: offsetMs)`. Otherwise call `_instructionStream.sendSample(sessionId, state.phase.name, state.currentPhaseTotalDuration, offsetMs, _wireTimestamp(offsetMs))` — dropping the `* state.currentIntervalMs` math; `tickCount` is `state.currentPhaseTotalDuration`. Update `_flushPending` the same way using `pending.offsetMs`. Add a small private helper `int _wireTimestamp(int offsetMs) => (_originWallClock?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch) + offsetMs;` so the wire `timestamp` is the reconstructed `originWallClock + offsetMs` (consistent for parked samples too), never a fresh `DateTime.now()` at send.

### Phase 3: Keep the existing test suite green

- [x] **Task 4: Update `_FakeInstructionStream` and the affected assertions** (depends on Task 1, Task 3)
  Files: `test/BreathModule/breath_module_state_channel_test.dart`
  The `sendSample` arity change makes the fake's 4-param `@override` an invalid override (breaks compilation of the whole file → `flutter test`/`flutter analyze` fail). Fix:
  1. Update `_FakeInstructionStream.sendSample` to the new 5-arg signature `(String sessionId, String phase, int tickCount, int offsetMs, int timestampMs)`. Keep the captured tuple shape as `(String, String, int)` = `(sessionId, phase, tickCount)` so the existing full-tuple assertions stay structurally valid; do NOT capture `offsetMs`/`timestampMs` into that tuple (both are derived from a real `Stopwatch`/wall-clock and are non-deterministic). If any assertion needs them, capture into separate lists and assert only `offsetMs >= 0` / `timestamp` monotonicity, never equality.
  2. The 3rd captured value is now `tickCount` (`currentPhaseTotalDuration`), no longer `currentPhaseTotalDuration * currentIntervalMs`. The `_state` helper defaults `currentPhaseTotalDuration: 1`, so every assertion that pinned the old interval-derived value must change to the expected tick count. To keep the assertions meaningful (not all `1`), set distinct `currentPhaseTotalDuration` values on the dispatched states in these tests and assert them. Affected assertions (current → new intent):
     - `('sid', 'exhale', 5000)` at line ~751 — assert `tickCount`.
     - `('sid', 'inhale', 5000)` at line ~771 — assert `tickCount`.
     - `('sid', 'exhale', 6000)` at line ~885 — assert `tickCount`.
     - `('sid', 'exhale', 5000)` at line ~950 — assert `tickCount`.
     - `[('sid', 'inhale', 6000)]` at line ~1016 — assert `tickCount`.
     - `('sid', 'exhale', 5000)` at line ~1047 — assert `tickCount`.
     - `('sid', 'exhale', 5000)` at line ~1145 — assert `tickCount`.
     - `('sid', 'inhale', 5000)` at line ~1183 — assert `tickCount`.
  3. The test "should pass currentIntervalMs through unchanged when it equals -1" (line ~891) is now obsolete — `currentIntervalMs` no longer feeds the payload. Repurpose it to assert the opposite invariant: with `currentIntervalMs: -1`, the dispatched 3rd arg is `tickCount` (e.g. `currentPhaseTotalDuration`), proving `currentIntervalMs` no longer poisons the value (no more `-1`). Rename it accordingly.
  4. Update test names/comments that reference `currentIntervalMs`/`durationMs` semantics to say `tickCount` where they describe the dispatched payload value (the lifecycle-only tests are unaffected).

## Notes
- Guards: NO proto edit, NO `mind_api` change. Geometry now lives in `data.offsetMs`. The readiness gate (note 114) and `_pendingInstruction` parking around the async `moduleSessionId` round-trip stay untouched — `offsetMs` is captured at phase time and survives parking exactly like the old `ts`.
- Signature divergence from note 121: note 121/ROADMAP sketch a 4-arg `sendSample(sessionId, phase, tickCount, offsetMs)` with the wire timestamp computed inside the stream. This plan deliberately keeps a 5th `timestampMs` param and computes `_wireTimestamp(offsetMs)` in the channel (which owns `_originWallClock`), keeping `BreathModuleInstructionStream` a thin mapper and origin-wall-clock ownership in one place. Reflect the 5-arg decision in the commit message.
- `_wireTimestamp` null-fallback (`?? DateTime.now()`) is dead under current control flow (`_handleInstruction` only runs when `_started`, which guarantees `_originWallClock != null`) — kept as harmless defensive code.
- Test determinism: this plan accepts relaxed assertions (`offsetMs >= 0`) rather than injecting a `Stopwatch`/clock into the constructor, to avoid widening the `BreathModuleStateChannel` constructor and touching every `_make()` call. The phase/tickCount assertions remain exact and deterministic.
- Cross-repo (out of scope, separate repo): `mind_web` must switch `transforms.ts` to read `data.offsetMs`. Until it ships, web keeps its old `timestamp`-based bars and loses the duration label — no regression versus today.
