# Review: Eliminate phase-change render contention on `BreathSessionScreen` (iteration 1)

## Scope

Reviewed the staged changes against `.ai-factory/plans/31-eliminate-phase-change-render-contention-on-breathsessionscreen.md`:

- `packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart`
- `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`
- `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
- supporting changes / staged untracked files (`.ai-factory/...`, `some.txt`)

Behavioral verification: walked the full `BreathSessionScreen.dart` post-edit, traced every captured closure variable (`viewModel`, `layout`, `_motionEngine`, `_shapeShifter`, `_orbCoordinator`, `_scrollController`, `_timelineKey`), and matched each `.select(...)` tuple against the consuming widget. Walked `BreathSessionViewModel.set state` to confirm dual-channel publication semantics are preserved.

## Findings

### F1 — `some.txt` is staged for commit (should NOT be committed)

A 701-line untracked file `some.txt` is in `git status` as "new file" alongside the real plan changes:

```
new file:   some.txt
```

Its contents are a captured `flutter run` console transcript including dependency resolution noise and the `[BREATH-PROBE]` log lines that the plan was designed to remove from the source. Committing this file would:

1. Re-introduce the `[BREATH-PROBE]` string into the repository — defeating the cleanup intent of Task 7 / Phase 3 (after which `grep -r 'BREATH-PROBE' packages/breath_module` returns zero matches, but `grep` over the whole repo would still hit `some.txt` with hundreds of matches).
2. Add ~30 KB of throwaway log output to history.
3. Violate the project rule that uncommitted/unfamiliar files should be investigated rather than blindly staged.

**Action:** unstage and delete `some.txt` (`git rm --cached some.txt && rm some.txt`), or move it to a gitignored scratch location, before committing. The plan's commit plan (Commits 1–3) does not include this file and should not include it.

### F2 — Plan Task 7 lists three files that have no diff against HEAD; verify the probes were never on this branch (or already removed)

Plan Task 7 instructs removing `debugPrint('[BREATH-PROBE] ...')` from:
- `packages/breath_module/lib/src/BreathSession/Views/BreathTimelineWidget.dart`
- `packages/breath_module/lib/src/BreathSession/Views/BreathShapeWidget.dart`
- `packages/breath_module/lib/src/BreathSession/Animation/BreathAnimationCoordinator.dart`

Verification:
- `git diff HEAD` for these three files: empty.
- `git show HEAD:<file> | grep 'BREATH-PROBE\|debugPrint'` for each: no matches.
- `grep -r 'BREATH-PROBE' packages/breath_module`: no matches.

Interpretation: the probes that the source note (`.ai-factory/notes/12-phase-change-rebuild-contention.md`) attributes to these three files were not present in `HEAD` and are not present in the working tree. Either (a) they were removed in an earlier commit before this branch, or (b) the note over-reported. Either way the acceptance criterion of Task 7 (zero `BREATH-PROBE` matches under `packages/breath_module`) is satisfied. **No code action needed**, but flagging because the plan and the note both list these files as carrying probes — readers cross-referencing the plan post-merge will find no removed lines and may wonder if the cleanup was skipped. Worth a one-line clarification in the implementer's commit message.

### F3 — Gratuitous rename in `BreathViewModel.set state` (not in the plan, but harmless)

The plan's Task 7 says: "remove the `debugPrint('[BREATH-PROBE] set state ...')` block inside `set state`. Keep the `isStructural` decision logic intact — only the diagnostic `debugPrint` goes."

The actual change introduces two new local variables that didn't exist before the probe was added:

```dart
@override
set state(BreathSessionState value) {
  final prev = super.state;
  final isStructural = !value.equalsIgnoringTickFields(prev);
  if (isStructural) {
    super.state = value;
  }
  if (!_stateController.isClosed) {
    _stateController.add(value);
  }
}
```

`prev` is read exactly once (in the next line); `isStructural` is read exactly once (in the `if`). The pre-probe version was:

```dart
if (!value.equalsIgnoringTickFields(super.state)) {
  super.state = value;
}
```

Both are semantically identical. Minor stylistic noise — adding two locally-scoped variables that name expressions used once each is a small step backwards from the original. Not worth blocking on; flagging for awareness. Consider reverting to the one-line form to keep the diff minimal and aligned with the plan.

### F4 — `Consumer` rebuild key-identity correctness (verified — no issue)

Inspected the four new `Consumer` widgets to ensure they don't break the existing `GlobalKey<BreathTimelineWidgetState> _timelineKey` reuse:

- The Timeline `Consumer` wraps `SizedBox > BreathTimelineWidget(key: _timelineKey, ...)`. On a state-only rebuild, the outer screen `build()` does **not** run (no `ref.watch` at screen root anymore); only the inner Consumer rebuilds, returning a new `SizedBox > BreathTimelineWidget` with the same `_timelineKey`. Flutter reuses the element / state via the GlobalKey. ✓
- On an outer-screen rebuild (MediaQuery / theme change), all four `Consumer`s are re-created. The Timeline still uses the same `_timelineKey`, so its state is preserved across that rebuild as well. ✓

### F5 — Closure capture of `viewModel` and `layout` inside `Consumer`s (verified — no issue)

Each `Consumer` builder captures `viewModel` and `layout` from the outer `build()` scope:
- `viewModel` is `ref.read(breathViewModelProvider.notifier)` — a stable Notifier instance; safe to retain across inner Consumer rebuilds.
- `layout` is recomputed on every outer build from MediaQuery. The inner Consumer rebuilds use the most-recently-captured `layout` from when their parent (outer Scaffold) last built, which is exactly when MediaQuery changed. Correct.

### F6 — Record-equality short-circuiting (verified — no issue)

The `.select((s) => (s.timelineSteps, s.activeStepId, s.status))` projection returns a Dart 3 record. Record equality compares fields with `==`. `timelineSteps` is a `List<TimelineStep>` whose `==` defaults to identity; the producer side (`BreathViewModel._onEngineState` and `_setupEngine`) preserves the list reference (documented invariant in `BreathSessionState.equalsIgnoringTickFields`), so identity holds and the record `==` short-circuits correctly on tick-only updates. ✓

### F7 — `package:flutter/scheduler.dart` import removal (verified — no issue)

The pre-edit screen imported `package:flutter/scheduler.dart` solely for `FrameTiming` in the removed `_onFrameTimings` method. The post-edit screen no longer imports it (line 2 — only `package:flutter/material.dart`). `Consumer` is imported transitively via `package:flutter_riverpod/flutter_riverpod.dart` (line 2 → line 2 of the file). ✓

### F8 — `ref.listenManual` for `_scrollToActive` and `didChangeAppLifecycleState` (verified — no issue)

- `ref.listenManual<BreathSessionState>(breathViewModelProvider, ...)` in `initState` (lines 86–93) is unchanged; reacts to `activeStepId` transitions without triggering rebuilds. ✓
- `didChangeAppLifecycleState` still uses `ref.read(breathViewModelProvider).status` (line 119) — one-shot read, not a rebuild trigger. ✓
- `WidgetsBinding.instance.addPostFrameCallback` still reads `ref.read(breathViewModelProvider)` for coordinator initialization (line 77). ✓

### F9 — `resetReason == other.resetReason` removal correctness (verified — no issue)

Confirmed the only consumers of `BreathSessionState.resetReason` are:
- `BreathAnimationCoordinator._onStateChanged` (raw `viewModel.listen(...)` stream)
- `OrbAnimationCoordinator._onStateChanged` (raw stream)

Neither subscribes via Riverpod, so dropping `resetReason` from `equalsIgnoringTickFields` does not regress any consumer: the raw `_stateController.add(value)` still fires on every call to `set state`. The morph-trigger idempotency (the coordinator's `_handleReset` only runs when `resetReason != null`) handles the clear-emit case unchanged. ✓

The updated doc comment correctly classifies `resetReason` alongside `remainingTicks` and `currentIntervalMs` as a transient field consumed only by raw-stream coordinators. ✓

## Summary

The substantive plan implementation (BreathSessionState equality narrowing, screen-wide `ref.watch` replaced with narrow `Consumer.select` subtrees, probe removal across the source tree) is **functionally correct**. The only must-fix is **F1: do not commit `some.txt`** — it is unrelated to the plan, contains the very `[BREATH-PROBE]` strings the cleanup removed, and was likely staged accidentally. F3 (minor variable-naming noise in `set state`) is optional polish. F2 is a documentation/awareness note, not a defect.

Resolve F1 before creating the planned commits.
