# Code Review 3: Smoothed-RR metronome for breath ticks (heart gap tolerance)

**Plan:** `.ai-factory/plans/64-smoothed-rr-metronome-for-breath-ticks-heart-gap-tolerance.md`
**Spec:** `.ai-factory/notes/130-heart-tick-source-gap-tolerance.md`
**Files reviewed in full:** `lib/Biometrics/SmoothedRrSource.dart` (new), `lib/BreathModule/HeartRateTickService.dart` (rewritten), `lib/Core/App.dart`, `lib/BreathModule/BreathModule.dart`, `test/BreathModule/switchable_tick_service_test.dart`, `docs/breath/session/tick-sources.md`, `docs/biometrics/active-rr-source.md`, `.ai-factory/ROADMAP.md`. Cross-referenced `ActiveRrSource`, `SwitchableTickService`, `ClockTickService`, `RrInterval`, `NeiryBciProvider`, and — new this pass — the **consumer side**: `BreathSessionViewModel` and `BreathSessionStateMachine`.
**Risk Level:** 🟢 Low

Third independent pass. The code set is byte-identical to reviews 1 and 2 (confirmed: no implementer commit landed between rounds — `HeartRateTickService.dart` hash `e86a9ed…`, `SmoothedRrSource.dart` hash `1df1839…`). Rather than re-tread the same ground, this pass focused on **verifying the one design assumption the prior reviews took on trust** — that the breath state machine, not the tick service, gates pause — and on the consumer-side contract. Both check out. Overall verdict is unchanged: correct, faithful to the plan/spec, safe to ship, with one robustness fix recommended before merge.

## New verification this pass (consumer side)

- **"No pause logic in the tick service" is correct — verified at the consumer.** `BreathSessionStateMachine._onTick` (lines 235–240) early-returns when `_state.status == pause || complete`. So a free-running metronome that keeps emitting through a pause is harmless — the ticks are dropped downstream, exactly as the spec claims ("pause is gated by `BreathSessionStateMachine._onTick`"). This matches `ClockTickService`'s existing behavior, so the mirror is behaviorally faithful, not just structurally. ✓
- **Tick payload contract preserved.** The old service emitted `TickData(rr.intervalMs)` per beat; the new one emits `TickData(_currentPeriodMs)`. Both are `TickData(int)`, and `_onTick` consumes the carried interval (`intervalMs` flows into `_advanceExercise`/`_startRest`/`_startNewCycle`). Passing the smoothed period as the phase interval is exactly the intended cadence semantics. No consumer change needed. ✓
- **`sourceChanges` / disposal wiring intact.** `BreathSessionViewModel` subscribes to `tickService.sourceChanges` to mirror `tickSource` into state (line 124) and disposes `tickService` on close (line 87). `HeartRateTickService.sourceChanges` is `const Stream.empty()` (unchanged) — the single authoritative `sourceChanges` channel remains `SwitchableTickService`'s, so the grace-driven fallback correctly updates `tickSource`. ✓
- **Pause + sensor interaction is benign.** During pause, real beats still flow → `_onSmoothed` keeps `_currentPeriodMs` fresh and `_effectiveActive` true; the state machine drops the ticks; on resume the cadence is up-to-date. If a pause exceeds 10 s with no beats, grace flips to clock even while paused — correct, since the sensor is genuinely silent. ✓

## Findings (carried forward — code unchanged, so prior findings still stand)

### 1. (Low–Medium) Unclamped `_currentPeriodMs` can turn the self-rescheduling metronome into a permanent busy-loop

`_scheduleNext()` schedules `Timer(Duration(milliseconds: _currentPeriodMs), _onMetronomeFire)` and `_onMetronomeFire` always reschedules; the metronome is never stopped on grace. `_currentPeriodMs` is fed from `SmoothedRrSource`'s SMA over raw `RrInterval.intervalMs` (only `isArtifact` is filtered, no value bound). Tracing to origin: `NeiryBciProvider._onRrInterval` builds `RrInterval` straight from the SDK with no validation; `ActiveRrSource` forwards raw; `SmoothedRrSource` does not clamp. A non-artifact `intervalMs` of `0`/tiny therefore reaches `_currentPeriodMs`, producing a zero-delay timer that re-fires every event-loop turn for the rest of the session (flooding `_tickController`, racing the dot while heartbeat is active, burning CPU even after grace detaches the source). This is strictly worse than the pre-change one-tick-per-beat behavior. **Recommend** a physiological clamp, e.g. `_currentPeriodMs.clamp(250, 3000)` at schedule or assignment. Severity gated on whether the SDK actually emits `intervalMs == 0 && !isArtifact` (firmware-dependent, unverifiable here) → defense-in-depth, not a confirmed fault.

### 2. (Low) Artifact-only window seeds `_effectiveActive = true` with no real cadence

`_effectiveActive` seeds from `ActiveRrSource.hasActiveSource`, which counts an artifact-only stream as active; `SmoothedRrSource` filters artifacts, so `hasActiveSource == true` while `smoothedIntervalMs == null`. The feature then claims availability and ticks at the `?? 1000` ms placeholder until grace (10 s) or the first genuine beat. Per the plan's explicit "seed from `hasActiveSource`" decision and self-healing, so a behavioral note. Minor doc nuance: `tick-sources.md`'s cold-start "`hasActiveSource` остаётся `false`" line doesn't cover this sub-case. Optional: also gate on `smoothedIntervalMs != null`.

### 3. (Nit) `dispose()` comment references a non-existent `_smoothedRrSource` field

`HeartRateTickService.dispose()` comments "Does NOT dispose `_smoothedRrSource`," but no such field exists (the constructor only captures the stream/seed locally). Cosmetic; reword to "the App-owned `SmoothedRrSource`."

### 4. (Nit) `SmoothedRrSource` with `window <= 0` would throw; `start()` has no double-call guard

Both unreachable in current usage (`window` defaults to 7 and only `App` constructs it; `start()` is called exactly once and matches `ClockTickService.simulateTick()`'s no-guard shape). Defense-only.

### 5. (Nit) No automated coverage for the new metronome/grace/replay logic

Consistent with the plan's `Testing: no`. The injected `timerFactory` + scriptable `smoothedIntervalStream` make it deterministically testable later; the conditional warm/cold replay guard in particular would benefit from a regression test if coverage is ever added.

## Correctness re-confirmed (abbreviated — full traces in reviews 1 & 2)

Double-count fix (ticks only from the metronome), `ClockTickService` mirror (no prime tick / no pause sub / never stopped on grace), one-shot self-rescheduling timers, all four warm/cold × active/stale replay-guard states, no-stuck-`true` invariant, one-way fallback + gated manual re-enable, metronome deliberately ignoring `ActiveRrSource`'s 2 s watchdog, App DI/disposal/ownership, untouched protected files, Russian behavior-focused docs, ROADMAP Phase 45 `[x]` — all verified and correct. ✓

## Verdict

Correct and safe to ship; this pass additionally confirms the consumer-side pause gating that the design depends on. Apply Finding #1 (period clamp) as cheap defense-in-depth before merge; Findings #2–#5 are optional. No new blocking issues across three independent reviews.
