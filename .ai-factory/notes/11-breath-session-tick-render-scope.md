# Breath Session — Per-Tick Render Scope Layering

**Date:** 2026-05-20
**Source:** conversation context

## Key Findings

- The visible per-second stutter on `BreathSessionScreen` is **not** caused by `_EclipsePainter` GPU cost — the orb animation runs in its own isolated `Ticker` and never triggers the per-second jank.
- Root cause: every state-machine tick rebuilds the **entire** `BreathSessionScreen` subtree because `ref.watch(breathViewModelProvider)` subscribes to the whole `BreathSessionState`, and `_onEngineState` allocates a new `timelineSteps` list on every tick.
- The right architectural fix is to **separate responsibilities by render scope**: structural state (timeline shape, status, active step id) belongs in the screen's `watch`, while the ticking field (`remainingTicks`) must flow on a dedicated channel so only the active timeline item repaints.

## Details

### Three render scopes that must stay isolated

```
   Scope                        Update frequency    Owner
   ─────                        ────────────────    ─────
   1. Orb / shape animation     60 fps              own Ticker + ValueListenable
                                                    (already isolated ✓)

   2. Structural state          rare (phase change, only ref.watch with select
      activeStepId, status,     start/pause/complete)
      timelineSteps shape

   3. Tick countdown            1 Hz                separate ValueListenable<int>
      (remainingTicks)                              consumed inside the active
                                                    _TimelineItem only
```

Today scopes 2 and 3 are **fused** inside a single `BreathSessionState` watched by the whole screen — that fusion is the bug.

### Concrete bleeding points

| # | File / line                                | What's wrong                                                  |
|---|--------------------------------------------|---------------------------------------------------------------|
| ① | `BreathSessionViewModel.dart:136`          | `.map().toList()` rebuilds the whole `timelineSteps` per tick |
| ② | `BreathSessionScreen.dart:162`             | `ref.watch(provider)` without `select` → full Scaffold rebuild|
| ③ | `BreathTimelineWidget.dart:103`            | `LinearGradient` allocated inside `shaderCallback` each paint |
| ④ | `BreathTimelineWidget.dart:43`             | `widget.steps != oldWidget.steps` is always true → ListView rebuild |
| ⑤ | `_TimelineItem.dart:224`                   | `AppLocalizations.of(context)` lookup per item per tick       |
| ⑥ | `BreathSessionScreen.dart:154`             | `MediaQuery.of(context)` in build path re-runs every tick     |

### Treatment strategy (in priority order)

```
1. Pull `remainingTicks` out of BreathSessionState → ValueNotifier<int> on
   BreathViewModel. Active _TimelineItem subscribes via ValueListenableBuilder.
   → tick no longer touches the screen rebuild path.

2. Switch ref.watch(provider) to ref.watch(provider.select(...)) per consumer
   block (timeline structure, status, controls).

3. Stop reallocating timelineSteps in _onEngineState — keep the list stable,
   mutate only the active step's duration via the dedicated channel from (1).

4. const-ify the LinearGradient inside ShaderMask (cache as field on State).

5. Wrap Stack(orb + shape) in RepaintBoundary so paint inval can't propagate.
```

### Why the EclipseOrb investigation was a red herring

The painter does create 6 gradients + 5 `MaskFilter.blur` + 6 `BlendMode.plus`
saveLayers per frame, and that does waste GPU. But it runs at a stable cadence
because its `Ticker` and `setState` live inside `_EclipseOrbState` — they
repaint only the orb, not the whole screen. That work is independent of the
1 Hz hiccup and can be optimized later as a separate concern (pre-rasterize the
orb into a `ui.Picture` once and `drawImage` per frame).

### Lesson for future debugging

When a profile shows "expensive per-frame allocations" (e.g. `Gradient.__constructor`)
but the **user-perceived** stutter is periodic (per-second), distrust the
flame-graph view: the stutter is almost certainly a **rebuild-scope** problem,
not a per-frame GPU cost. Trace the cadence of the symptom — not the volume of
allocations — to the actual rebuild root.

## Resolved: subscriber audit

Walked all consumers of `BreathSessionState` to settle the two open questions:

| Subscriber                    | Channel                         | Needs `remainingTicks`? |
|-------------------------------|---------------------------------|-------------------------|
| `BreathAnimationCoordinator`  | raw `viewModel.listen()` stream | **yes** — feeds `motionEngine.setRemainingPhaseTicks` for inter-tick interpolation |
| `OrbAnimationCoordinator`     | raw `viewModel.listen()` stream | **yes** — drives orb progress |
| `BreathSoundCoordinator`      | raw `viewModel.listen()` stream | debug-print only         |
| `BreathModuleStateChannel`    | raw `_stateController.stream`   | **no** — reads only `status`/`phase`/`exerciseIndex`/`currentIntervalMs` |
| `BreathSessionScreen`         | `ref.watch(provider)` (Riverpod) | yes today, but should NOT |

**Conclusion: do NOT remove `remainingTicks` from `BreathSessionState`.** The
animation coordinators need the tick cadence and read it from the raw stream —
that channel must keep ticking at 1 Hz.

The fix lives one layer down: filter the **Riverpod publication** (`super.state =`)
so it skips updates that only change `remainingTicks` (and `timelineSteps`,
which today is rebuilt solely to mutate the active step's `duration`). The raw
`_stateController.add(value)` channel continues to tick — coordinators stay
correct. The screen's `ref.watch` only fires on structural changes.

For the per-tick countdown shown inside the active timeline row: expose a
sibling `ValueListenable<int>` (e.g. `remainingTicksNotifier`) on
`BreathViewModel`, consumed by a tiny `ValueListenableBuilder` inside the
active `_TimelineItem`. `BreathModuleStateChannel` is unaffected because it
doesn't read the field at all.
