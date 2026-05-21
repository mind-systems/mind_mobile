# Review: Eliminate phase-change render contention on `BreathSessionScreen` (iteration 2)

## Scope

Re-reviewed the staged changes against `.ai-factory/plans/31-eliminate-phase-change-render-contention-on-breathsessionscreen.md`, focusing on the must-fix and nit raised in iteration 1.

Staged files now (`git status`):
- `.ai-factory/ROADMAP.md` (modified)
- `.ai-factory/notes/12-phase-change-rebuild-contention.md` (new)
- `.ai-factory/plan-reviews/...-plan-review-1.md` (new)
- `.ai-factory/plans/...-plan.md` (new)
- `.ai-factory/reviews/...-review-1.md` (new)
- `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart` (modified)
- `packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart` (modified)

## Verification of prior findings

- **F1 (must-fix, iteration 1) — `some.txt` unstaged and removed**: confirmed. `git status` no longer lists `some.txt`; the file is absent from the working tree. ✓
- **F3 (nit, iteration 1) — gratuitous `prev`/`isStructural` locals in `BreathViewModel.set state`**: confirmed reverted. `BreathSessionViewModel.dart` is no longer in `git diff HEAD --stat`; `git show HEAD:.../BreathSessionViewModel.dart` shows the one-line `if (!value.equalsIgnoringTickFields(super.state)) { super.state = value; }` form, matching the pre-probe baseline. ✓
- **F2 (info, iteration 1) — three files in Task 7 had no diff and no probes in HEAD**: unchanged. `grep -r 'BREATH-PROBE' packages/breath_module` returns no matches; the cleanup acceptance criterion holds.

## Re-verification of correctness findings F4–F9

Inspected the iteration-2 diff for `BreathSessionScreen.dart` and `BreathSessionState.dart` — identical to the code reviewed and verified correct in iteration 1:

- `Consumer` rebuild / `GlobalKey<BreathTimelineWidgetState>` reuse — correct.
- Closure capture of `viewModel` and `layout` inside Consumers — correct.
- Dart 3 record-equality short-circuiting for `(timelineSteps, activeStepId, status)` — correct, leans on the documented `identical(...)` invariant for `timelineSteps`.
- `package:flutter/scheduler.dart` import removed (no remaining `FrameTiming` reference) — correct.
- `ref.listenManual<BreathSessionState>` for `_scrollToActive`, `didChangeAppLifecycleState`, and the `postFrameCallback` coordinator init — all preserved.
- `resetReason` removal from `equalsIgnoringTickFields` does not regress `BreathAnimationCoordinator` / `OrbAnimationCoordinator` consumers (both use the raw `_stateController` stream, which still fires on every `set state`). Doc comment updated to classify `resetReason` as a transient field. Correct.

## Findings (new)

None.

REVIEW_PASS
