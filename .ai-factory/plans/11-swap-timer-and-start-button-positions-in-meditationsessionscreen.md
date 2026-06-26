# Plan: Swap timer and start button positions in `MeditationSessionScreen`

## Context
Reorder the meditation session layout so the elapsed-time timer sits directly under the pose image in the center section, and the play/stop control button moves to the very bottom of the screen.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Layout swap

- [x] **Task 1: Move timer into center section and button to bottom**
  Files: `packages/meditation_module/lib/src/MeditationSession/MeditationSessionScreen.dart`
  In the `build` method's `Column`:
  - Inside the `Expanded` → `Center` → `Column`, replace the `ControlButton` block (the `SizedBox(width: 80, height: 80, child: ControlButton(...))`, currently after the pose `Image.asset` and `SizedBox(height: 40)`) with the timer widget — the `ValueListenableBuilder<int>` that renders `_formatDuration(seconds)` as a `Text` with `Theme.of(context).textTheme.displayMedium?.copyWith(color: AppColors.warmAccentDark, fontFeatures: [const FontFeature.tabularFigures()])`. Keep the `const SizedBox(height: 40)` spacer between the pose image and the timer.
  - Replace the bottom `Padding(padding: const EdgeInsets.only(bottom: 40), child: ValueListenableBuilder...)` (the timer) with the same `Padding(padding: const EdgeInsets.only(bottom: 40), ...)` now wrapping the `SizedBox(width: 80, height: 80, child: ControlButton(...))` (the play/stop button).
  - Preserve all existing widget configuration verbatim: the `ControlButton` icon/`onPressed`/`iconSize` logic driven by `isActive`, the `elapsedSeconds` `valueListenable` source, and the timer `Text` styling. Only the positions of the two widgets change.

## Notes
- `isActive`, `status`, `poseId`, and the `ref.listen` block at the top of `build` remain unchanged.
- Single self-contained edit → one commit at the end: "Swap timer and start button positions in meditation session screen".
