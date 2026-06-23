# Plan: Breath survives the lock (remove the lifecycle auto-pause)

## Context
Stop `BreathSessionScreen` from auto-pausing the breath loop and silencing audio when the app is backgrounded, so the session keeps running while the device is locked (relying on the keep-alive foundations from notes 138/139). The user-initiated pause button is untouched.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Remove lifecycle auto-pause

- [x] **Task 1: Drop the lifecycle-driven auto-pause in `didChangeAppLifecycleState`**
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  Remove the body of `didChangeAppLifecycleState` (lines 127-138): delete the `paused`-branch (`_soundCoordinator.suspend()` + the conditional `pause()` for `breath`/`rest` status) and the `resumed`→`_soundCoordinator.resume()` branch. After this change the screen no longer reacts to app lifecycle transitions, so the breath audio loop, tick one-shots, and `BreathSessionStateMachine` keep running on background. Do **not** touch `BreathSessionStateMachine`, the tick sources, or `BreathSoundCoordinator` internals — only remove the call sites here.

- [x] **Task 2: Clean up the now-unused `WidgetsBindingObserver` wiring** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  `didChangeAppLifecycleState` is the only lifecycle observer callback in this file. With its body gone the override is dead code, so remove it entirely along with its supporting wiring: the `WidgetsBindingObserver` mixin from the `_BreathSessionScreenState` declaration (line 34, keep `TickerProviderStateMixin`), `WidgetsBinding.instance.addObserver(this)` in `initState` (line 50), and `WidgetsBinding.instance.removeObserver(this)` in `dispose` (line 122). Leave the rest of `initState`/`dispose` intact (motion engine, shape shifter, coordinators, scroll controller setup/teardown). Run `flutter analyze` on the package and resolve any unused-import or unused-member warnings introduced by the removal.

## Notes
- Spec: `.ai-factory/notes/140-breath-survives-background.md`.
- Depends on notes 138 (iOS background audio) and 139 (Android FGS) being in place so the process actually survives suspension; this milestone only removes the self-pause.
- Verify manually: start a breath session with audio, lock the device — guidance/ticks continue; unlock after ~1 min and the orb is at the correctly advanced phase (not frozen), with no biometric log gap.

## Commit
Single commit after both tasks: "Remove breath session lifecycle auto-pause so it survives backgrounding"
