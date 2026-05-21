# Plan: Eliminate phase-change render contention on `BreathSessionScreen`

## Context
A phase change on the breathing session currently triggers a full `BreathSessionScreen` rebuild — and on cycle/exercise boundaries it triggers two. This plan ships two coupled changes that together reduce a phase change to a single narrow `Consumer` rebuild, plus removes all `[BREATH-PROBE]` diagnostic instrumentation.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Drop `resetReason` from publication equality

- [x] **Task 1: Exclude `resetReason` from `equalsIgnoringTickFields` and refresh the doc comment**
  Files: `packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart`
  Remove the `resetReason == other.resetReason &&` line from `equalsIgnoringTickFields` (currently line 99). Update the doc comment above the method so the "Excluded fields and why" section lists `resetReason` as a third transient field alongside `remainingTicks` and `currentIntervalMs`. The new bullet must state that `resetReason` is consumed only by raw-stream animation coordinators (`BreathAnimationCoordinator`, `OrbAnimationCoordinator`) via `viewModel.listen(...)` — never via Riverpod — so a clear-emit (`newCycle → null`) must not classify as a structural change. Do not touch `copyWith` — its `resetReason: resetReason ?? this.resetReason` carry-forward semantics are independent of the publication-equality check.

### Phase 2: Narrow the screen rebuild surface with `Consumer.select`

- [x] **Task 2: Remove the screen-wide `ref.watch` and probe instrumentation in `BreathSessionScreen`** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  In `_BreathSessionScreenState`:
  - Delete the `_screenBuildCount`, `_shapeStackBuildCount`, `_bottomBarBuildCount`, `_controlButtonBuildCount` fields.
  - Delete the `_onFrameTimings` method.
  - Remove `WidgetsBinding.instance.addTimingsCallback(_onFrameTimings);` from `initState` and `WidgetsBinding.instance.removeTimingsCallback(_onFrameTimings);` from `dispose`.
  - Remove the `debugPrint('[BREATH-PROBE] scrollToActive ...')` line from `_scrollToActive`.
  - In `build()`, remove `final state = ref.watch(breathViewModelProvider);` and the `_screenBuildCount++` + `debugPrint('[BREATH-PROBE] Screen.build ...')` block. Keep `final viewModel = ref.read(breathViewModelProvider.notifier);` (used by several inner callbacks). Keep `MediaQuery.of(context)` and `BreathSessionLayout.compute(...)` at the top of `build()` — they don't depend on `state`.

- [x] **Task 3: Replace the ShapeStack `Builder` with a `Consumer` that selects `loadState`** (depends on Task 2)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  Replace the first `Builder(builder: (context) { _shapeStackBuildCount++; debugPrint(...); return Padding(...); })` block with a `Consumer(builder: (context, ref, _) { final loadState = ref.watch(breathViewModelProvider.select((s) => s.loadState)); return Padding(...); })`. The inner widget tree (Padding → SizedBox → Stack with `EclipseOrb` + `AnimatedOpacity` + `BreathShapeWidget`) stays identical except `state.loadState == SessionLoadState.ready` becomes `loadState == SessionLoadState.ready`. Drop the throwaway probe counter and `debugPrint` entirely. `viewModel.tickStream` reference stays from the outer-scope `viewModel`.

- [x] **Task 4: Replace `BreathTimelineWidget` parent reads with a `Consumer` that selects a `(timelineSteps, activeStepId, status)` record** (depends on Task 2)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  Wrap the `SizedBox(height: layout.timelineHeight, child: BreathTimelineWidget(...))` block in a `Consumer(builder: (context, ref, _) { final (steps, activeStepId, status) = ref.watch(breathViewModelProvider.select((s) => (s.timelineSteps, s.activeStepId, s.status))); return SizedBox(...); })`. Inside, pass `steps:` to `steps`, `activeStepId:` to `activeStepId`, and `status:` to `status` (replacing the prior `state.timelineSteps` / `state.activeStepId` / `state.status` reads). `remainingTicksListenable` still uses `ref.read(breathViewModelProvider.notifier).remainingTicksNotifier` — read it via the inner `Consumer`'s `ref`. The record equality short-circuits on identical refs because `timelineSteps` is carried by reference (`identical(...)` invariant documented in `BreathSessionState`).

- [x] **Task 5: Replace the ControlButton `Builder` with a `Consumer` that selects `(status, loadState)`** (depends on Task 2)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  Replace the second `Builder(builder: (context) { _controlButtonBuildCount++; debugPrint(...); return Padding(...); })` block with a `Consumer(builder: (context, ref, _) { final (status, loadState) = ref.watch(breathViewModelProvider.select((s) => (s.status, s.loadState))); return Padding(padding: EdgeInsets.all(layout.buttonPadding), child: _buildControlButton(status: status, loadState: loadState, viewModel: viewModel, buttonSize: layout.buttonSize, iconSize: layout.iconSize)); })`. Update `_buildControlButton` signature to take `BreathSessionStatus status`, `SessionLoadState loadState`, and `BreathViewModel viewModel` (drop the `BreathSessionState state` parameter); rewrite the body to use `status` / `loadState` directly instead of `state.status` / `state.loadState`.

- [x] **Task 6: Replace the BottomBar `Builder` with a `Consumer` that selects `(canStar, isStarred)`** (depends on Task 2)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  Replace the third `Builder(builder: (context) { _bottomBarBuildCount++; debugPrint(...); return SessionBottomBar(...); })` block with a `Consumer(builder: (context, ref, _) { final (canStar, isStarred) = ref.watch(breathViewModelProvider.select((s) => (s.canStar, s.isStarred))); return SessionBottomBar(iconSize: layout.iconSize, actions: [...]); })`. Inside the `actions` list, replace `state.canStar` with `canStar` and `state.isStarred` with `isStarred`. The share / edit `IconButton`s and their `viewModel.shareSession()` / `viewModel.openEditor()` callbacks remain unchanged.

### Phase 3: Final probe cleanup

- [x] **Task 7: Remove `[BREATH-PROBE]` instrumentation from the ViewModel and the remaining widget builds** (depends on Task 6)
  Files:
  `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`,
  `packages/breath_module/lib/src/BreathSession/Views/BreathTimelineWidget.dart`,
  `packages/breath_module/lib/src/BreathSession/Views/BreathShapeWidget.dart`,
  `packages/breath_module/lib/src/BreathSession/Animation/BreathAnimationCoordinator.dart`
  - In `BreathSessionViewModel.dart`: remove the `debugPrint('[BREATH-PROBE] set state ...')` block inside `set state` (around line 96–100+). Keep the `isStructural` decision logic intact — only the diagnostic `debugPrint` goes.
  - In `BreathTimelineWidget.dart`: remove the `debugPrint('[BREATH-PROBE] Timeline build ...')` lines at the top of `build()` (around line 94–98).
  - In `BreathShapeWidget.dart`: remove the `debugPrint('[BREATH-PROBE] ShapeWidget OUTER build')` line inside `build()` (around line 28).
  - In `BreathAnimationCoordinator.dart`: remove the `debugPrint('[BREATH-PROBE] morph trigger ...')` block inside `_handleReset` (around line 61–65). Keep all morph-trigger logic — only the diagnostic print goes.
  After this task, `grep -r 'BREATH-PROBE' packages/breath_module` must return zero matches.

- [x] **Task 8: Smoke-check the screen still compiles and `ref.listenManual` for `_scrollToActive` is intact** (depends on Task 7)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  Read the file end-to-end and confirm:
  - No remaining references to `state` (the deleted variable) inside `build()` or `_buildControlButton`.
  - `ref.listenManual<BreathSessionState>(breathViewModelProvider, ...)` for `_scrollToActive` in `initState` is unchanged.
  - `didChangeAppLifecycleState` still uses `ref.read(breathViewModelProvider).status` (it's a one-shot read, not a rebuild trigger — leave as-is).
  - `WidgetsBinding.instance.addPostFrameCallback` in `initState` still reads `ref.read(breathViewModelProvider)` for coordinator initialization — leave as-is.
  - Imports list: `package:flutter/scheduler.dart` was only used for `FrameTiming` in `_onFrameTimings`. If no other code in this file references `scheduler.dart`, remove the import.
  Run `flutter analyze packages/breath_module` (full path: `/usr/local/bin/flutter analyze packages/breath_module`) to confirm no analyzer errors.

## Commit Plan
- **Commit 1** (after tasks 1–2): "Drop resetReason from publication equality and remove screen-wide ref.watch in BreathSessionScreen"
- **Commit 2** (after tasks 3–6): "Replace Builder probes with narrow Consumer.select subtrees on BreathSessionScreen"
- **Commit 3** (after tasks 7–8): "Remove [BREATH-PROBE] instrumentation and verify analyzer is clean"
