# BCI Calibration UX — Per-stage Instructions, Sounds, and AudioOneShot Warm-up Fix

**Date:** 2026-06-05
**Source:** conversation context

## Key Findings

- `BciCalibrationSection` had no instruction text at the start of calibration because `BciPairingService` emitted `calibration: null` until the first stage completed — fixed by seeding the field immediately on state entry.
- ExoPlayer underruns the AudioTrack on first play of a cold local asset >~35 KB (just_audio #941): only the minimum hardware buffer (~78 ms / 3464 frames) plays before the buffer drains. Fixed by a silent warm-up play inside `AudioOneShot.load()`.

## Details

### Files changed

| File | Change |
|------|--------|
| `packages/bci_module/lib/src/BciPairing/BciPairingService.dart` | Seed `calibration: BciCalibrationProgressDTO(stagesCompleted: 0, isComplete: false)` when transitioning to `calibrating` state |
| `packages/bci_module/lib/src/BciPairing/Views/BciCalibrationSection.dart` | Per-stage instruction text; `_stageChime` on stage change; `_completionCue` on completion; test scaffold removed |
| `packages/bci_module/assets/stage.wav` | Added from neiry_kit (stage-change chime) |
| `packages/bci_module/pubspec.yaml` | Declared `stage.wav` and `calibration_complete.wav` under `flutter.assets` |
| `packages/mind_l10n/lib/l10n/app_en.arb` + `app_ru.arb` | Added `bciPairingOpenEyes` key |
| `packages/mind_audio/lib/src/audio_one_shot.dart` | Silent warm-up in `load()`: play at volume 0 for 200 ms, stop, seek(0), set volume 1 |

### Per-stage instruction logic

`NfbCalibrator.calibrateIndividual()` runs 4 stages: 1 & 3 = close eyes, 2 & 4 = open eyes.
Active stage = `stagesCompleted + 1`. Odd → `bciPairingCloseEyes`; even → `bciPairingOpenEyes`.

### Sound triggers (in `ref.listen`)

- Stage chime (`stage.wav`): fires when `inProgress && prevStages != nextStages`.
- Completion cue (`calibration_complete.wav`): fires when `wasComplete == false && isComplete == true`.
- Both loaded in `initState` with a 200 ms silent warm-up inside `AudioOneShot.load()`.

### AudioOneShot warm-up

ExoPlayer reads the APK asset progressively; on first play it fills only the minimum AudioTrack hardware buffer before the buffer drains (just_audio #941, #887). The warm-up runs the asset through ExoPlayer once silently, populating the OS page cache. All subsequent `play()` calls deliver the full audio.

```dart
Future<void> load(AudioTrack track) async {
  _loading = true;
  try {
    await _player.setAudioSource(AudioSource.asset(track.assetPath));
    await _player.setVolume(0);
    unawaited(_player.play());
    await Future.delayed(const Duration(milliseconds: 200));
    await _player.stop();
    await _player.seek(Duration.zero);
    await _player.setVolume(1);
  } finally {
    _loading = false;
  }
}
```
