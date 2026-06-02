# BCI Data Screen — Horizontal Metric Bars

**Date:** 2026-06-02
**Source:** conversation context

## Key Findings

- `BciMetricBar` is currently a vertical column (36×120 px, grows upward). Replace with a horizontal row cell: label + value on one line, animated-width bar on the next line.
- Bar height shrinks from 36 px to 24 px (1.5× narrower). Bar width animates from 0 to full available width via `LayoutBuilder`.
- The group layout changes from a horizontal `Row` of bars to a vertical `Column` (or `ListView`) of cells, with more spacing between cells than between the label line and the bar.

## Details

### New BciMetricBar layout

**File:** `packages/bci_module/lib/src/BciData/BciMetricBar.dart`

```dart
class BciMetricBar extends StatelessWidget {
  final double? value;   // 0.0–1.0, null = no data
  final Color color;
  final String label;

  const BciMetricBar({required this.color, required this.label, this.value, super.key});

  @override
  Widget build(BuildContext context) {
    final clamped = (value ?? 0.0).clamp(0.0, 1.0);
    final valueText = value != null ? '${(clamped * 100).round()}' : '--';

    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth = constraints.maxWidth;
      return AnimatedOpacity(
        opacity: value != null ? 1.0 : 0.3,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                const Spacer(),
                Text(
                  valueText,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.right,
                ),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              height: 24,
              width: maxWidth * clamped,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      );
    });
  }
}
```

### Group layout in BciDataScreen

**File:** `packages/bci_module/lib/src/BciData/BciDataScreen.dart`

Replace horizontal `Row` groups with vertical spacing:

```dart
// Instead of: Row(children: bars.map(...).toList())
// Use:
Column(
  children: bars.mapIndexed((i, bar) => [
    bar,
    if (i < bars.length - 1) const SizedBox(height: 12), // inter-cell gap
  ]).expand((e) => e).toList(),
)
```

Inter-cell gap (12 px) is larger than the label-to-bar gap (4 px) — matches the requested visual hierarchy.

If the total content height exceeds the screen, wrap the body in a `SingleChildScrollView`. Given 10 metrics (5 emotions + 5 EEG) plus heart rate, a `ListView` for the whole screen body may be appropriate.

### Value display

Show `(value * 100).round()` as an integer string (0–100). No percent sign — the user requested just numbers. When `value` is null, show `'--'`.

### What does NOT change

- Colors of each metric (emotion and EEG palettes) — unchanged.
- `AnimatedOpacity` dim behavior when value is null — unchanged.
- `AnimatedContainer` 400 ms / `easeOut` timing — unchanged.
- The `value` normalization in `BciDataViewModel` — unchanged.
