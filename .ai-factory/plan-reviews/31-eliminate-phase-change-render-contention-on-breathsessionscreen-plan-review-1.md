# Plan Review — 31 Eliminate phase-change render contention on `BreathSessionScreen`

**Files Reviewed:** 1 plan + 6 source files (`BreathSessionState.dart`, `BreathSessionScreen.dart`, `BreathSessionViewModel.dart`, `BreathTimelineWidget.dart`, `BreathShapeWidget.dart`, `BreathAnimationCoordinator.dart`)
**Risk Level:** 🟢 Low

## Context Gates

- **ARCHITECTURE.md / module boundaries:** No violation. All edits stay inside `packages/breath_module/lib/src/BreathSession/...`. The Service / ViewModel / Coordinator separation is untouched. `Consumer.select` is a standard Riverpod presentation-layer pattern and does not leak domain types.
- **RULES.md:**
  - "Module Services must be stateless" — not affected.
  - "Never add module-specific state to App.dart" — not affected.
  - "Constructor injection" — not affected.
  - No rule violations introduced.
- **ROADMAP.md:** The plan is the exact decomposition of the open Phase 16 item ("Eliminate phase-change render contention on `BreathSessionScreen`"). Scope matches one-to-one (both `equalsIgnoringTickFields` + `Consumer.select` changes, plus `[BREATH-PROBE]` cleanup). ✅ aligned.

## Codebase verification

Cross-checked the plan against the actual files:

- `equalsIgnoringTickFields` (BreathSessionState.dart:91-107) currently has `resetReason == other.resetReason &&` on line 99 — Task 1's removal target is accurate. ✅
- `copyWith`'s `resetReason: resetReason ?? this.resetReason` (line 141) — plan correctly notes this is independent and must not be touched. ✅
- `BreathSessionViewModel.set state` (lines 92–109) currently has the `[BREATH-PROBE] set state` `debugPrint` block — Task 7 line range (~96–100+) is accurate. ✅
- `BreathSessionScreen.dart` structure matches plan exactly:
  - `_screenBuildCount`/`_shapeStackBuildCount`/`_bottomBarBuildCount`/`_controlButtonBuildCount` fields (lines 46–49) ✅
  - `_onFrameTimings` (lines 51–63), `addTimingsCallback` (line 69), `removeTimingsCallback` (line 132) ✅
  - `debugPrint('[BREATH-PROBE] scrollToActive ...')` (line 153) ✅
  - `final state = ref.watch(breathViewModelProvider)` (line 186) and the `_screenBuildCount++`/`debugPrint` block (188–194) ✅
  - Three `Builder(...)` probes — ShapeStack (210), Timeline parent (252 — actually plain `SizedBox`, not a Builder; plan is correct that this block is *not* a Builder and only needs to be wrapped in a Consumer), ControlButton (265), BottomBar (286) ✅
  - `_buildControlButton(state, viewModel, ...)` signature at line 274 / definition at line 325 — Task 5's signature rewrite is accurate ✅
- `viewModel.tickStream` is used inside the ShapeStack subtree (line 230) — plan correctly preserves the outer-scope `viewModel` reference for Task 3. ✅
- `ref.listenManual<BreathSessionState>(breathViewModelProvider, ...)` for `_scrollToActive` (lines 107–114) — plan correctly leaves untouched. ✅
- `didChangeAppLifecycleState` uses `ref.read(...)` (line 141), not `ref.watch` — plan correctly identifies this as a one-shot read. ✅
- `addPostFrameCallback` uses `ref.read(...)` (line 98) — same, correctly left alone. ✅
- `package:flutter/scheduler.dart` import (line 2) — only used for `FrameTiming` inside `_onFrameTimings`. Plan correctly proposes removing it after `_onFrameTimings` deletion. ✅
- `BreathTimelineWidget.build` `[BREATH-PROBE] Timeline build` line is at 94–98 — matches Task 7. ✅
- `BreathShapeWidget.build` `[BREATH-PROBE] ShapeWidget OUTER build` line is at 28 — matches Task 7. ✅
- `BreathAnimationCoordinator._handleReset` `[BREATH-PROBE] morph trigger` block is at 61–65 — matches Task 7. ✅
- Confirmed `resetReason` is read only by `BreathAnimationCoordinator._handleReset` and `OrbAnimationCoordinator._handleReset` — both subscribe via `viewModel.listen(...)` on the raw `_stateController` stream (not Riverpod). Task 1's safety claim holds. ✅

## Correctness of the optimization

- **`set state` semantics post-Task-1:** When the engine emits two back-to-back states that differ only in `resetReason` (`newCycle → null`), `equalsIgnoringTickFields` will now return `true` → `super.state` is *not* updated, but `_stateController.add(value)` *still* fires → animation coordinators still receive both emissions and trigger morph. Riverpod skips the spurious second publication. Behavior is correct.
- **Subtle but safe:** because skipped publications mean `super.state` lags behind the latest emitted value, a future tick that *does* trigger publication will compare against the older `super.state`. Since `resetReason` is excluded from equality, that comparison is consistent — no risk of an "I missed a resetReason" misclassification.
- **`Consumer.select` with records:** Dart record `==` compares positional fields element-wise. For `(timelineSteps, activeStepId, status)`, list equality falls back to `Object.==` (reference equality) — which is exactly what's needed since `timelineSteps` is carried by reference (`identical(...)` invariant already documented in `BreathSessionState`). For `(status, loadState)` and `(canStar, isStarred)`, all fields are enum/bool with value equality. ✅
- **Outer build re-execution:** After removing `ref.watch`, the outer `build()` runs only on widget-tree changes (mount, MediaQuery / layout, parent rebuild). `layout`, `mq`, and `viewModel` references inside the inner Consumer closures will be re-captured on outer rebuilds — correct.
- **`tickStream` stability:** `BreathViewModel.tickStream` returns `tickService.tickStream.cast()` which creates a new wrapper per call. The inner ShapeStack Consumer would rebuild on `loadState` changes (loading → ready, basically once per session) — `EclipseOrb.pulseStream` is reassigned on each Consumer rebuild but this matches the *existing* behavior on `state.loadState` changes, so no regression.

## Critical Issues

None.

## Issues / Gaps

### 🟡 Minor — Unused import after Task 7

`packages/breath_module/lib/src/BreathSession/Animation/BreathAnimationCoordinator.dart` only uses `import 'package:flutter/foundation.dart';` for the `debugPrint` call inside `_handleReset`. Once Task 7 removes that `debugPrint`, no other symbol from `foundation.dart` is referenced in the file (the rest of the file uses only `BreathMotionEngine`, `BreathShapeShifter`, `BreathSessionState`, `BreathViewModel`). The import becomes dead.

Depending on lint config, `flutter analyze` may emit `unused_import` (this lint is part of the default `flutter_lints` ruleset). Task 8 promises "no analyzer errors" — even if warnings don't fail the gate, the analyzer output will be noisy.

**Fix:** add to Task 7 (or fold into Task 8) — "after deleting the `debugPrint` in `BreathAnimationCoordinator._handleReset`, also remove `import 'package:flutter/foundation.dart';` from the file."

For reference, the other three files in Task 7 do **not** have this issue:
- `BreathSessionViewModel.dart` keeps `foundation` for `ValueNotifier`/`ValueListenable`.
- `BreathTimelineWidget.dart` keeps `foundation` for `ValueListenable<int>`.
- `BreathShapeWidget.dart` uses `widgets.dart` (not `foundation.dart`); the import is needed for `StatelessWidget`/`ListenableBuilder`/etc.

### 🟢 Nit — Task 4 phrasing

Task 4 calls the existing Timeline block a `Builder` ("Replace `BreathTimelineWidget` parent reads with a `Consumer`...") but the current code at line 252 is a bare `SizedBox(...)`, not a `Builder`. The body of the task ("Wrap the `SizedBox(...)` block in a `Consumer(...)`") is correct, and the surrounding wording is unambiguous. No fix needed — flagging only because the other three subtrees are `Builder` wrappers and a reader skimming the headline might expect symmetry.

## Positive Notes

- The plan correctly preserves all `ref.read(...)` call sites that are not rebuild-driving (`addPostFrameCallback`, `didChangeAppLifecycleState`, `_scrollToActive`'s `listenManual`). These are explicitly enumerated in Task 8 — strong defense-in-depth.
- Task 1 explicitly forbids touching `copyWith` (which has `resetReason: resetReason ?? this.resetReason` semantics) and explains why. Catches a footgun a less careful plan would hit.
- The `equalsIgnoringTickFields` doc-comment update is specified in enough detail to be a one-shot edit, with the correct rationale (raw-stream-only consumer, no Riverpod path).
- Task 5's signature change of `_buildControlButton` is fully specified — including which `state.*` reads to swap and which parameter to drop. Implementer has zero ambiguity.
- The acceptance criterion in Task 7 (`grep -r 'BREATH-PROBE' packages/breath_module` returns zero matches) is automation-verifiable.
- Task 8's smoke-check list maps directly to the four `ref.read`/`ref.listen` call-sites that remain — a useful invariant the reviewer can re-verify post-implementation.
- Commit plan groups changes coherently (Phase 1 + Phase 2 entry / Phase 2 body / Phase 3 cleanup) and matches the dependency graph.
- Full path `/usr/local/bin/flutter analyze` is specified in Task 8 — consistent with project memory.

## Recommendation

Add a single bullet to **Task 7** (or fold into Task 8's analyzer pass) covering the unused `foundation.dart` import in `BreathAnimationCoordinator.dart`. With that, the plan is ready to implement.

PLAN_REVIEW_PASS
