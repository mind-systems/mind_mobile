# Plan: Show impedance value under channel label in BciImpedanceSection

## Context
Display the raw impedance value as a whole number beneath each channel's name in the BCI pairing signal-quality section, in muted text, with no value shown when impedance is null.

> Note: `BciChannelQualityDTO.impedanceOhm` is a `double?` (kept `double?` in phase 08 to avoid lossy truncation). It is rendered as a whole number for display only — see Task 1 for the exact formatting.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Display impedance value

- [x] **Task 1: Add impedance value Text under channel name**
  Files: `packages/bci_module/lib/src/BciPairing/Views/BciImpedanceSection.dart`
  In the `channels.map((ch) => Column(...))` per-channel column (around lines 45-62), add a new `Text` directly below the existing `Text(ch.channelName, ...)` (line 57-60). The new widget:
  ```dart
  Text(
    ch.impedanceOhm?.toStringAsFixed(0) ?? '',
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).textTheme.labelSmall?.color?.withValues(alpha: 0.5),
        ),
  ),
  ```
  Notes:
  - No units — number only.
  - Use `.toStringAsFixed(0)` (not `.toString()`): `impedanceOhm` is a `double?`, so `.toString()` would render decimals (`1000.0`, `523.7`). `.toStringAsFixed(0)` rounds to a whole number for display (`1000`, `524`) matching the intended integer presentation, without mutating the underlying `double`.
  - Empty string when `impedanceOhm` is null (renders zero height, no extra `SizedBox`).
  - The placeholder columns (the `List.generate(placeholderCount, ...)` block, lines 63-80) stay unchanged — they have no DTO.
  - `BciChannelQualityDTO.impedanceOhm` already exists; no model changes needed.
  - Use `.withValues(alpha:)` (project already uses this API), not the deprecated `.withOpacity()`.

## Notes / Known limitations
- **Vertical alignment edge case (accepted, no action):** the value `Text` adds a second text line only to channels with a non-null impedance. Placeholder columns (`const Text(' ')`) and real channels with a null impedance stay one line tall. Since the enclosing `Row` uses the default `crossAxisAlignment: center`, a mix of one-line and two-line columns would center-align and slightly misalign the circles. In practice channels arrive as a full set of four with values, so this is a minor transient visual case, not a correctness bug. Reserving a fixed-height slot for the value line is intentionally **not** done here to keep this a single-widget, one-file change per the spec; revisit only if pixel-perfect alignment is later required.
