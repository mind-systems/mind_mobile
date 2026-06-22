# Breath session survives device lock (stop the lifecycle auto-pause)

**Date:** 2026-06-22
**Source:** conversation context

## Key Findings

- Breath **deliberately pauses itself** when backgrounded: `BreathSessionScreen.didChangeAppLifecycleState` calls `_soundCoordinator.suspend()` and, if the session is `breath`/`rest`, `breathViewModelProvider.notifier.pause()`. Combined with no background-execution capability, a locked device both stops the engine and (within ~1 min) gets the whole isolate suspended.
- To make breath continue when the device locks, **remove the lifecycle-driven auto-pause** and let the keep-alive foundations (iOS background audio note 138, Android FGS note 139) hold the process alive so the breath loop, ticks, and state machine keep running.

## Details

### Current state
`packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`:
- `:50` `WidgetsBinding.instance.addObserver(this)`; `:122` `removeObserver`.
- `:127-138`:
  ```dart
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _soundCoordinator.suspend();
      final status = ref.read(breathViewModelProvider).status;
      if (status == BreathSessionStatus.breath || status == BreathSessionStatus.rest) {
        ref.read(breathViewModelProvider.notifier).pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      _soundCoordinator.resume();
    }
  }
  ```
- `_soundCoordinator` is `BreathSoundCoordinator`; `suspend()` (`packages/mind_audio` coordinator) only stops the one-shot tick player — the loop keeps playing — and `pause()` halts the breath engine.

### Change
- Remove the lifecycle auto-pause: drop the `paused`-branch body (the `suspend()` + conditional `pause()`) and the `resumed`→`resume()` so the session is **not** paused/silenced when the app backgrounds. The breath audio loop, tick one-shots, and `BreathSessionStateMachine` keep running; on iOS this continued playback is what holds the audio session alive (note 138), on Android the FGS does (note 139).
- Keep the `WidgetsBindingObserver` registration (harmless; leave the empty/observer in place) unless `flutter analyze` flags it unused — then remove cleanly.
- The user-initiated pause button is untouched — only the *automatic* lifecycle pause is removed.

### Guards
- Depends on notes 138 (iOS) and 139 (Android) so the process actually survives; without them the engine still freezes on suspension (acceptable degradation, but the feature isn't delivered).
- Do **not** touch `BreathSessionStateMachine`, tick sources (`docs/breath/session/tick-sources.md`), or `BreathSoundCoordinator` internals.
- Heart-rate tick source keeps flowing only while the BCI Bluetooth link stays up in background — out of scope here.

### Verify
- Start a breath session with audio, lock the device: guidance audio/ticks continue; unlock after a minute and the orb is at the correct advanced phase (not frozen at lock time); biometric logs show no gap.

## Open Questions
- None — behavior change is a deletion gated on the keep-alive foundations.
