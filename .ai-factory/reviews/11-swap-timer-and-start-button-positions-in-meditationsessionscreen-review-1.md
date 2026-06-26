# Code Review: Swap timer and start button positions in `MeditationSessionScreen`

## Scope
Reviewed `git diff HEAD` and `git status`. The only code change is in
`packages/meditation_module/lib/src/MeditationSession/MeditationSessionScreen.dart`.
(The other staged files are plan/plan-review artifacts, not code.)

## Summary
The change is a pure positional swap of two existing widgets:
- The timer (`ValueListenableBuilder<int>` rendering `_formatDuration(seconds)`) moves into the center `Expanded → Center → Column`, directly under the pose image and the existing `SizedBox(height: 40)` spacer.
- The play/stop `ControlButton` (wrapped in `SizedBox(80×80)`) moves into the bottom `Padding(bottom: 40)`.

This matches the plan (Task 1) exactly.

## Correctness checks
- **Widgets preserved verbatim** — `ControlButton` icon/`onPressed`/`iconSize` logic, the `elapsedSeconds` `valueListenable` source, and the timer `Text` styling are all unchanged; only positions swapped.
- **No new symbols introduced** — `FontFeature`, `AppColors`, `ControlButton`, `_formatDuration`, and `elapsedSeconds` were all already referenced in this file before the change, so no imports are missing.
- **No state/lifecycle impact** — `ref.listen`, `status`, `poseId`, `isActive` and the `dispose` override are untouched. `isActive` is still in scope at the new button location (declared in `build`).
- **Spacer / padding intact** — `const SizedBox(height: 40)` between pose and timer remains; bottom `Padding(EdgeInsets.only(bottom: 40))` retained.
- **No runtime regressions** — no migrations, type changes, async ordering, or race conditions involved; this is layout-only.

## Findings
None.

REVIEW_PASS
