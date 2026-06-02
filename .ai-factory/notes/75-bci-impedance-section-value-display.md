# BCI Impedance Section — Show Numeric Impedance Value

**Date:** 2026-06-02
**Source:** conversation context

## Key Findings

- One file changes: `packages/bci_module/lib/src/BciPairing/Views/BciImpedanceSection.dart`.
- Add a `Text` below the channel name showing `ch.impedanceOhm?.toString() ?? ''` — no units, just the number. Empty string when null (no visible element).
- Depends on note 74 (`impedanceOhm` field on `BciChannelQualityDTO`).

## Details

### Current per-channel column

```dart
Column(
  children: [
    Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: _qualityColor(ch.quality))),
    const SizedBox(height: 4),
    Text(ch.channelName, style: theme.textTheme.labelSmall),
  ],
)
```

### After change

```dart
Column(
  children: [
    Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: _qualityColor(ch.quality))),
    const SizedBox(height: 4),
    Text(ch.channelName, style: theme.textTheme.labelSmall),
    Text(
      ch.impedanceOhm?.toString() ?? '',
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.textTheme.labelSmall?.color?.withValues(alpha: 0.5),
      ),
    ),
  ],
)
```

Same muted-alpha pattern used for section headers and dimmed labels throughout the BCI module. No extra `SizedBox` needed — empty string produces zero height.

The placeholder circles (rendered when `state.channels` has fewer than 4 items) keep their current structure unchanged — they have no DTO, so no impedance text to show.

### Verify

Connect a Neiry device and open the pairing screen. After reaching the impedance stage, each channel circle should show its label (T3, T4, O1, O2) with the raw integer value beneath it in muted text. Before hardware reports impedance, the space under the label is empty.
