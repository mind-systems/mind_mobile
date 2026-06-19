# Plan Review: Stamp breath instructions on a monotonic offset axis (`{phase, tickCount, offsetMs}`, drop `durationMs`)

**Plan:** `.ai-factory/plans/56-stamp-breath-instructions-on-a-monotonic-offset-axis-payload-phase-tickcount-offsetms-drop-durationms.md`
**Files inspected:** `BreathModuleInstructionStream.dart`, `BreathModuleStateChannel.dart`, `InstructionSample.dart`, `BreathSessionStateMachine.dart`, `BreathSessionState.dart`, `test/BreathModule/breath_module_state_channel_test.dart`, notes 121/124, ROADMAP Phase 42, RULES.md, ARCHITECTURE.md
**Risk Level:** 🟡 Medium — design is correct, but one blocking omission (existing tests).

---

## Context Gates

- **Architecture (`ARCHITECTURE.md`):** ✅ PASS. The change stays inside the domain-adjacent `lib/BreathModule/Core/` channel + thin instruction mapper; no module/boundary crossing, no domain model leaking into the package. Consistent with the layered design.
- **Rules (`RULES.md`):** ✅ PASS. The three rules concern Module Services (stateless, no streams), `App.dart` purity, and constructor injection. `BreathModuleStateChannel` is not an `IXxxService`; it is already a stateful coordinator with subscriptions and a `dispose()`. Adding a `Stopwatch`/`DateTime?` field does not violate any rule. No `App.dart` change.
- **Roadmap (`ROADMAP.md`):** ✅ PASS. Directly implements Phase 42, the unchecked task at line 177 (verbatim title match). Spec note 121 exists and is consistent. Good milestone linkage.

---

## Critical Issues

### 1. The existing test suite will fail to compile — no task updates it (BLOCKER)

`test/BreathModule/breath_module_state_channel_test.dart` is an extensive (1237-line) suite for exactly this class. Its fake declares:

```dart
class _FakeInstructionStream implements BreathModuleInstructionStream {
  final List<(String, String, int)> sendSampleCalls = [];
  @override
  void sendSample(String sessionId, String phase, int durationMs, int timestampMs) =>
      sendSampleCalls.add((sessionId, phase, durationMs));
  ...
}
```

Task 1 changes the real signature to `sendSample(String sessionId, String phase, int tickCount, int offsetMs, int timestampMs)` (5 params). The fake's 4-param `@override` then becomes an **invalid override** → an analyzer/compile error. Because Dart compiles the whole test file as a unit, this breaks `flutter test` *and* `flutter analyze` for the entire suite — not just this file.

Beyond compilation, ~15 assertions in the "instruction dispatch", "pending flush", and "reset() clears instruction state" groups capture the 3rd positional argument as `durationMs` and assert concrete values derived from `currentIntervalMs` (e.g. `expect(... .first, ('sid', 'exhale', 5000))`, `(... , 'exhale', -1)`, `(... , 6000)`). After the change the 3rd arg is `tickCount` (= `currentPhaseTotalDuration`, which the test helper defaults to `1` and these tests never set), and `offsetMs`/`timestampMs` are new. Every one of those assertions becomes wrong.

The plan's `Settings → Testing: no` means "don't add new tests" — it does **not** excuse leaving the existing suite red. `/aif-verify` runs the suite; it will fail.

**Fix:** add an explicit task to update `_FakeInstructionStream.sendSample` to the new 5-arg signature (widen `sendSampleCalls` to capture `offsetMs`/`timestamp` as needed) and adjust the affected assertions. Since `offsetMs` derives from a real `Stopwatch`, the updated assertions must not pin an exact `offsetMs` (it will be a small non-deterministic value) — assert `phase`/`tickCount` and, if needed, `offsetMs >= 0` / `timestamp` monotonicity rather than equality. Decide whether to also inject the clock/stopwatch for determinism (consistent with the project's "Test Infra" pattern of injecting `clock`/`Timer` factories — ROADMAP lines 97-103), or accept relaxed assertions.

---

## Minor Issues / Observations

### 2. Stopwatch is not stopped on pause — `offsetMs` includes paused time (intentional, but confirm)
The plan stops/resets the stopwatch only in the start branch and in `reset()`; it is never stopped on `pause`. So `offsetMs` keeps advancing across a pause, and the gap between the last pre-pause phase offset and the first post-resume phase offset will include the full pause duration. This **matches the old behavior** (`ts = DateTime.now()` also advanced during pause), so it is not a regression, and it is consistent with note 124's plan to later emit explicit `phase='pause'` markers on the same continuous axis. No change required — flagging only so the implementer does not "helpfully" add a `_stopwatch.stop()` on pause, which would diverge from the continuous-axis contract that the follow-up tasks (123/124) depend on.

### 3. `tickCount` semantics confirmed correct
`state.currentPhaseTotalDuration` is the phase tick *count* (`BreathSessionStateMachine._computeEnrichedFields` sets it from `steps[i].duration` / `restDuration`, both tick counts), so renaming it to `tickCount` in the payload is accurate, and dropping the `* currentIntervalMs` product correctly removes the `-1`-poisoned value. ✅

### 4. Signature divergence from note 121 is acceptable
Note 121 and the ROADMAP sketch a 4-arg `sendSample(sessionId, phase, tickCount, offsetMs)` with the wire timestamp computed inside the stream. The plan instead keeps a 5th `timestampMs` param and computes `_wireTimestamp(offsetMs)` in the channel (which owns `_originWallClock`). This is a sound choice — it keeps `BreathModuleInstructionStream` a thin mapper (aligned with note 117 / Phase "collapse to thin mapper") and keeps origin-wall-clock ownership in one place. Just ensure the documentation/commit reflects the 5-arg decision since it differs from the note.

### 5. `_wireTimestamp` null-fallback is dead but harmless
`_handleInstruction` only runs when `_started`, which guarantees `_originWallClock != null`; the `?? DateTime.now()` fallback never executes. Harmless defensive code — fine to keep.

### 6. Line-number references are accurate
Start branch at lines 64-69, `_channel.start()` at line 66, `ts` at line 98, sends at lines 104/111 — all verified against the current file. `_handleLifecycle` (line 46) does run before `_handleInstruction` (line 47) in the same `_onState` pass, so the stopwatch is reset before the first `offsetMs` read (≈0 at origin). ✅

---

## Positive Notes

- Correct root-cause fix: the negative `durationMs` (`currentPhaseTotalDuration * -1` at origin) and the cross-clock axis are both eliminated by a single client-owned monotonic source.
- No proto / `mind_api` change needed — correctly leverages the free-form `Struct data` field; `InstructionSample.data` is `Map<String, dynamic>`, so adding `tickCount`/`offsetMs` is type-safe.
- Parking (`_pendingInstruction`) and the readiness gate are correctly left untouched; capturing `offsetMs` at phase time and stamping `_wireTimestamp(offsetMs)` keeps parked samples consistent with their origin offset (resolves note 121's open question correctly).
- Cross-repo `mind_web` impact is explicitly scoped out with a no-regression rationale.
- No other in-repo consumers of `data['durationMs']` or `sendSample` exist besides the channel and the test (verified by search), so blast radius is contained.

---

## Verdict

The design is correct and well-scoped, but **Issue #1 is blocking**: changing `sendSample`'s arity breaks compilation of the existing state-channel test suite, which fails the verify gate. Add a task to update the test fake's signature and the affected assertions before implementation.

(Not a pass — resolve Issue #1 and re-review.)
