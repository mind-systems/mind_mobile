# Plan Review: SmoothedRrSource and HeartRateTickService metronome tests

**Plan:** `100-smoothedrrsource-and-heartratetickservice-metronome-tests.md`
**Files Reviewed:** plan + 5 source/reference files
**Risk Level:** 🟢 Low

## Verification Against Codebase

I cross-checked every technical claim in the plan against the real implementations.

### SmoothedRrSource (`lib/Biometrics/SmoothedRrSource.dart`) — ✅ accurate
- Constructor `SmoothedRrSource(ActiveRrSource source, {int window = 3})` matches the plan's `window: 1` override usage (Task 2 last case).
- `smoothedIntervalMs` getter returns `null` until the first non-artifact interval (`_subject.hasValue ? value : null`) — Task 1 assertions are correct.
- `smoothedIntervalStream` is an **unseeded** `BehaviorSubject<int>`, so it replays only after a value lands — Task 1 "no replay before first interval" and Task 2 "replay last SMA to late subscriber" are both correct.
- SMA math verified against `_onInterval` (rounded mean, drop-oldest at `_window`):
  - 500 → 500; 500,600 → 550; 500,600,700 → 600; +800 → 700 ✅
  - artifact case: 500, artifact(9999), 600, 700 → window `[500,600,700]` → 600 ✅ (artifact short-circuits before `_samples.add`)
  - stream sequence 500,600,700 → `[500,550,600]` ✅
- Availability is pure pass-through to `_source` (Task 4) ✅.
- `dispose()` cancels the sub, closes `_subject`, does **not** dispose `_source` (Task 5) ✅.

### HeartRateTickService (`lib/BreathModule/HeartRateTickService.dart`) — ✅ accurate
- `timerFactory` and `graceWindow` are injectable constructor params — the spy-factory harness from `active_rr_source_test.dart` applies directly.
- Warm/cold construction path verified: `expectReplay = smoothedIntervalMs != null` → `_droppedReplay = !expectReplay`. Cold pre-marks dropped (first emission genuine); warm drops one replay (Tasks 6, 8) ✅.
- Grace armed at construction only when `hasActiveSource` is true (warm path) — Task 6 grace assertions correct ✅.
- Metronome seed `_currentPeriodMs = smoothedIntervalMs ?? 1000`, scheduled on `start()`, no prime tick — Tasks 6, 7 correct ✅.
- Clamp range 250–3000 ms applied both at scheduling (`_scheduleNext`) and at tick emission (`_onMetronomeFire`) — Task 7 clamp tests (100→250, 5000→3000, both for Duration *and* tick `intervalMs`) correct ✅.
- Genuine beats update period + re-arm grace but emit no tick; `_armGrace` cancels the prior grace timer — Task 8 correct ✅.
- `_onGraceExpired` flips `_effectiveActive` false without stopping the metronome (coasts) — Task 9 correct ✅.
- ITickService surface (`heartbeat`, `1000`, empty `sourceChanges`, `trySwitchTo == false`) — Task 10 correct ✅.
- `dispose()` cancels both timers + sub, closes `tickStream` and `_effectiveActive`, leaves SmoothedRrSource alone — Task 11 correct ✅.

### Reference patterns & fakes — ✅ accurate
- `_FakeTimer implements Timer` + `spyFactory` capturing `(delay, cb)` exists verbatim in `active_rr_source_test.dart` and is reusable.
- The implicit-interface fake pattern (`implements ConcreteClass`) is established in `switchable_tick_service_test.dart` — `_FakeSmoothedRrSource implements SmoothedRrSource` / `_FakeActiveRrSource implements ActiveRrSource` will type-check.
- The shared-`timerFactory` gotcha (grace vs metronome disambiguated by `Duration`) is correct and important — confirmed both timers route through the same factory.

### Logistics — ✅
- Target dirs `test/Biometrics/` and `test/BreathModule/` exist; neither target file exists yet (no overwrite/conflict).
- Test command path `/usr/local/bin/flutter` matches project convention.
- `_rr` helper import `package:mind/Biometrics/Models/SensorSource.dart` is correct; `RrInterval` ctor signature (`intervalMs`/`timestamp`/`isArtifact`/`source`, all required) matches.
- No migrations involved (test-only plan) — N/A is correct.

## Context Gates
- **Architecture** (`ARCHITECTURE.md` present): WARN — none. Test-only change, no boundary impact.
- **Rules** (`RULES.md` present): WARN — none. Rules govern module Services/App.dart wiring; not applicable to test files.
- **Roadmap**: WARN — `ROADMAP_TESTS.md` exists; consider confirming this test work is linked there, but not blocking.
- **skill-context** (`.ai-factory/skill-context/aif-review/SKILL.md`): absent — no project overrides to apply.

## Observations (non-blocking)
These would not break implementation; they're refinements an implementing agent should keep in mind:

1. **`_currentPeriodMs` is private.** Several task assertions phrase expectations as "`intervalMs == _currentPeriodMs`" or "period becomes 600" (Tasks 7, 8). There is no public getter — period is only observable indirectly via (a) the fired tick's `intervalMs`, or (b) the next captured metronome `Duration`. The plan's gotcha note ("assert on captured `Duration` values") covers this; just confirm warm-path Task 8 verifies the period change through `start()` + a metronome fire rather than expecting a direct read.

2. **BehaviorSubject replay needs a microtask flush.** For the warm-path replay-drop test (Task 8), the `_FakeSmoothedRrSource` must seed its `smoothedIntervalStream` BehaviorSubject **and** set `smoothedIntervalMs` non-null; the seeded replay is delivered asynchronously, so the test must `await Future<void>.delayed(Duration.zero)` before emitting the genuine value. The reference tests already use this idiom throughout.

3. **`hasActiveSourceStream` assertions need `.skip(1)`.** `_effectiveActive` is a seeded BehaviorSubject (warm=true), so Task 9's "emits false" and Task 4's transition checks should skip the replayed seed value — same pattern as `active_rr_source_test.dart`.

4. **Interface completeness for fakes.** `_FakeActiveRrSource implements ActiveRrSource` must also provide a no-op `dispose()` (returns `Future<void>`) to satisfy the interface, and `_FakeSmoothedRrSource` must expose `hasActiveSourceStream` even though `HeartRateTickService` never reads it. The plan already lists `hasActiveSourceStream` for the fake; just don't forget `dispose`.

## Positive Notes
- The plan correctly identifies the precise coverage gap (real metronome/grace/replay-drop logic vs. the hand-written fake exercised by `switchable_tick_service_test.dart`).
- SMA arithmetic in the task descriptions is worked out correctly, including the rounded-mean nuance (`500,600 → 550`).
- The warm/cold replay-drop semantics — the trickiest part of `HeartRateTickService` — are understood and have dedicated cases.
- Reuse of the existing `spyFactory`/`_FakeTimer` harness keeps the new tests consistent with the established style.

PLAN_REVIEW_PASS
