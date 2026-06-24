# Plan: Make `BreathModuleStateChannel` offset axis testable: inject Stopwatch factory + Clock

## Context
Make the offset/timestamp axis of `BreathModuleStateChannel` deterministically testable by injecting a `Stopwatch` factory and a `clock` function (replacing the internally-constructed `Stopwatch()` and hardcoded `DateTime.now()`), and extend the test fake to capture the full `sendSample` 5-tuple so future offset assertions are possible.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Scope notes
- This milestone is **enablement only**: the production refactor + the fake extension. It does NOT add the Gap 1–6 offset test cases described in `.ai-factory/notes/182-test-plan-breath-channel-offset-gaps.md` — those belong to a follow-up test-implementation milestone.
- The real constructor uses **named** parameters, so the new `stopwatchFactory` / `clock` params are added as optional named parameters with defaults (the test plan note showed positional params, which is stale — follow the actual code).
- `BreathModuleInstructionStream.sendSample` already takes 5 args `(sessionId, phase, tickCount, offsetMs, timestampMs)`; no interface change is required.

## Tasks

### Phase 1: Production refactor

- [x] **Task 1: Inject `stopwatchFactory` and `clock` into `BreathModuleStateChannel`**
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  - Add two optional named constructor parameters with defaults:
    `Stopwatch Function() stopwatchFactory = Stopwatch.new` and `DateTime Function() clock = DateTime.now`.
  - Replace the inline field `final Stopwatch _stopwatch = Stopwatch();` (line 24) with a `final Stopwatch _stopwatch;` initialized once in the constructor initializer list from `stopwatchFactory()`. The single instance is reused across `reset()`/`start()` (which call `_stopwatch..reset()..start()` / `..stop()..reset()`), matching current behavior.
  - Store the clock as a field `final DateTime Function() _clock;` (assigned in the initializer list from `clock`).
  - Replace `_originWallClock = DateTime.now();` (line 85) with `_originWallClock = _clock();`.
  - Replace the `DateTime.now()` fallback inside `_wireTimestamp` (line 140) with `_clock()` so timestamp computation is fully clock-driven and testable.
  - Keep all existing behavior, log lines, and the named-parameter constructor shape intact; the new params are additive and default-compatible, so no call sites break.

### Phase 2: Test fake extension

- [x] **Task 2: Extend `_FakeInstructionStream` to capture the full 5-tuple and keep existing assertions green** (depends on Task 1)
  Files: `test/BreathModule/breath_module_state_channel_test.dart`
  - Change `sendSampleCalls` from `List<(String, String, int)>` to `List<(String, String, int, int, int)>` and update `sendSample` to record the full `(sessionId, phase, tickCount, offsetMs, timestampMs)` tuple (currently it discards `offsetMs`/`timestampMs` at lines 56–61).
  - Add a projection getter on the fake to preserve the existing `(sessionId, phase, tickCount)` assertions without coupling them to nondeterministic offset/timestamp values produced by the default real `Stopwatch`/clock:
    ```dart
    List<(String, String, int)> get phaseTickCalls =>
        sendSampleCalls.map((c) => (c.$1, c.$2, c.$3)).toList();
    ```
  - Update existing assertions that compare against 3-tuple literals (e.g. lines 756, 776, 839–840, 893, 915, 958, 1024, 1055, 1153, 1191) to read from `phaseTickCalls` instead of `sendSampleCalls`. Single-field accesses via `.$1` (e.g. lines 1091, 1217) and length/empty checks (`hasLength`, `isEmpty`) work unchanged on the new 5-tuple list and need no edit — switch only the tuple-equality sites.
  - Do NOT add new offset/monotonicity test cases in this milestone (those are the follow-up). The goal here is: fake captures offsets, and the existing suite stays fully green.
  - Run `/usr/local/bin/flutter test test/BreathModule/breath_module_state_channel_test.dart` and confirm all existing tests pass.

## Notes for the implementer
- After Task 1, a follow-up milestone can inject a controllable `FakeStopwatch` (settable `elapsedMilliseconds`) and a fixed `FakeClock` via `_make(...)` to assert exact `offsetMs`/`timestampMs` values (pause marker `offsetMs > 0`, resume re-emit ordering, wire-timestamp = origin + offset). This plan only lays the seams.
- Single commit at the end: "Inject Stopwatch factory and clock into BreathModuleStateChannel and capture offsets in test fake".
