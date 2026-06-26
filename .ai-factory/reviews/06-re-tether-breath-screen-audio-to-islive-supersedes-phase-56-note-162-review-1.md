# Code Review: Re-tether breath screen audio to `isLive`

**Scope of changes reviewed:** `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart` (the only source file changed; the rest of the diff is plan/metadata files).

## Summary

The change adds `WidgetsBindingObserver` to `_BreathSessionScreenState`, registers/removes the observer correctly, and implements `didChangeAppLifecycleState` to suspend the sound coordinator on background when the session is not live, resuming on foreground. The implementation matches the plan exactly and the existing observer idiom in `BreathSessionConstructorScreen`.

## Correctness analysis

- **No use-before-init.** `_soundCoordinator` is `late final`, assigned synchronously in `initState` (`:72`). The observer is added at `:50`, but `didChangeAppLifecycleState` cannot fire re-entrantly during `initState` — lifecycle events are dispatched on a later event-loop turn via the platform channel. By the time any callback runs, the coordinator is assigned. No `LateInitializationError` risk.
- **No use-after-dispose.** `dispose` calls `WidgetsBinding.instance.removeObserver(this)` first (`:116`), before `_soundCoordinator.dispose()` (`:119`) and `super.dispose()`. No lifecycle callback can reach a disposed coordinator. Disposal ordering is correct.
- **Switch is well-formed.** Dart 3 switch statements do not fall through on non-empty cases, so `paused` and `resumed` are independent. `default: break;` correctly ignores `inactive` / `detached` / `hidden`. Style matches the file's existing switches.
- **Gate logic is right.** `isLive` is true only for `running`/`paused` (`BreathSessionState.dart:56-58`). On background: `notStarted`/`completed` → `!isLive` → `suspend()` stops the `tick_clock.ogg` one-shot (the reported bug); `running`/manual-`paused` → no-op, audio survives the lock (the stated constraint). `suspend()` setting `_isSuspended` is honored by the `_onTick` early-return.
- **`resume()` is safe unconditionally.** It only clears `_isSuspended`; on a never-suspended coordinator the flag is already `false`, so the call is a harmless no-op. No interaction with the independent `isMuted` path.
- **`suspend()` before audio finishes loading is safe.** It sets `_isSuspended` and calls `_oneShot.stop()`, which is benign pre-load, and the flag persists through `_initAudio` (which never clears it). A session backgrounded before the post-frame `initialize()` runs stays correctly suspended.

## Constraint compliance

- No running-session auto-`pause()` re-added (Phase 51 regression avoided). ✅
- Active and manual-pause sessions stay audible in background. ✅
- No changes to FGS, biometrics, state machine, tick sources, or `BreathSoundCoordinator` internals — only the existing `suspend()`/`resume()` are called. ✅
- Meditation untouched. ✅

## Findings

None. The change is minimal, correct, lifecycle-safe, and within scope.

REVIEW_PASS
