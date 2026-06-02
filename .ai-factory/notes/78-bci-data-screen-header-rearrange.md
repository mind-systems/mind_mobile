# BCI Data Screen — Header Rearrangement (Battery + Dots Together Left)

**Date:** 2026-06-02
**Source:** conversation context

## Key Findings

- Channel quality dots move from the right side to next to the battery indicator on the left.
- Dots get a rounded background pill; height ~22 px (slightly larger than the 16 px battery icon); color matches `SessionBottomBar` background on the breath screen (`Theme.of(context).cardColor`).
- One file changes: `BciDataScreen.dart` where `BciDataHeader` is defined.

## Details

### Current layout

```
[battery icon + %]  [Spacer]  [dot dot dot dot]
```

### New layout

```
[battery icon + %]  [8px gap]  [╔══dots══╗]  [Spacer]
                                 rounded pill
                                 bg: cardColor
                                 height: 22px
                                 padding: 6h
```

### Code change in `BciDataHeader`

**File:** `packages/bci_module/lib/src/BciData/BciDataScreen.dart`

```dart
// BEFORE: battery row on left, dots row on right separated by Spacer
Row(
  children: [
    _BatteryRow(state: state),
    const Spacer(),
    _ChannelDotsRow(state: state),
  ],
)

// AFTER: both on left, dots in a pill container
Row(
  children: [
    _BatteryRow(state: state),
    const SizedBox(width: 8),
    Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _buildDots(state, context),
      ),
    ),
    const Spacer(),
  ],
)
```

`_buildDots` extracts the existing dot-building logic (real colored dots when connected + channels, placeholder grey dots when disconnected). Internal dot size (8×8 px) and spacing (4 px) stay unchanged.

### Background color rationale

`Theme.of(context).cardColor` is the same token used by `SessionBottomBar` in `packages/breath_module` — both live on a dark scaffold background, so the pill naturally reads as an elevated surface. No new theme token needed.

### Verify

Open BCI data screen:
- Battery indicator and channel dots are grouped on the left side.
- Dots appear inside a visible rounded pill.
- When disconnected, all 4 placeholder dots are visible inside the pill at 0.3 opacity.
- When connected with signal data, dots reflect signal quality colors inside the pill.
