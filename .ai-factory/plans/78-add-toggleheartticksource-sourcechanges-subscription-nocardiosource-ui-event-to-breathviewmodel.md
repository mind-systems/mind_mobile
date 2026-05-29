# Plan: Add `toggleHeartTickSource()` + `sourceChanges` subscription + `noCardioSource` UI event to `BreathViewModel`

## Context
Expose a manual heart/clock tick source toggle on `BreathViewModel`, surface the rejection case as a UI event, and make `state.tickSource` the single readout of `ITickService.sourceChanges` so manual toggles and auto-fallback share one update path.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Rename error enum into UI event enum

- [x] **Task 1: Rename `BreathSessionError` → `BreathSessionUiEvent` and add `noCardioSource`**
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`
  Replace the existing enum declaration
  ```dart
  enum BreathSessionError { starFailed }
  ```
  with
  ```dart
  enum BreathSessionUiEvent { starFailed, noCardioSource }
  ```
  Rename the callback field `void Function(BreathSessionError error)? onErrorEvent;` to `void Function(BreathSessionUiEvent event)? onUiEvent;`. Update the existing emit site in `toggleStar()` from `onErrorEvent?.call(BreathSessionError.starFailed);` to `onUiEvent?.call(BreathSessionUiEvent.starFailed);`. Do NOT touch `BreathSessionListViewModel` or `LoginViewModel` — those have their own unrelated `SessionListError` / `LoginError` enums and `onErrorEvent` fields.

- [x] **Task 2: Update the one screen callsite**
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  In `initState()` (around line 99), rename `viewModel.onErrorEvent = (_) { ... }` to `viewModel.onUiEvent = (_) { ... }`. Keep the existing body — the snackbar emit on `starFailed` still applies. The `noCardioSource` branch is intentionally NOT handled in this milestone (that is wired in milestone 7); the `_` discard already covers any new variant without breaking compilation. If the existing handler does not currently destructure the variant, add a TODO-free `// noCardioSource handled in M7` line of context but do not introduce new behavior here.

### Phase 2: Subscribe to `sourceChanges` and write `state.tickSource`

- [x] **Task 3: Add `_sourceChangesSub` field and subscription wiring** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`
  Add a new field next to the other `StreamSubscription` fields:
  ```dart
  StreamSubscription<TickSource>? _sourceChangesSub;
  ```
  Add the import for `TickSource` if not already present — it lives at `package:breath_module/src/CommonModels/TickSource.dart` and is re-exported by the package; the file already imports `../ITickService.dart` which transitively references `TickSource`, so add an explicit import `import '../CommonModels/TickSource.dart';` to make the field type resolve cleanly.
  In `initState()`, after `_setupEngine(dto);` runs once (before assigning the `_sessionUpdateSubscription` / `_sessionDeletionSubscription`), add:
  ```dart
  _sourceChangesSub = tickService.sourceChanges.listen((src) {
    state = state.copyWith(tickSource: src);
  });
  ```
  Place this subscription exactly once — `_setupEngine` is invoked again on session updates, but the tick service is stable for the lifetime of the VM, so the subscription must NOT live inside `_setupEngine`. Do NOT cast `tickService` to `SwitchableTickService`; `sourceChanges` is declared on `ITickService` (added in M4) and is available directly.

- [x] **Task 4: Cancel `_sourceChangesSub` in `ref.onDispose`** (depends on Task 3)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`
  Inside the existing `ref.onDispose(() { ... })` block in `build()`, add `_sourceChangesSub?.cancel();` alongside the other subscription cancellations (before `_stateMachine?.dispose();` and `tickService.dispose();`). Keep the existing ordering convention — subscription cancellations first, then `dispose()` calls on owned objects.

### Phase 3: Public toggle method

- [x] **Task 5: Add `toggleHeartTickSource()` public method** (depends on Tasks 1, 3)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`
  In the `// ===== Public controls =====` section (alongside `pause`, `resume`, `complete`, `restartEngine`, etc.), add:
  ```dart
  void toggleHeartTickSource() {
    final target = state.tickSource == TickSource.heartbeat
        ? TickSource.timer
        : TickSource.heartbeat;
    final ok = tickService.trySwitchTo(target);
    if (!ok) {
      onUiEvent?.call(BreathSessionUiEvent.noCardioSource);
    }
    // state.tickSource is updated by the _sourceChangesSub subscriber, not here —
    // single sync point for both manual toggle and auto-fallback.
  }
  ```
  Do NOT write `state = state.copyWith(tickSource: ...)` from inside this method. Do NOT cast `tickService` to `SwitchableTickService` — both `sourceChanges` and `trySwitchTo` are declared on `ITickService` (added in M4).

## Verification (manual, no test code)
After the edits:
- `flutter analyze` must pass — the enum rename is purely local to `BreathSessionViewModel.dart` + `BreathSessionScreen.dart`; the other `onErrorEvent` callsites in `BreathSessionListViewModel`, `LoginViewModel`, and their screens belong to unrelated enums and must remain untouched.
- Launching a session must behave identically to the previous milestone — `SwitchableTickService` still defaults to `TickSource.timer`, no toggle button exists yet (lands in M7), so `toggleHeartTickSource()` is unreachable from UI but available on the VM for M7 to call.
- The `_sourceChangesSub` subscription is set up exactly once in `initState()` (not in `_setupEngine`) so re-runs on session updates do not stack subscriptions.

<!-- orchestrator-sessions
planner: 66dd4ade-dbf2-44e1-be2a-ecf7351b4422
elapsed: 543
implementer: d02f302f-bb3d-4e2d-88a5-58e172e1dd12
-->
