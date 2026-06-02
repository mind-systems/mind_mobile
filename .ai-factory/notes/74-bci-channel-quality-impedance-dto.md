# BCI Channel Quality DTO — Add `impedanceOhm` Field

**Date:** 2026-06-02
**Source:** conversation context

## Key Findings

- `BciChannelQualityDTO` exposes only `channelName` and `quality`; the domain `BciChannelQuality` has `impedanceOhm` but the mapper silently drops it.
- Two files change: the DTO (add nullable field) and the mapper (pass value through). No other files touch.
- Field is nullable — hardware may not report impedance before calibration starts.

## Details

### BciChannelQualityDTO

**File:** `packages/bci_module/lib/src/BciPairing/Models/BciChannelQualityDTO.dart`

```dart
@immutable
class BciChannelQualityDTO {
  final String channelName;
  final BciSignalQuality quality;
  final int? impedanceOhm;   // NEW — null until hardware reports a value

  const BciChannelQualityDTO({
    required this.channelName,
    required this.quality,
    this.impedanceOhm,
  });
}
```

### BciChannelQualityMapping

**File:** `lib/BciModule/BciChannelQualityMapping.dart`

The extracted mapper (created in Phase 26 task "Extract duplicated BCI channel-quality mapper") maps `BciChannelQuality` → `BciChannelQualityDTO`. Add `impedanceOhm`:

```dart
BciChannelQualityDTO mapChannel(BciChannelQuality source) => BciChannelQualityDTO(
  channelName: source.channelName,
  quality: _mapLevel(source.signalLevel),
  impedanceOhm: source.impedanceOhm,   // NEW
);
```

`BciChannelQuality.impedanceOhm` is `int` in the domain model (`lib/Bci/Models/BciChannelQuality.dart`); it maps 1:1 to the nullable DTO field — no conversion needed.

### Verify

`BciPairingService` produces `BciChannelQualityDTO` objects via the mapper. After this task, each DTO carries the impedance value when available. `BciImpedanceSection` does not yet display it — that is the next task.
