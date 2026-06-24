# Tick cadence pipeline re-decomposition — `ITickCadenceSource` + selector (behavior-preserving, RR only)

**Date:** 2026-06-23
**Source:** conversation context

## Key Findings

- The breath "heart" tick path today bakes **three concerns into one place**: smoothing lives in `SmoothedRrSource`, while **staleness/availability** (the 10 s `_coastGraceWindow`) **and** the metronome both live inside `HeartRateTickService`. To add a second cadence source (HR-derived, note 164) cleanly, each source must fully encapsulate its own smoothing **and** its own "usable right now?" status, and the metronome must become a dumb consumer.
- A tick cadence source should expose exactly two things: a **smoothed period (MA) stream** and a **usable status**. When not usable it simply emits nothing — the metronome coasts / the selector falls back.
- This milestone is a **behavior-preserving refactor**: with a single RR source wired, the runtime behavior must be byte-for-byte equivalent to today (same SMA, same 10 s grace, same auto-fallback to the clock). The HR source is added in note 164.
- **Do NOT touch `ActiveRrSource`** — its watchdog/selection logic is explicitly out of scope (the original "heart tick didn't switch" symptom was *not* an `ActiveRrSource` liveness bug; that line of investigation is dropped).

## Details

### New contract — `lib/BreathModule/TickCadence/ITickCadenceSource.dart`

```dart
abstract interface class ITickCadenceSource {
  Stream<int> get smoothedPeriodMs;   // MA cadence curve, ms-per-beat
  bool get isUsable;                  // can drive ticks right now
  Stream<bool> get usableChanges;     // transitions of isUsable (BehaviorSubject)
  void dispose();
}
```

### `RrTickCadenceSource(SmoothedRrSource)` — absorbs the grace/availability today in `HeartRateTickService`

Wraps the existing `SmoothedRrSource` (unchanged; SMA over last 3 non-artifact RR — `_defaultWindow = 3`, `SmoothedRrSource.dart:33`).

- `smoothedPeriodMs` ← `smoothedRrSource.smoothedIntervalStream` (`Stream<int>`, `SmoothedRrSource.dart:51`).
- `isUsable` — relocate the **entire** `_effectiveActive` / `_droppedReplay` / `_armGrace` / `_onGraceExpired` machinery from `HeartRateTickService` verbatim (cite lines, copy exact):
  - seed `BehaviorSubject<bool>.seeded(smoothedRrSource.hasActiveSource)` (`HeartRateTickService.dart:33`; `hasActiveSource` is `SmoothedRrSource.dart:54`);
  - keep the warm/cold replay guard `expectReplay = smoothedRrSource.smoothedIntervalMs != null` then `_droppedReplay = !expectReplay` (`HeartRateTickService.dart:37,41`; `smoothedIntervalMs` is `int?`, `SmoothedRrSource.dart:47`) so the first stale BehaviorSubject replay does not count as a genuine beat;
  - on a genuine (non-replay) smoothed emission → `isUsable = true` + re-arm the 10 s grace (the activation half of `_onSmoothed`, `HeartRateTickService.dart:141-144`; `_coastGraceWindow = Duration(seconds: 10)`, `:54`; `_armGrace`, `:149-151`);
  - grace expiry → `isUsable = false` (`_onGraceExpired`, `HeartRateTickService.dart:154-155`).
- This is the single home of RR staleness. `dispose()` cancels the smoothed sub + grace timer + closes the subject; does **not** dispose `SmoothedRrSource` (App-owned singleton).

### `TickCadenceSelector(List<ITickCadenceSource> sources)` — keeps all warm, picks first usable by priority

- Subscribes to every source's `usableChanges` at construction (all warm in parallel).
- Active = the lowest-index source with `isUsable == true`; re-pipes that source's `smoothedPeriodMs` to its own output. Re-selects on any `usableChanges`.
- Exposes the same `ITickCadenceSource` surface: `smoothedPeriodMs` (active source's curve), `isUsable` (any usable), `usableChanges`.
- With a single source it is a pass-through → behavior-preserving.
- `dispose()` cancels its subs + disposes each child source.

### Metronome — rewrite `HeartRateTickService` as a dumb `ITickService` consumer

Keep it implementing `breath_module`'s `ITickService` (`source => TickSource.heartbeat`, `nominalIntervalMs => 1000`, `sourceChanges => Stream.empty()`, `trySwitchTo => false`). **Keep the name `HeartRateTickService`** — only its internals are gutted.

- Constructor signature `HeartRateTickService({required ITickCadenceSource cadence, Timer Function(Duration, void Function()) timerFactory = Timer.new})` — replaces the current `smoothedRrSource:` param (`HeartRateTickService.dart:28-31`). Subscribe to `cadence.smoothedPeriodMs` → update `_currentPeriodMs` (`:63`).
- **Keep** the free-running self-rescheduling metronome (`_scheduleNext` / `_onMetronomeFire`, `:117-128`) and the 250–3000 ms clamp (`_periodFloorMs = 250` / `_periodCeilMs = 3000`, `:114-115`). Real beats still never emit ticks. `start()` (`:95`) still called once at construction.
- `hasActiveSource` / `hasActiveSourceStream` (`:88-89`) now **delegate** to `cadence.isUsable` / `cadence.usableChanges`.
- **Remove**: `_coastGraceWindow` (`:54`), `_effectiveActive` (`:58`), `_droppedReplay` (`:62`), `_armGrace` (`:149`), `_onGraceExpired` (`:154`), and the activation half of `_onSmoothed` (`:141-144`). No grace timer in the metronome anymore — staleness is the source's job (this is the de-duplication the design calls for).

### `SwitchableTickService` — unchanged

Still listens to `_heart.hasActiveSourceStream` and reads `_heart.hasActiveSource` in `trySwitchTo`; those getters now delegate to the selector. No code change required there.

### Wiring — `lib/BreathModule/BreathModule.dart:33-34`

```dart
final rrCadence = RrTickCadenceSource(App.shared.smoothedRrSource);
final selector  = TickCadenceSelector([rrCadence]);
final heart     = HeartRateTickService(cadence: selector)..start();
final tickService = SwitchableTickService(clock: clock, heart: heart);
```

`SwitchableTickService.dispose()` already disposes `_heart`; the metronome must dispose the selector, which disposes the RR cadence source. `App.dart:225-226` (`ActiveRrSource`/`SmoothedRrSource` singletons) is untouched.

## How to verify

- One RR source wired → identical behavior to today: heart tick toggles on with a live RR cadence, coasts through short gaps, and auto-falls-back to the clock after the 10 s grace. (Relocating the grace must not change its duration or semantics.)
- `flutter analyze` clean; existing tick-service tests (`test/.../switchable_tick_service`, note 91) still green, adjusted only for the new construction seam.

## Decisions

- **Keep the name `HeartRateTickService`** for the gutted metronome — internals change, name stays.
- **`RrTickCadenceSource` + `TickCadenceSelector` + metronome stay per-session** (built in `BreathModule.buildSession()`, like the tick services today) — not App-singletons. The underlying `SmoothedRrSource` is already an App-singleton and stays warm across sessions regardless, so no cadence warmth is lost.
