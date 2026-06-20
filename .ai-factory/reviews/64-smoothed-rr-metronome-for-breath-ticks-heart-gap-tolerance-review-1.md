# Code Review: Smoothed-RR metronome for breath ticks (heart gap tolerance)

**Plan:** `.ai-factory/plans/64-smoothed-rr-metronome-for-breath-ticks-heart-gap-tolerance.md`
**Spec:** `.ai-factory/notes/130-heart-tick-source-gap-tolerance.md`
**Files reviewed (in full):** `lib/Biometrics/SmoothedRrSource.dart` (new), `lib/BreathModule/HeartRateTickService.dart` (rewritten), `lib/Core/App.dart`, `lib/BreathModule/BreathModule.dart`, `test/BreathModule/switchable_tick_service_test.dart`, `docs/breath/session/tick-sources.md`, `docs/biometrics/active-rr-source.md`, `.ai-factory/ROADMAP.md`. Cross-referenced `ActiveRrSource`, `SwitchableTickService`, `ClockTickService`, `RrInterval`.
**Risk Level:** 🟢 Low

The implementation is faithful to the thrice-reviewed plan and to spec note 130. All the load-bearing decisions are correctly realized:

- **Real beats never emit ticks** — `_onSmoothed` only updates `_currentPeriodMs`, flips `_effectiveActive`, and re-arms grace; ticks come solely from `_onMetronomeFire`. The double-count hazard is genuinely eliminated. ✓
- **Mirror `ClockTickService`** — metronome started via `..start()` in `BreathModule.buildSession`, no prime tick, no pause/lifecycle subscription, never stopped on grace (only `dispose()` cancels). ✓
- **One-shot self-rescheduling timers** — both metronome and grace use `Timer.new` (one-shot); `_onMetronomeFire` reschedules at the *current* period, so cadence updates take effect (Issue #3 from review-1 correctly resolved). ✓
- **Conditional warm/cold replay guard** — `expectReplay = smoothedIntervalMs != null` → `_droppedReplay = !expectReplay`. Warm path drops the one stale `BehaviorSubject` replay; cold path treats the first emission as genuine (review-2 Issue A correctly resolved). I traced all four states (warm+active, warm+stale, cold+inactive, cold) — each behaves as designed; no phantom activation on a stale SMA. ✓
- **No stuck-`true`** — whenever `_effectiveActive` becomes true, a grace timer is pending (armed at construction when seeded active, re-armed on every genuine beat), so it always flips false within 10 s of the last beat. ✓
- **Disposal/ownership** — `HeartRateTickService.dispose()` cancels metronome + grace + smoothed sub and closes its own controllers; neither it nor `SmoothedRrSource` disposes the App-owned upstream. App wiring mirrors `activeRrSource` exactly (field/constructor/initialize/`App._`). ✓
- **Test** — single `@override void start() {}` no-op added to `_FakeHeartRateTickService`, mirroring the existing `simulateTick` precedent; fake satisfies the full concrete interface; no test-logic change. ✓
- **Docs** — written in Russian to match neighboring files; describe behavior, not code. ROADMAP Phase 45 marked `[x]` (no duplicate entry). ✓

The findings below are robustness/edge-case notes — none is a build-breaker or a contract violation.

---

## Findings

### 1. (Low–Medium) Unclamped `_currentPeriodMs` — a near-zero non-artifact interval makes the self-rescheduling metronome busy-loop for the rest of the session

`HeartRateTickService._scheduleNext()` schedules `Timer(Duration(milliseconds: _currentPeriodMs), _onMetronomeFire)`, and `_onMetronomeFire` unconditionally reschedules. `_currentPeriodMs` is fed from `SmoothedRrSource`'s SMA, which averages raw `RrInterval.intervalMs` values with **no lower bound** (`SmoothedRrSource._onInterval` only filters `isArtifact`, then averages). `RrInterval` itself carries no validation, and `ActiveRrSource` forwards intervals raw.

If a non-artifact interval of `0` (or a few ms) reaches the average — e.g. a malformed sample the BCI provider does not flag as an artifact — `_currentPeriodMs` can become `0`/near-zero. A `Timer` with a zero/tiny duration re-fires on essentially every event-loop turn, and because the metronome **reschedules itself and is never stopped on grace**, this becomes a permanent busy-loop that floods `_tickController` for the remainder of the session (until `dispose()`), burning CPU even after grace has flipped `_effectiveActive` false and `SwitchableTickService` has stopped listening.

This is strictly worse than the old behavior, where a bad interval produced a *single* `TickData(rr.intervalMs)` per beat rather than a self-perpetuating loop. The SMA-over-7 smoothing mitigates a single outlier but does not eliminate the case (a run of small intervals, or a 0 averaged with a small window early on).

**Suggested fix:** clamp the period to a sane physiological floor when scheduling, e.g. `Duration(milliseconds: _currentPeriodMs.clamp(250, 3000))` (or clamp at the point `_currentPeriodMs` is assigned). Cheap, and bounds the worst case regardless of upstream data quality. Confidence that `intervalMs == 0` actually occurs depends on `NeiryBciProvider`'s artifact tagging (not verified here), so treat this as defense-in-depth rather than a confirmed live crash.

### 2. (Low) Artifact-only window seeds `_effectiveActive = true` with no smoothed value, ticking at the 1000 ms placeholder until grace

`_effectiveActive` is seeded from `smoothedRrSource.hasActiveSource`, which passes through `ActiveRrSource.hasActiveSource`. `ActiveRrSource` counts a source as active even when it has only emitted **artifacts** (it forwards artifacts and does not filter them). `SmoothedRrSource`, however, skips artifacts, so in an artifact-only window `hasActiveSource == true` while `smoothedIntervalMs == null`.

Result at session open in that window: `_effectiveActive` seeds **true**, grace is armed, and the metronome ticks at the `?? 1000` ms placeholder (~60 bpm) — so `trySwitchTo(heartbeat)` succeeds and the dot can be driven by a placeholder cadence that reflects no real beat. It self-heals: within 10 s grace flips false (no *genuine* beat resets it) → fallback to clock; or a genuine beat replaces the placeholder period.

This is consistent with the plan's explicit "seed from `hasActiveSource`" decision and is short-lived, so I'm flagging it as a behavioral note rather than a defect. If undesirable, seed/gate activation additionally on `smoothedIntervalMs != null`. (Note: the doc claims "Холодный старт … `hasActiveSource` остаётся `false` … до первого удара" — that holds for a truly cold source but not for the artifact-only sub-case, where `hasActiveSource` is already true.)

### 3. (Nit) No automated coverage for the new metronome/grace/replay logic

Per the plan `Testing: no`, so this is acceptable and not requested. Worth recording that the conditional replay guard and grace expiry — the subtlest parts of the change — are unverified by tests. The injected `timerFactory` already makes them deterministically testable (fake timer + scripted `smoothedIntervalStream`) if coverage is added later.

### 4. (Nit) `start()` has no double-call guard

Calling `start()` twice would create a second self-rescheduling metronome chain and leak the first timer. It is called exactly once (`..start()` in `BreathModule.buildSession`), and `ClockTickService.simulateTick()` has the same no-guard shape, so this matches existing precedent. No action needed.

---

## Correctness checks that passed

- App DI wiring (`smoothedRrSource` field, `App._` param, `initialize()` construction after `activeRrSource`, pass-through to `App._`) is internally consistent — no missing/duplicated wiring. ✓
- `SmoothedRrSource._onInterval` never calls `reduce` on an empty list (sample is added first); `smoothedIntervalMs` guards on `hasValue`. ✓
- `BehaviorSubject` replay ordering (seed delivered before subsequent adds) makes the single-replay-drop assumption safe even if a genuine beat is added between `listen()` and microtask delivery. ✓
- Grace flipping `_effectiveActive` false routes through `SwitchableTickService._healthSub` (`!hasActive && active == heartbeat`) → one-way fallback; re-enable is manual and gated on `_heart.hasActiveSource` (now `_effectiveActive.value`). ✓
- Metronome deliberately does **not** subscribe to `hasActiveSourceStream`, so `ActiveRrSource`'s ~2 s silence watchdog no longer prematurely drops the heart source — the 10 s grace governs instead. This is the core fix and is correctly realized. ✓
- `SwitchableTickService`, `ClockTickService`, `ActiveRrSource`, `ITickService`, `BreathViewModel` untouched. ✓

---

**Verdict:** The change is correct, faithful to the plan, and safe to ship. Recommend addressing Finding #1 (period clamp) as cheap defense-in-depth before merge; Findings #2–#4 are optional. No blocking issues.
