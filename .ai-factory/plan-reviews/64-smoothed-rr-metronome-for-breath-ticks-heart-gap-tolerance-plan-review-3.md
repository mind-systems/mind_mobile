# Plan Review 3 — Smoothed-RR metronome for breath ticks (heart gap tolerance)

**Plan:** `.ai-factory/plans/64-smoothed-rr-metronome-for-breath-ticks-heart-gap-tolerance.md`
**Spec:** `.ai-factory/notes/130-heart-tick-source-gap-tolerance.md`
**Risk Level:** 🟢 Low

## Verdict

This is the third iteration; the two earlier review rounds (recorded in the plan's "Review Resolutions") are correctly folded in. I re-derived every codebase claim against the actual source and found the plan accurate and implementable. No blocking issues.

## Verification performed (all confirmed against source)

- **File paths.** `lib/BreathModule/HeartRateTickService.dart`, `lib/Core/App.dart`, `lib/BreathModule/BreathModule.dart`, `test/BreathModule/switchable_tick_service_test.dart`, both docs files, and `.ai-factory/ROADMAP.md` all exist as referenced. `lib/Biometrics/SmoothedRrSource.dart` does not yet exist (correct — Task 1 creates it).
- **App.dart line anchors.** `final ActiveRrSource activeRrSource;` at line 98, `required this.activeRrSource,` in `App._` at line 129, `final activeRrSource = ActiveRrSource([bciProvider]);` at line 214, `activeRrSource: activeRrSource,` at line 243 — all match the plan's anchors exactly. The five mirrored edits for `smoothedRrSource` are correctly placed.
- **API usage.** `RrInterval` exposes `intervalMs` (int), `isArtifact` (bool), `source` (SensorSource) — Task 1's filter and SMA push are valid. `TickData(int)` is the constructor used by both `ClockTickService` and the current `HeartRateTickService` — `TickData(_currentPeriodMs)` is valid. `rxdart: ^0.28.0` is in `pubspec.yaml`, so unseeded `BehaviorSubject`, `hasValue`, and `value` are all available.
- **`ClockTickService` precedent.** `simulateTick()` is a public method that starts a `Timer.periodic` and is invoked from `buildSession` via `ClockTickService()..simulateTick()` (BreathModule.dart line 32). The plan's public `start()` + `..start()` symmetry mirrors this precisely; "no immediate/prime tick, no pause logic, never stopped except in dispose" matches the clock's actual code.
- **Test-compile claim.** `_FakeHeartRateTickService implements HeartRateTickService` (line 50) and already carries an `@override bool hasActiveSource` field plus `hasActiveSourceStream` getter. Adding a public `start()` to the concrete class forces exactly one new `@override void start() {}` on the fake — the same shape as `_FakeClockTickService`'s `@override void simulateTick() {}` (line 41). Task 4's single-line addition is necessary and sufficient; no test logic changes are required, and all assertions remain valid (the fake's `hasActiveSource` is a settable field, which satisfies the interface getter regardless of the real class re-pointing it at `_effectiveActive`).
- **No missed consumers.** The only references to `HeartRateTickService` are `BreathModule.buildSession` (Task 4 updates it), `SwitchableTickService` (type reference only, unchanged — correct per the "do not touch" guard), and the test fake (Task 4). Nothing else constructs or injects it.
- **ROADMAP Phase 45** exists (line 207) and already links `notes/130-heart-tick-source-gap-tolerance.md`. Task 6's "verify + mark `[x]`, do not duplicate" is right.
- **Docs language.** `docs/breath/session/tick-sources.md` and `docs/biometrics/active-rr-source.md` are both written in Russian. Task 5's instruction to write the updates in Russian correctly applies the global "match neighboring docs" rule.

## BehaviorSubject replay logic (the focus of reviews 1–2) — sound

The conditional-replay design in Task 3 is internally consistent:

- `smoothedIntervalMs` is specified to return `null` iff the subject lacks a value, so `_expectReplay = smoothedRrSource.smoothedIntervalMs != null` is exactly equivalent to "the subject `hasValue`," which is exactly the condition under which RxDart prepends a replayed value to a new subscription. The flag is captured synchronously at construction (no `await`), so it cannot drift before `.listen()` runs.
- Warm path drops one replay; cold path drops none — this correctly preserves "first real beat activates" while preventing a stale SMA from a disconnected sensor from falsely arming `_effectiveActive`/grace.
- Initial activation is governed solely by the constructor seed `smoothedRrSource.hasActiveSource` (raw `ActiveRrSource` availability), independent of the replayed value — so `trySwitchTo(heartbeat)` rejects on a cold source and accepts on a live one, matching today's behavior.
- `SmoothedRrSource` publishes once per accepted beat (not only on value change), so each genuine beat resets the 10 s grace — the grace mechanism depends on this and the plan states it explicitly.

## Context Gates

- **RULES.md — WARN (addressed):** Rule "App.dart is infrastructure only" is satisfied — `SmoothedRrSource` is a general derived biometric metric that mirrors `ActiveRrSource` (already an App-level biometric singleton), not breath-module state. The plan frames it this way explicitly. Rule "let the class manage its own subscription" is satisfied: `smoothedRrSource` is constructor-injected and `HeartRateTickService` owns its subscription internally; the external `..start()` call is a lifecycle kick that directly follows the accepted `ClockTickService()..simulateTick()` precedent in the same file, not new outside-wiring. No action needed.
- **ARCHITECTURE.md — OK:** No structural rule conflicts; the change extends the existing "Biometric streaming" / "Heart rate tick source" features without crossing a documented boundary.
- **ROADMAP.md — OK:** Phase 45 present and linked; correctly handled by Task 6.
- **Migrations — N/A:** No Drift schema or proto changes; nothing to migrate.

## Non-blocking observations (optional, do not gate implementation)

1. **All-artifact stream edge case.** If a sensor emits only `isArtifact == true` intervals, `SmoothedRrSource` stays silent (correct, by design), so `_effectiveActive` flips false after 10 s even though `ActiveRrSource.hasActiveSource` may remain true (its `_onInterval` restarts the watchdog for artifacts too). This is arguably the desired outcome — an all-artifact stream should not pace breathing — but the implementer may want a one-line awareness comment so it is not later mistaken for a bug.
2. **Unused pass-through.** `SmoothedRrSource.hasActiveSourceStream` is exposed but not consumed by `HeartRateTickService` (which uses its own `_effectiveActive`). Harmless and reasonable to keep for future consumers; just noting it is dead for the current caller.

## Positive Notes

- Every "do not touch" guard (`SwitchableTickService`, `ClockTickService`, `ActiveRrSource`, `ITickService`, `BreathViewModel`) is respected; the metronome/grace logic lives entirely above `hasActiveSourceStream`.
- The double-count root cause is correctly addressed by "beats never emit ticks," and the one-shot self-rescheduling timer (vs `Timer.periodic`) is the right primitive for a variable cadence — the plan calls this out explicitly.
- Timer-factory injection mirrors the existing `ActiveRrSource` testability pattern, keeping the rewrite unit-testable without real delays.
- Commit plan is clean and maps 1:1 to the task phases.

PLAN_REVIEW_PASS
