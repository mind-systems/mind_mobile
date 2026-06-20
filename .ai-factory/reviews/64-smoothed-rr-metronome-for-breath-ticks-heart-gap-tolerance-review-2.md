# Code Review 2: Smoothed-RR metronome for breath ticks (heart gap tolerance)

**Plan:** `.ai-factory/plans/64-smoothed-rr-metronome-for-breath-ticks-heart-gap-tolerance.md`
**Spec:** `.ai-factory/notes/130-heart-tick-source-gap-tolerance.md`
**Files reviewed in full:** `lib/Biometrics/SmoothedRrSource.dart` (new), `lib/BreathModule/HeartRateTickService.dart` (rewritten), `lib/Core/App.dart`, `lib/BreathModule/BreathModule.dart`, `test/BreathModule/switchable_tick_service_test.dart`, `docs/breath/session/tick-sources.md`, `docs/biometrics/active-rr-source.md`, `.ai-factory/ROADMAP.md`. Cross-referenced `ActiveRrSource`, `SwitchableTickService`, `ClockTickService`, `RrInterval`, `NeiryBciProvider`.
**Risk Level:** 🟢 Low

This is an independent second pass. The code set is unchanged since review-1 (no implementer commit landed in between; the only added artifact is `review-1.md` itself). I re-derived the behavior from scratch rather than relying on review-1, and reached the same overall verdict: the implementation is correct, faithful to the plan and spec note 130, and safe to ship. One robustness finding is worth addressing before merge; the rest are notes.

## What I verified independently

- **Double-count fix is real.** Ticks originate only in `_onMetronomeFire`; `_onSmoothed` never touches `_tickController`. A late real beat updates the period, not the tick count. ✓
- **`ClockTickService` mirror.** `..start()` in `BreathModule.buildSession`, no prime tick (`start()` only schedules the first future fire), no lifecycle/pause subscription, metronome never stopped on grace (only `dispose()` cancels). ✓
- **Self-rescheduling one-shot timers.** `_timerFactory = Timer.new` (one-shot); `_onMetronomeFire` reschedules at the current `_currentPeriodMs`, so period changes take effect. Grace is one-shot, re-armed on each genuine beat. ✓
- **Warm/cold replay guard — traced all four states:**
  - *warm+active* → seed `true`, grace armed at construction, replay dropped, period seeded from SMA; subsequent genuine beats drive it. ✓
  - *warm+stale* (SMA retained but `hasActiveSource` false) → seed `false`, no grace armed, replay dropped, stays inactive until a real beat — no phantom activation. ✓
  - *cold+inactive* → `_droppedReplay` pre-set `true`, first emission treated as genuine, activates on first real beat. ✓
  - The `BehaviorSubject` seed-before-subsequent-adds ordering makes the single-drop assumption robust even if a genuine beat is added between `listen()` and microtask delivery. ✓
- **No stuck-`true`.** Every transition of `_effectiveActive` to true is paired with an armed grace timer (construction-if-active, or per genuine beat), so it always returns to false within 10 s of the last beat. ✓
- **One-way fallback + manual re-enable.** Grace→false routes through `SwitchableTickService._healthSub` (`!hasActive && active==heartbeat`); re-enable via `trySwitchTo(heartbeat)` is gated on `_heart.hasActiveSource` (now `_effectiveActive.value`). The seeded `_effectiveActive` delivered to `_healthSub` on subscribe cannot cause a spurious switch (default `_activeSource` is `timer`). ✓
- **Metronome ignores `ActiveRrSource`'s ~2 s silence watchdog** by design — it subscribes only to `smoothedIntervalStream`, not `hasActiveSourceStream`, so the 10 s grace governs the drop. This is the core feature behavior and is correctly realized. ✓
- **DI/disposal/ownership.** App wiring mirrors `activeRrSource` (field, `App._` param, `initialize()` ordering, pass-through). `HeartRateTickService.dispose()` cancels metronome + grace + smoothed sub and closes its own controllers; neither new component disposes the App-owned upstream. ✓
- **Untouched files** — `SwitchableTickService`, `ClockTickService`, `ActiveRrSource`, `ITickService`, `BreathViewModel` not modified; test gains only the `start()` no-op; docs are Russian and behavior-focused; ROADMAP Phase 45 marked `[x]` without a duplicate. ✓

## Findings

### 1. (Low–Medium) Unclamped `_currentPeriodMs` lets a degenerate RR value turn the self-rescheduling metronome into a permanent busy-loop — newly verified that nothing upstream validates the value

`_scheduleNext()` builds `Timer(Duration(milliseconds: _currentPeriodMs), _onMetronomeFire)` and `_onMetronomeFire` always reschedules. `_currentPeriodMs` comes from `SmoothedRrSource`'s SMA, which averages raw `RrInterval.intervalMs` after only the `isArtifact` filter. I traced the value to its origin: `NeiryBciProvider._onRrInterval` (line 328) constructs `RrInterval(intervalMs: rr.intervalMs, isArtifact: rr.isArtifact, …)` directly from the Neiry SDK with **no validation or clamping**, `ActiveRrSource` forwards it raw, and `SmoothedRrSource` does not bound it. So a non-artifact `intervalMs` of `0` (or a tiny/negative value) reaches `_currentPeriodMs` unmodified.

Consequences, which are strictly worse than the pre-change behavior:
- A `Timer` with a zero/near-zero duration re-fires on essentially every event-loop turn. Because the metronome reschedules itself and is **never stopped on grace**, this is a permanent busy-loop that floods `_tickController` for the rest of the session, even after grace flips `_effectiveActive` false and `SwitchableTickService` has detached — pure wasted CPU plus, while heartbeat is active, the breath dot races at microtask speed.
- The old implementation emitted a single `TickData(rr.intervalMs)` per beat; a bad value was a one-off glitch, not a self-perpetuating loop.

The SMA-over-7 smoothing dampens a single outlier but does not eliminate the case (a run of small values, or a `0` averaged into a still-small window early on).

**Recommendation:** clamp to a physiological floor/ceiling when scheduling, e.g. `Duration(milliseconds: _currentPeriodMs.clamp(250, 3000))` (≈ 20–240 bpm), or clamp at assignment in `_onSmoothed`/the constructor. One line, bounds the worst case regardless of upstream data quality. Severity is gated on whether the SDK ever emits `intervalMs == 0 && !isArtifact` (firmware-dependent, not verifiable from this repo), so treat as defense-in-depth rather than a confirmed runtime fault.

### 2. (Low) Artifact-only window seeds `_effectiveActive = true` with no real cadence

`_effectiveActive` is seeded from `smoothedRrSource.hasActiveSource`, a pass-through of `ActiveRrSource.hasActiveSource`, which treats a source emitting **only artifacts** as active (artifacts are forwarded, not filtered). `SmoothedRrSource` skips artifacts, so during an artifact-only window `hasActiveSource == true` while `smoothedIntervalMs == null`. Opening a session then seeds `_effectiveActive` true, arms grace, and runs the metronome at the `?? 1000` ms placeholder — so `trySwitchTo(heartbeat)` succeeds and the dot can be driven by a placeholder cadence reflecting no real beat. Self-heals within 10 s (grace, since no *genuine* beat resets it) or as soon as a real beat lands.

This matches the plan's explicit "seed from `hasActiveSource`" decision, so it's a behavioral note, not a defect. Minor doc inaccuracy: `tick-sources.md`'s "Холодный старт … `hasActiveSource` остаётся `false` … до первого удара" is true for a genuinely cold source but not for the artifact-only sub-case. If undesirable, additionally gate activation on `smoothedIntervalMs != null`.

### 3. (Nit) `dispose()` comment references a non-existent field

`HeartRateTickService.dispose()` says "Does NOT dispose `_smoothedRrSource` — owned by App," but the service does not keep a `_smoothedRrSource` field (it only captures the stream/seed values in the constructor). Harmless, but the comment names something that isn't there — consider rewording to "the App-owned `SmoothedRrSource`."

### 4. (Nit) `SmoothedRrSource` with `window <= 0` would throw

If ever constructed with `window: 0`, `_onInterval` adds one sample, trims it back to empty, then `reduce` on an empty list throws. Unreachable today (only `App` constructs it, with the default `7`), so defense-only. Not worth code churn unless the constructor becomes public API.

### 5. (Nit) No automated coverage for the new metronome/grace/replay logic

Consistent with the plan's `Testing: no`. The injected `timerFactory` plus a scriptable `smoothedIntervalStream` make the conditional replay guard and grace expiry deterministically testable if coverage is added later. Also `start()` has no double-call guard, but it's invoked exactly once and `ClockTickService.simulateTick()` shares the same shape — no action needed.

## Verdict

Correct, faithful to the (thrice-reviewed) plan, and safe to ship. Recommend applying Finding #1's period clamp as cheap defense-in-depth before merge; Findings #2–#5 are optional. This pass independently corroborates review-1 and surfaces no new blocking issues.
