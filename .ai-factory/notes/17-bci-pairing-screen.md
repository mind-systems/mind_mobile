# BciPairingScreen — Implementation Spec

**Date:** 2026-05-21
**Used by:** ROADMAP Phase 17, milestone 10

## Role

Single screen that covers the full device lifecycle: discovery, connect, impedance check, and calibration. Uses `AudioOneShot` + `AssetAudioCatalog` from `packages/mind_audio` for the calibration-complete sound — `bci_module` does not import `just_audio` directly. Lives in `packages/bci_module/`.

```dart
static const path = '/bci_pairing';
```

## Screen structure

```
┌─────────────────────────────────────────┐
│ [X] Connect Headband      🔋 82%  [Disconnect] │  ← top bar
├─────────────────────────────────────────┤
│ ── Nearby devices ──────────────────────│
│  [•] Neiry Headband A3F2   [known]      │
│  [ ] Neiry Headband 0011                │
│   …scanning…                           │
├─────────────────────────────────────────┤
│ ── Signal quality ──────────────────────│  ← greyed until connected
│  O  O  O  O   (per-channel circles)    │
│  Adjust headband for good contact       │
├─────────────────────────────────────────┤
│ ── Calibration ─────────────────────────│  ← greyed until connected
│ [Start calibration]                     │
│  Stage: ● ● ○ ○                        │  ← when calibrating
│  Close your eyes and relax              │  ← when calibrating
└─────────────────────────────────────────┘
```

## Top bar

- **Close button** (top-left or top-right `X`): calls `vm.onClose()`. Always visible.
- **Title:** "Connect Headband" (l10n key: `bciPairingTitle`). Centered.
- **Battery indicator:** `"🔋 ${state.batteryPercent}%"` — only visible when `state.batteryPercent != null`.
- **Disconnect button:** Visible only when `state.stage != BciPairingStage.discovery`. Red text. On tap → show confirmation `AlertDialog`: "Disconnect device?" [Cancel] [Disconnect]. On confirm → `vm.onDisconnect()`. This returns stage to `discovery`.

## Discovery section (always visible)

- Section header: "Nearby devices".
- `ListView` of `BciScannedDeviceDTO` items:
  - Device name + serial (truncated).
  - `isKnown == true` → show small badge or secondary text "(previously paired)".
  - While `state.isConnecting` and this serial is the target → show `CircularProgressIndicator` instead of leading icon.
  - On tap → `vm.onDeviceTap(device.serial)`.
- While `state.isScanning && state.devices.isEmpty` → shimmer or `LinearProgressIndicator` at top.
- While `state.isScanning && state.devices.isNotEmpty` → `LinearProgressIndicator` at top + device list.

## Impedance section

- Wrapped in `IgnorePointer(ignoring: state.stage == BciPairingStage.discovery)` + `AnimatedOpacity` (0.38 when disabled).
- Section header: "Signal quality".
- Row of circular indicators, one per `state.channels`. Colour: `BciSignalQuality.good` → green, `fair` → amber, `poor` → red.
- Channel name label below each circle.
- Caption: "Adjust headband for good contact on all channels."

## Calibration section

- Same `IgnorePointer` / `AnimatedOpacity` treatment as impedance.
- **Start calibration button** (full-width `ElevatedButton`): enabled only when `state.stage == BciPairingStage.impedance`. On tap → `vm.onStartCalibration()`.
- **Stage progress** (visible when `state.calibration != null`):
  - Row of 4 dots: filled circle for `i < stagesCompleted`, outlined for the rest.
  - Stage instruction text below: "Close your eyes and relax."
- **Completion state** (`state.calibration?.isComplete == true`): show green checkmark + "Calibration complete". Play audio cue (see below).
- When `state.stage == BciPairingStage.ready` and the checkmark is shown, the Disconnect button becomes the primary call-to-action to leave if the user wants to switch devices; otherwise they just close with X.

## Calibration completion sound

Use `AudioOneShot` from `mind_audio` — do not reference `AudioPlayer` or `AudioSource` directly.

```dart
// State fields:
late final AudioOneShot _completionCue;
bool _cueReady = false;

// initState:
_completionCue = AudioOneShot();
unawaited(_loadCue());   // must be unawaited(...), not bare call — unawaited_futures lint

Future<void> _loadCue() async {
  final source = await AssetAudioCatalog().sourceFor(
    const AudioTrack('packages/bci_module/assets/calibration_complete.wav'),
  );
  await _completionCue.load(source);
  if (mounted) setState(() => _cueReady = true);
}

// ref.listen for the false→true transition (in build):
ref.listen<BciPairingState>(bciPairingViewModelProvider, (prev, next) {
  if (_cueReady &&
      prev != null &&                            // guard: skip mount-time fire
      prev.calibration?.isComplete != true &&
      next.calibration?.isComplete == true) {
    _completionCue.play();
  }
});

// dispose():
_completionCue.dispose();
```

**Asset:** copy `calibration_complete.wav` (or `.ogg`, whichever exists) from `neiry_kit/example/assets/` into `packages/bci_module/assets/`. Declare in `packages/bci_module/pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/calibration_complete.wav
```

Note: in Dart code the asset is referenced as `'packages/bci_module/assets/calibration_complete.wav'` (consumer-side prefix) — this is correct. Only the pubspec declaration uses the package-root-relative form above.

Check `neiry_kit/example/` for the actual filename before copying.

## State transitions visible in UI

| `BciPairingStage` | Impedance section | Calibration section |
|---|---|---|
| `discovery` | greyed out, non-interactive | greyed out, non-interactive |
| `impedance` | active, channels coloured | start button enabled |
| `calibrating` | active | stage dots + instruction visible |
| `ready` | active | green checkmark |

## l10n keys needed

Add to `packages/mind_l10n/lib/l10n/app_en.arb` (and `app_ru.arb`):
- `bciPairingTitle`: "Connect Headband"
- `bciPairingNearbyDevices`: "Nearby devices"
- `bciPairingKnownDevice`: "Previously paired"
- `bciPairingSignalQuality`: "Signal quality"
- `bciPairingAdjustHeadband`: "Adjust headband for good contact on all channels."
- `bciPairingCalibration`: "Calibration"
- `bciPairingStartCalibration`: "Start calibration"
- `bciPairingCloseEyes`: "Close your eyes and relax."
- `bciPairingCalibrationComplete`: "Calibration complete"
- `bciPairingDisconnect`: "Disconnect"
- `bciPairingDisconnectConfirm`: "Disconnect device?"
