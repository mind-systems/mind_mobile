# Plan: Horizontal metric bars on BCI data screen

## Context
Redesign `BciMetricBar` from a vertical 36×120 px upward-growing column into a horizontal cell (label + value on one line, animated-width bar below), and switch the emotion/EEG bar groups on `BciDataScreen` from horizontal `Row` layout to vertical `Column` layout. Spec: `.ai-factory/notes/77-bci-data-screen-horizontal-bars.md`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Widget redesign

- [x] **Task 1: Rewrite `BciMetricBar` as a horizontal cell**
  Files: `packages/bci_module/lib/src/BciData/Views/BciMetricBar.dart`
  Replace the current vertical-column implementation with a horizontal layout per the spec:
  - Wrap the whole widget in `LayoutBuilder` to read `constraints.maxWidth` (the bar's full available width).
  - Outer `AnimatedOpacity` (opacity `1.0` when `value != null`, else `0.3`; `400 ms`, `Curves.easeOut`) — preserves current dim behavior.
  - Child is a `Column(crossAxisAlignment: CrossAxisAlignment.start)` containing:
    1. `Row(children: [Text(label, style: textTheme.bodyMedium), Spacer(), Text(valueText, style: textTheme.bodySmall, textAlign: TextAlign.right)])`.
    2. `const SizedBox(height: 4)` — label-to-bar gap.
    3. `AnimatedContainer(duration: 400 ms, curve: Curves.easeOut, height: 24, width: maxWidth * clamped, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)))`.
  - Value/clamp logic: `final clamped = (value ?? 0.0).clamp(0.0, 1.0);` and `final valueText = value != null ? '${(clamped * 100).round()}' : '--';` (integer 0–100, no percent sign; `'--'` when null).
  - Remove the obsolete `_barWidth` / `_maxBarHeight` constants and the `topLeft`/`topRight`-only border radius.
  - Keep the constructor signature (`value`, `color`, `label`); the spec makes `value` optional but the screen always passes it, so keeping it `required` is acceptable — match the spec's optional `value` only if it reads cleaner. Do not change colors or animation timing.

### Phase 2: Screen layout

- [x] **Task 2: Switch emotion & EEG bar groups to vertical columns** (depends on Task 1)
  Files: `packages/bci_module/lib/src/BciData/BciDataScreen.dart`
  For both the "Emotional states" section (5 `BciMetricBar`s) and the "EEG bands" section (5 `BciMetricBar`s):
  - Replace the inner `Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [...])` with a `Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...])`.
  - Insert `const SizedBox(height: 12)` between adjacent cells (inter-cell gap — larger than the 4 px in-cell label-to-bar gap). Do not add a trailing spacer after the last cell.
  - The surrounding `Padding(horizontal: 16)` and `BciSectionHeader` stay as-is. The horizontal cells now fill the available width so `LayoutBuilder` in `BciMetricBar` measures the full padded row width.
  - The body is already wrapped in `SingleChildScrollView`, so the overflow requirement from the spec is already satisfied — no additional scroll wrapper needed. Leave the heart-rate row and section spacing (`SizedBox(height: 24)`) unchanged.

## Notes
- No changes to `BciDataViewModel` value normalization, the metric colors, or animation durations/curves.
- 2 tasks total — single commit at the end (no commit checkpoints needed). Suggested message: "Redesign BCI metric bars as horizontal cells".
