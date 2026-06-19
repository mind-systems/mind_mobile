# State machine: seed the tick source's nominal interval at init instead of `-1`

**Date:** 2026-06-19
**Source:** conversation context

## Key Findings

- `BreathSessionStateMachine._initialRestState()` and `_initialBreathState()` set `currentIntervalMs: -1` (`BreathSessionStateMachine.dart:127,151`), and `resume()` (line 182) carries that `-1` forward into the first active state. So at the origin the session has **no cadence** until the first tick lands.
- This `-1` is the shared root of two recurring bugs: (a) breath animation/audio cannot run at origin because they read `currentIntervalMs` as the cadence and `-1` is meaningless until the first tick (a bug we have hit before); (b) any duration math at origin is poisoned (the `durationMs:-15`, addressed at the wire level by note 121).
- The state machine is alive from construction and the **nominal** cadence is always known: timer source = `1000 ms`; heart-rate source = a sane default until the first RR interval arrives. There is no reason to represent the origin cadence as `-1`.
- `-1` is legitimate only as a *measured* inter-tick delta sentinel. The fix is to seed the *nominal/configured* interval at init, not to abolish the measured field.

## Details

### Current state
- `ITickService` (`packages/breath_module/lib/src/ITickService.dart`) exposes `tickStream`, `source`, `sourceChanges`, `trySwitchTo`, `dispose` — **no nominal-interval accessor**. The `TickData.intervalMs` field on the same file (line 19) is the per-tick *measured* delta delivered with every tick (always real — `ClockTickService` emits `TickData(1000)`); it is NOT the `-1`. The `-1` is the state machine's `currentIntervalMs` **seed** at `BreathSessionStateMachine.dart:127,151`, distinct from `TickData.intervalMs`.
- `ClockTickService` (`lib/BreathModule/ClockTickService.dart:16`) ticks every `1000 ms` and emits `TickData(1000)`.
- `HeartRateTickService` emits a tick per RR interval (first RR can be 1.3–17 s away).
- `SwitchableTickService` wraps an active source and forwards ticks.

### The change
1. Add `int get nominalIntervalMs` to `ITickService`.
2. `ClockTickService.nominalIntervalMs => 1000`. `HeartRateTickService.nominalIntervalMs` returns a default (last-known RR if available, else a `1000` placeholder). `SwitchableTickService.nominalIntervalMs` delegates to the currently active source.
3. In `BreathSessionStateMachine._initialRestState()` and `_initialBreathState()`, replace `currentIntervalMs: -1` with `currentIntervalMs: tickService.nominalIntervalMs`.

### Why independently shippable
- After note 121 the wire no longer carries `durationMs`, so `-1` never reaches the server regardless of this milestone. This task is purely about the **in-app origin cadence** for animation/audio (and future consumers reading `currentIntervalMs` at origin). It can ship before or after note 121 with no contract impact.

### Guards
- Do NOT change cadence behavior after the first real tick — `_onBreathTick`/`_onRestTick`/`_startNewCycle`/`_startRest` keep folding the measured `tickData.intervalMs` exactly as now.
- The measured-delta sentinel may still appear elsewhere; this change only affects the two initial-state builders.
- `equalsIgnoringTickFields` already excludes `currentIntervalMs`, so seeding a real value does not perturb structural-change detection.
- `BreathSessionState.initial()` (`Models/BreathSessionState.dart:66`) also seeds `currentIntervalMs: -1`, but it is the **pre-load** state (`loadState: loading`) with no cadence consumer — leave it `-1`. Only the two state-machine initial builders (`_initialRestState`/`_initialBreathState`) get the nominal seed.

## Open Questions

- For `HeartRateTickService`, is a last-known RR cached anywhere at construction, or is the `1000` placeholder the only honest default before the first beat? If a default RR (e.g. derived from a configured BPM target) is available, prefer it.
  **Resolution:** `HeartRateTickService.nominalIntervalMs => 1000` placeholder. Verified: the service caches no last RR and has no BPM target; the origin seed is overwritten on the first real beat, so the effect is the first frame only. No config-derived RR.
