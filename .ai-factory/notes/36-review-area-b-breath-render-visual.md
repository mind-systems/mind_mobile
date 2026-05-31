# Code Review — Area B: Breath Render Perf + Visual Redesign (Phases 15, 16, 20)

**Date:** 2026-05-31
**Source:** conversation context (roadmap review, branch `bci-integration`)
**Scope:** `BreathSessionViewModel.dart`, `Models/BreathSessionState.dart`, `BreathSessionScreen.dart`, `BreathSessionLayout.dart`, `Views/BreathTimelineWidget.dart`, `packages/mind_ui/lib/src/{ControlButton,AppTheme}.dart`

## Verdict

The render-scope work (Phases 15–16) is solid and internally consistent — dual-channel publication, narrow `.select` consumers, the per-tick `ValueNotifier` side-channel, and the `identical()` carry-by-reference invariant all line up with their documented design, and the `[BREATH-PROBE]` instrumentation is fully removed. The visual redesign (Phase 20) is correct except one missed surface.

## Key Findings

- **[Medium-low / visual] The active timeline row still renders the OLD cyan, not the gold redesign.** `BreathTimelineWidget.dart:214`: `final color = isActive ? const Color(0xFF00D9FF) : ...`. Phase 20 replaced cyan with `colorScheme.tertiary` "everywhere on the session screen" but only touched 4 files — `BreathTimelineWidget` was not in that list. Result: the active step label + countdown number render cyan while the orb, shape, and all bottom-bar icons are warm gold. Needs a product call: if the timeline accent is meant to stay cyan it should read `cs.primary` (which *is* `0xFF00D9FF`), not a hardcoded literal; if it was an oversight it should be `cs.tertiary`.
- **[Low / dead code] Two stale cyan default fallbacks.** `BreathShapeWidget.dart:46` and `BreathShapePainter.dart:19` both default `shapeColor` to `const Color(0xFF00D9FF)`. The screen always passes `cs.tertiary` explicitly (`BreathSessionScreen.dart:242`), so these defaults are unreachable at runtime — harmless but stale post-redesign.

## Details

### Render-scope mechanics (verified correct)
- `BreathViewModel.set state` (lines 95–103): publishes to Riverpod (`super.state = value`) only when `!value.equalsIgnoringTickFields(super.state)`; the raw `_stateController.add(value)` always fires. Animation/sound/state-channel coordinators keep per-tick cadence on the raw stream; the screen does not rebuild on tick-only deltas.
- `equalsIgnoringTickFields` (State lines 95–110) excludes `remainingTicks`, `currentIntervalMs`, **and `resetReason`** — the Phase 16 change is present; `resetReason` is documented as a raw-stream-only transient. `timelineSteps` compared by `identical(...)`, and `_onEngineState` carries `state.timelineSteps` by reference (line 185), so the identity invariant holds. The per-tick `.map().toList()` reallocation is gone.
- Active countdown flows only through `remainingTicksNotifier` (`ValueListenable<int>`), wired to the active row's `ValueListenableBuilder` (`BreathTimelineWidget.dart:237-241`); inactive rows render static `step.duration`, completed rows derive `'0'` from list position (`activeIndex`). Only one `Text` rebuilds per tick.
- `BreathSessionScreen.build` does **not** `ref.watch` the provider at top level — every subscription is a narrow `.select` inside its own `Consumer` (loadState; (steps,activeStepId,status); (status,loadState); (canStar,isStarred); tickSource). Matches the Phase 16 acceptance criteria.

### Layout (clean)
`BreathSessionLayout.compute` derives a single uniform `scale = availableHeight / _idealHeight`, and `_idealHeight` is computed from the same private constants used per-field — no hardcoded 652 to drift. Public `kBottomBarBaseHeight`/`kIconSize` are the single source consumed by `SessionBottomBar`. No `* scale` arithmetic leaks into `build()`.

### Minor observations (not findings)
- Tapping the orb toggles `_isBlackedOut` via `setState`, which rebuilds the whole `build()` subtree once (all `Consumer` builders re-run, though `.select` still gates future Riverpod-driven rebuilds). Rare user action — acceptable.
- `ControlButton` correctly uses `cs.primary` (cyan) by design — Phase 20 explicitly kept the central button cyan.

## Open Questions

- Product decision on the active timeline color: gold (`cs.tertiary`, consistent with redesign) or cyan accent (`cs.primary`, consistent with the central control button)? Either way, replace the hardcoded `0xFF00D9FF` literal with the theme reference.
