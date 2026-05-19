# BreathSessionScreen Adaptive Layout Scale Factor

**Date:** 2026-05-19
**Source:** conversation context

## Key Findings

- The overflow on small screens is a **16:9 formfactor problem**, not a device-specific bug. Old phones (Mi A1, old Nexus, old Pixels) have ~640dp height vs modern 18:9/20:9 phones (800dp+).
- A single `scale` coefficient (derived from available height) is applied to every dimension — shape, paddings, button, timeline rows, font sizes, bottom bar icons. Everything shrinks proportionally.
- Font sizes in `_TimelineItem` are hardcoded; they must be derived from the scaled `itemHeight` rather than a separate param.
- The outer `LayoutBuilder` in `BreathSessionScreen.build()` is dead code — remove it.

## Details

### Root Cause

| Formfactor | Aspect ratio | Available height (dp) | Fits at scale 1.0? |
|---|---|---|---|
| Mi A1, old Nexus/Pixel | 16:9 | ~524dp | No — overflow ~128dp |
| Modern phones (Galaxy A70, Pixel 5+) | 18:9 – 20:9 | 800dp+ | Yes |

### Content Budget at Scale 1.0

| Element | Height |
|---|---|
| Shape SizedBox + vertical padding (20×2) | 252 + 40 = **292dp** |
| Timeline (`48 × 4.5`) | **216dp** |
| Button (80) + padding all:32 (32×2) | **144dp** |
| **Total = kIdealContentHeight** | **652dp** |

### Scale Factor Formula

```dart
const kIdealContentHeight = 652.0;

// Inside LayoutBuilder within Expanded:
final scale = (constraints.maxHeight / kIdealContentHeight).clamp(0.5, 1.0);
```

- Mi A1: `524 / 652 ≈ 0.80` → everything shrinks ~20%
- Modern phone (800dp+): `800 / 652 > 1.0` → clamped to `1.0`, unchanged

### What Scales

Every dimension multiplied by `scale`:

| Element | Formula | Scale 1.0 | Scale 0.80 |
|---|---|---|---|
| `shapeDimension` | `screenWidth * 0.7 * scale` | 252dp | 202dp |
| Shape vertical padding | `20 * scale` | 20dp | 16dp |
| `itemHeight` (timeline row) | `48.0 * scale` | 48dp | 38dp |
| `timelineHeight` | `itemHeight * 4.5` | 216dp | 173dp |
| Active font size | `itemHeight * 0.458` | 22dp | 17.4dp |
| Inactive font size | `itemHeight * 0.333` | 16dp | 12.7dp |
| Button size | `80.0 * scale` | 80dp | 64dp |
| Button padding (all) | `32.0 * scale` | 32dp | 26dp |
| `SessionBottomBar` icon size | `28.0 * scale` | 28dp | 22dp |
| **Total content** | | **652dp** | **521dp** ✓ |

### Font Sizes in Timeline

`_TimelineItem` (private class in `BreathTimelineWidget.dart`, line ~168) has hardcoded:
```dart
fontSize: isActive ? 22 : 16
```
Fix: pass `itemHeight` as a new param to `_TimelineItem` and derive font sizes from it:
```dart
fontSize: isActive ? itemHeight * 0.458 : itemHeight * 0.333
```
This ties font size to row height automatically — no separate scale param needed.

### Architecture: `BreathSessionLayout` data class

All scale math lives in one small file — `BreathSessionLayout.dart` — next to the screen. `BreathSessionScreen.build()` never sees `scale` directly.

```dart
class BreathSessionLayout {
  final double shapeDimension;
  final double shapePadding;
  final double itemHeight;
  final double buttonSize;
  final double buttonPadding;
  final double iconSize;

  static const double _kShapeWidthRatio = 0.7;
  static const double _kShapePadding    = 20.0;
  static const double _kTimelineItems   = 4.5;
  static const double _kItemHeight      = 48.0;
  static const double _kButtonSize      = 80.0;
  static const double _kButtonPadding   = 32.0;
  static const double _kIconSize        = 28.0;
  static const double _kMinScale        = 0.5;

  const BreathSessionLayout._({...});

  static double _idealHeight(double screenWidth) =>
      (screenWidth * _kShapeWidthRatio + _kShapePadding * 2) +
      (_kItemHeight * _kTimelineItems) +
      (_kButtonSize + _kButtonPadding * 2);

  factory BreathSessionLayout.compute(double screenWidth, double availableHeight) {
    final scale = (availableHeight / _idealHeight(screenWidth)).clamp(_kMinScale, 1.0);
    return BreathSessionLayout._(
      shapeDimension: screenWidth * _kShapeWidthRatio * scale,
      shapePadding:   _kShapePadding  * scale,
      itemHeight:     _kItemHeight    * scale,
      buttonSize:     _kButtonSize    * scale,
      buttonPadding:  _kButtonPadding * scale,
      iconSize:       _kIconSize      * scale,
    );
  }
}
```

Key property: `_idealHeight` is derived from the same constants used to compute each field — rounding errors or edits to one constant automatically propagate to the reference height. No manual `652.0` to keep in sync.

Usage in `BreathSessionScreen` (inside `LayoutBuilder` within `Expanded`):
```dart
final layout = BreathSessionLayout.compute(screenWidth, constraints.maxHeight);
```

### Implementation Locations

| Change | File |
|---|---|
| New file — all scale math | `packages/breath_module/lib/src/BreathSession/BreathSessionLayout.dart` |
| Remove outer `LayoutBuilder`, add inner one inside `Expanded`, use `layout.*` | `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart` |
| Add `itemHeight` param to `_TimelineItem`, derive font: `itemHeight * 0.458 / 0.333` | `packages/breath_module/lib/src/BreathSession/Views/BreathTimelineWidget.dart` |
| Add `iconSize` param (default 28.0), replace hardcoded `iconSize: 28` | `packages/breath_module/lib/src/BreathSession/Views/SessionBottomBar.dart` |
