# Heart tick source — smoothed-cadence metronome + reusable SmoothedRrSource layer

**Date:** 2026-06-20
**Source:** conversation context

## Key Findings

- Today the breath state machine ticks **one phase-step per real RR beat** (`HeartRateTickService`: one `ActiveRrSource` interval → one `TickData`). Two problems: (1) a device RR gap stalls the dot (no beat → no tick) and `ActiveRrSource` declares silence after `max(2000ms, lastInterval×2)`, so `SwitchableTickService` auto-falls-back to the clock almost immediately, losing the heart cadence; (2) the gap *can't* be papered over by "synthesize a tick when a beat is overdue" — if the real beat was merely slow and lands right after the synthetic one, the state machine gets **two ticks back-to-back** and over-advances the phase. In a 5-tick phase that double-count is −1/5 of its duration plus a visible jump. Counting ticks 1:1 with beats is the root flaw.
- Fix: **decouple ticks from individual beats.** Drive breathing from a free-running **metronome** whose period is a **moving average** of RR intervals. Real beats only update the average — they never emit ticks — so back-to-back synthetic+real can't double-count. A missing beat is filled by the metronome continuing at the last average; HRV/jitter is smoothed by the window. This is an intentional *approximation* of the heartbeat for the breathing module — smooth and accurate enough for pacing, not beat-locked.
- This **obsoletes the `×1.75` overdue-watchdog** from the earlier design (it was a crutch for the coast-on-overdue model). Only the feature-**disable** grace remains: no real beat for `_coastGraceWindow` (10 s) → disable heart, fall back to the clock.
- **Ownership split** (the "прослойка" question): the *smoothed-RR metric* is a general, reusable biometric signal → extract a new `lib/Biometrics/SmoothedRrSource.dart` (App singleton, mirrors `ActiveRrSource`). The *metronome + tick generation + grace* is breath-specific → stays in `HeartRateTickService`. `ActiveRrSource` stays **raw** (real beats only — server pipeline + future pulse animation need true HRV). A future live-BPM/HRV feature reuses `SmoothedRrSource` with no duplication.
- `SwitchableTickService`, `ClockTickService`, `ActiveRrSource`, `ITickService`, and `BreathViewModel` need **no changes**. `SwitchableTickService`'s contract ("fall back when `hasActiveSourceStream` emits false") stays true — only *when* `HeartRateTickService` emits false changes. The existing `test/BreathModule/switchable_tick_service_test.dart` stays green untouched.

## Details

### Current chain (immediate drop + double-count risk)

1. RR gap → no beat → `HeartRateTickService` emits no tick → dot stalls at the phase boundary.
2. `ActiveRrSource._restartWatchdog` fires `_onSilence` after `max(2000ms, lastIntervalMs×2)`; no other source → `_hasActiveController.add(false)`, stream quiet.
3. `HeartRateTickService.hasActiveSourceStream` proxies that → `SwitchableTickService._healthSub` sees `!hasActive && active == heartbeat` → `_switchInternal(timer)` → `sourceChanges(timer)` → `BreathSessionState.tickSource = timer`.
4. Any "synthesize a tick on overdue beat" patch double-counts: the synthetic tick + the slow-but-real beat both advance the phase.

### New component — `lib/Biometrics/SmoothedRrSource.dart` (reusable, App singleton)

A thin derived-metric layer over `ActiveRrSource`. Pure: no ticks, no breath knowledge. **Always-on and independent of any breath session** — created in `App.initialize()` and subscribed to `ActiveRrSource` from then on, so its moving average accumulates continuously in parallel with the raw stream. By the time any consumer (breath, or a future live-BPM widget) subscribes, the average is already **warm** — subscribe and read the current value. Mirrors how `ActiveRrSource` already lives independently of the session.

- Constructor `SmoothedRrSource(ActiveRrSource source, {int window = _defaultWindow})`; subscribes to `source.stream`.
- Maintains a ring of the last `window` **non-artifact** intervals (skip `rr.isArtifact` — this is the artifact-filter slot the docs flag as "easy to add later"); on each accepted interval recompute the simple moving average and publish it.
- Exposes: `int? get smoothedIntervalMs` (current SMA, null before the first beat), `Stream<int> get smoothedIntervalStream` (BehaviorSubject — emits once per accepted real beat), and pass-throughs `bool get hasActiveSource => source.hasActiveSource` / `Stream<bool> get hasActiveSourceStream => source.hasActiveSourceStream`.
- `static const int _defaultWindow = 7;` (9 is smoother / more robust to a single outlier but lags real HR changes more — one-line change).
- `dispose()` cancels the subscription and closes its subject. Does **not** dispose `source` (owned by `App`).
- Wiring: `App.initialize()` creates `smoothedRrSource = SmoothedRrSource(activeRrSource)` after `activeRrSource`; `BreathModule.buildSession()` injects `App.shared.smoothedRrSource` into `HeartRateTickService` (replacing the direct `activeRrSource` injection).

### Rewritten `HeartRateTickService` — free-running metronome on the smoothed cadence

`HeartRateTickService` stops 1:1 beat→tick. Constructed per-session over the **already-warm** `SmoothedRrSource`, so it starts without a ramp. It owns an `_effectiveActive` `BehaviorSubject<bool>` **seeded from `smoothedRrSource.hasActiveSource`** (not hard false) — so on opening a session with a live sensor the heart toggle is available immediately and no false fallback fires. It re-points the getters at it (`hasActiveSource`/`hasActiveSourceStream` — exactly what `SwitchableTickService` reads).

**Mirror `ClockTickService` exactly — this is the binding rule, not a preference.** The clock proves the pattern: `simulateTick()` starts a `Timer.periodic` at `buildSession` and runs untouched until `dispose()`; it does **not** emit an immediate tick; it has **no** pause logic. Pause is enforced solely by `BreathSessionStateMachine._onTick`, which early-returns while `status == pause || complete` and drops the ticks. The metronome must behave identically.

- **Metronome lifecycle:** a self-rescheduling timer, **started at construction in `buildSession`** alongside the clock (e.g. `HeartRateTickService(...)..start()`, mirroring `ClockTickService()..simulateTick()`); free-runs for the whole session; **never stops** until `dispose()` cancels it; emits into a broadcast `_tickController` that `SwitchableTickService` forwards only while heartbeat is the active source. On fire → emit `TickData(_currentPeriodMs)`, then reschedule at `_currentPeriodMs`.
- **No prime tick.** First metronome tick lands after one period — same as the clock. Because `SmoothedRrSource` is warm, that period is already a real averaged interval, so startup latency ≤ one real beat. Do not add an immediate tick (it would diverge from the clock for no reason).
- **No pause logic.** Do not subscribe to lifecycle, do not stop on pause/background. The state machine gates ticks. (Dart `Timer.periodic` is suspended by the OS in background anyway and does not catch up — same as the clock.)
- **Period:** `_currentPeriodMs` = `smoothedRrSource.smoothedIntervalMs ?? 1000` (1000 ms placeholder only if a beat has literally never arrived).
- **On each smoothed emission** (`smoothedRrSource.smoothedIntervalStream`, i.e. a real beat arrived): update `_currentPeriodMs`, set `_effectiveActive` true, and **reset the grace timer**. Beats adjust the period; they do **not** emit ticks → no double-count.
- **Grace timer** (`_coastGraceWindow`, 10 s; reset on every real beat; armed at construction if seeded active): when it fires (no real beat for 10 s) → `_effectiveActive.add(false)` only. The metronome is **not** stopped. `SwitchableTickService` reacts to the false → auto-falls-back to the clock → `sourceChanges(timer)` → `tickSource` flips. This is the single, real "drop to clock". Auto-fallback is one-way; the user re-enables manually (now possible since a later beat flips `_effectiveActive` true again).
- **Coast falls out for free:** during the 0–10 s silence window `_effectiveActive` is still true, so the metronome keeps forwarding at the last smoothed period — that *is* the coast. No separate coast code path.
- **Before the first beat ever** (`smoothedIntervalMs == null`): the metronome runs at the 1000 ms placeholder but `_effectiveActive` stays false (seeded from the cold source) until the first real beat, so the feature isn't claimed without a source (matches today) and `trySwitchTo(heartbeat)` is rejected.
- Named constant: `static const Duration _coastGraceWindow = Duration(seconds: 10);`.

### Testability (folded in, same file)

Inject timer factories the way `ActiveRrSource` already does (note 90): a periodic/self-reschedule factory for the metronome and a one-shot `Timer Function(Duration, void Function()) = Timer.new` for the grace timer. Defaults preserve production behavior. Feed a scripted `smoothedIntervalStream` (or drive a fake `SmoothedRrSource`) to assert cadence + grace deterministically without real delays.

### Files

- `lib/Biometrics/SmoothedRrSource.dart` — **new** reusable smoothing layer.
- `lib/Core/App.dart` — create `smoothedRrSource` singleton after `activeRrSource`.
- `lib/BreathModule/BreathModule.dart` — inject `smoothedRrSource` into `HeartRateTickService`.
- `lib/BreathModule/HeartRateTickService.dart` — metronome rewrite + grace + injected factories.
- `docs/breath/session/tick-sources.md` — `HeartRateTickService` is now a smoothed-cadence metronome (period = moving average of RR via `SmoothedRrSource`), not 1:1 beat→tick; auto-fallback fires only after `_coastGraceWindow` (10 s) of no real beat.
- `docs/biometrics/active-rr-source.md` — note the new `SmoothedRrSource` derived layer sits above `ActiveRrSource`; `ActiveRrSource` stays raw, its silence window unchanged. (Consider a short `docs/biometrics/smoothed-rr-source.md`.)

### Guards

- Do **not** touch `SwitchableTickService`, `ClockTickService`, `ActiveRrSource`, `ITickService`, or `BreathViewModel` — the metronome/grace must live above `hasActiveSourceStream` so the single `sourceChanges` channel keeps `tickSource` correct.
- **Real beats must never emit ticks** — only update the metronome period. This is the whole fix for the double-count; do not "also emit on beat."
- **Mirror `ClockTickService`: no prime tick, no pause/lifecycle logic, never stop the metronome on grace** (grace flips `_effectiveActive` only). Diverging from the clock here is a bug, not an enhancement.
- Do **not** synthesize anything back into `ActiveRrSource.stream` — `ActiveRrSource` stays raw real-RR-only.
- Metronome period = **smoothed** interval, never a raw single interval, never the ×nominal.
- `SmoothedRrSource` is pure metric — no `ITickService`, no breath imports, no grace logic (that's breath's).
- Cancel the metronome timer + grace timer in `HeartRateTickService.dispose()`; cancel sub + close subject in `SmoothedRrSource.dispose()`. Neither disposes `ActiveRrSource` (owned by `App`).

### How to verify

- `observe-logs` (`bash ~/.claude/skills/observe-logs/scripts/query-loki.sh since-restart mind_mobile --project mind`): on an RR gap, ticks keep arriving at the smoothed cadence (no stall, no double-tick), `tickSource` stays `heartbeat`; after 10 s with no real beat it flips to `timer` exactly once. With a slow-but-present beat, tick count stays ~1 per beat — no over-advance.
- Unit test: feed a scripted smoothed cadence; assert the metronome emits at the smoothed period; assert a (late) real beat updates the period but adds **no** extra tick; advance 10 s with no beat → `hasActiveSourceStream` emits false once; a beat before 10 s resets the grace.
- Pause: assert that with the metronome free-running, a paused state machine advances no phase (the state machine already drops ticks) — confirms no pause logic is needed in the tick service.

## Decisions (settled — do not re-open)

- **Mirror `ClockTickService`**: no prime tick, no pause/lifecycle handling, metronome started at construction and never stopped on grace. Verified against the clock's actual code (`simulateTick` = `Timer.periodic`, no immediate tick; pause is gated by `BreathSessionStateMachine._onTick`). This reverses an earlier "emit a prime tick" idea.
- **`SmoothedRrSource` is always-on/warm** (App singleton from `App.initialize()`), so the metronome reads a real period immediately; `_effectiveActive` seeds from its availability.
- **SMA window = 7, grace = 10 s** — named constants. SMA (not EMA) for predictability and to match the "period 7/9" framing. 9 = smoother but laggier (one-line change).

## Open Questions

- None blocking implementation. (Future, non-blocking: free-running metronome is not phase-locked to individual beats — an intentional approximation; a future feature needing true beat-locked pacing would consume `ActiveRrSource` directly. `BreathMotionEngine` already EMA-smooths `intervalMs` for *animation velocity* — downstream of and independent from this *cadence* smoothing; no conflict, but worth knowing.)
