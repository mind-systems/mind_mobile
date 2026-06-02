# BCI Calibration — Clock Tick Sound

**Date:** 2026-06-02
**Source:** conversation context

## Key Findings

- `BciCalibrationSection` already has `initState` + `ref.listen` for the completion cue sound — the tick follows the same pattern.
- `mind_audio` is already a `bci_module` dependency; `AudioOneShot` is available without any pubspec change.
- Asset `assets/audio/tick_clock.ogg` is declared in the root app's `pubspec.yaml` (`assets/audio/`) and accessible from the package.
- Tick plays every 1 second while `calibration != null && !calibration.isComplete`; stops immediately on completion, failure, or disconnect.

## Details

### File

`packages/bci_module/lib/src/BciPairing/Views/BciCalibrationSection.dart`

`BciCalibrationSection` is already a `ConsumerStatefulWidget`. Changes are additive.

### New fields

```dart
AudioOneShot? _tick;
Timer? _tickTimer;
```

### initState

After the existing `_loadCue()` call, add:

```dart
_tick = AudioOneShot();
unawaited(_tick!.load(AudioSource.asset('assets/audio/tick_clock.ogg')));
```

Pre-buffers the asset so each `play()` is instant.

### ref.listen — tick start/stop

Add inside `build()`, alongside the existing completion-cue listener:

```dart
ref.listen<BciCalibrationProgressDTO?>(
  bciPairingViewModelProvider.select((s) => s.calibration),
  (prev, next) {
    final inProgress = next != null && !next.isComplete;
    if (inProgress && _tickTimer == null) {
      _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _tick?.play();
      });
    } else if (!inProgress) {
      _tickTimer?.cancel();
      _tickTimer = null;
    }
  },
);
```

Guard `_tickTimer == null` before starting prevents a double-timer if the listener fires while a timer is already running.

### dispose

```dart
@override
void dispose() {
  _tickTimer?.cancel();
  _tick?.dispose();
  super.dispose();
}
```

### Behaviour

| State | Tick |
|---|---|
| No calibration started | Silent |
| Calibration in progress (stages 0–4) | Ticking every 1 s |
| Calibration complete | Stops immediately |
| Calibration failed / disconnect | Stops immediately |

### Verify

Start calibration with eyes closed — a clock tick should be audible each second. After completion (or the `calibration_complete.wav` cue fires), ticking stops. Re-opening the screen and starting again plays the tick again from the first second.
