# Code Review: Breath survives the lock (remove the lifecycle auto-pause)

**Reviewed:** `git diff HEAD` — `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
**Plan:** `.ai-factory/plans/74-breath-survives-the-lock-remove-the-lifecycle-auto-pause.md`

## Scope of change
Single-file deletion in `BreathSessionScreen`:
- Removed `WidgetsBindingObserver` from the `_BreathSessionScreenState` mixin list (kept `TickerProviderStateMixin`).
- Removed `WidgetsBinding.instance.addObserver(this)` from `initState`.
- Removed `WidgetsBinding.instance.removeObserver(this)` from `dispose`.
- Removed the entire `didChangeAppLifecycleState` override (the `paused`→`suspend()`+conditional `pause()` branch and the `resumed`→`resume()` branch).

This matches both tasks in the plan exactly.

## Correctness verification

- **No dangling references.** `didChangeAppLifecycleState` was the only `WidgetsBindingObserver` callback in the file, so removing the mixin and observer registration leaves no overridden-but-uncalled members. Verified by grep across the package.
- **No unused imports introduced.** `_soundCoordinator` is still used in `build` (mute toggle `isMuted`/`toggleMute`) and `_buildControlButton` (`reset()`), so `Audio/BreathSoundCoordinator.dart` stays referenced. `BreathSessionStatus` is still used in `_buildControlButton`. `AppLifecycleState` came from the bulk `package:flutter/material.dart` import, so its disappearance produces no unused-import warning.
- **`dispose` still tears down `_soundCoordinator`** (`_soundCoordinator.dispose()` at line 117) — removing the observer does not orphan any resource.
- **Constructor screen unaffected.** `BreathSessionConstructorScreen` has its own independent `WidgetsBindingObserver` (`BreathSessionConstructorScreen.dart:24`); this change does not touch it.
- **User-initiated pause untouched.** The pause/resume control button (`_buildControlButton`, lines 394–414) still calls `viewModel.pause()`/`resume()` directly — unchanged.

## Non-blocking observations (no action required for this milestone)

1. **Orphaned `BreathSoundCoordinator.suspend()` / `resume()`.** With the lifecycle handler gone, these two methods (`BreathSoundCoordinator.dart:136`, `:141`) now have zero callers anywhere in the repo. This is dead code, but the plan explicitly scoped out touching `BreathSoundCoordinator` internals ("don't touch ... `BreathSoundCoordinator` internals"), so leaving them is the intended outcome. Public methods are not flagged by `flutter analyze`, so this causes no build/analyze failure. Worth a future cleanup, not a defect here.

2. **Stale documentation.** `docs/breath/session/audio.md:76-77` still documents the `AppLifecycleState.paused`→`suspend()`+`pause()` and `resumed`→`resume()` behavior that this change removes. The plan set `Docs: no`, so this is out of scope for the milestone, but the doc now describes behavior that no longer exists and should be updated in a follow-up.

## Runtime risk assessment
No type mismatches, no migrations, no race conditions. The change is a pure removal of lifecycle reactivity; the breath loop, tick sources, and `BreathSessionStateMachine` continue running on background as intended (process survival itself depends on the keep-alive foundations from notes 138/139, which are prerequisites and outside this diff). Manual verification (lock device mid-session, confirm audio/ticks continue and orb is correctly advanced on unlock) is still required per the plan's Notes.

No bugs, security issues, or correctness problems found in the code change.

REVIEW_PASS
