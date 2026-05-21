# BciPairingScreen — Implementation Spec

**Date:** 2026-05-21
**Used by:** ROADMAP Phase 17, milestone 10

## Role

Single screen that covers the full device lifecycle: discovery, connect, impedance check, and calibration. Uses `just_audio` for the calibration-complete sound. Lives in `packages/bci_module/`.

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
- **Title:** "Connect Headband" (l10n key: `bcsPairingTitle`). Centered.
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

```dart
// In _BciPairingScreenState.initState():
_player = AudioPlayer();
await _player.setAsset('packages/bci_module/assets/calibration_complete.wav');

// In didUpdateWidget / after state.calibration?.isComplete transitions to true:
unawaited(_player.seek(Duration.zero).then((_) => _player.play()));

// In dispose():
_player.dispose();
```

**Asset:** copy `calibration_complete.wav` (or `.ogg`, whichever exists) from `neiry_kit/example/assets/` into `packages/bci_module/assets/`. Declare in `packages/bci_module/pubspec.yaml`:
```yaml
flutter:
  assets:
    - packages/bci_module/assets/
```

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
- `bcsPairingTitle`: "Connect Headband"
- `bcsPairingKnownDevice`: "Previously paired"
- `bcsPairingSignalQuality`: "Signal quality"
- `bcsPairingAdjustHeadband`: "Adjust headband for good contact on all channels."
- `bcsPairingCalibration`: "Calibration"
- `bcsPairingStartCalibration`: "Start calibration"
- `bcsPairingCloseEyes`: "Close your eyes and relax."
- `bcsPairingCalibrationComplete`: "Calibration complete"
- `bcsPairingDisconnect`: "Disconnect"
- `bcsPairingDisconnectConfirm`: "Disconnect device?"
