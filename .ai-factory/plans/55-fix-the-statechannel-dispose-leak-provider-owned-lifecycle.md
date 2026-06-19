# Plan: Fix the stateChannel dispose leak (provider-owned lifecycle)

## Context
Tie `BreathModuleStateChannel` teardown (dispose + restart reset) to the `BreathViewModel` provider lifecycle instead of a build-local `late final` referenced by build-timing-dependent screen closures, eliminating the `LateInitializationError` that leaks the channel and the zombie `BreathSoundCoordinator` after a session → constructor → back round-trip.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Provider-owned teardown hooks

- [x] **Task 1: Add module-channel dispose/reset hooks to `BreathViewModel`**
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`
  Add two nullable hook fields and a setter to attach them:
  - `void Function()? _onModuleDispose;`
  - `void Function()? _onModuleReset;`
  - `void attachModuleChannel({required void Function() onDispose, required void Function() onReset}) { _onModuleDispose = onDispose; _onModuleReset = onReset; }`
  In the existing `build()` `ref.onDispose(() { … })` block (lines 67-76), call `_onModuleDispose?.call();` **first** (before the existing subscription/`_stateController`/`tickService` teardown), so the channel cancels its subscriptions on `vm.stream` before that stream controller is closed.
  In `restartEngine()` (lines 270-273), invoke `_onModuleReset?.call();` **before** `_setupEngine(_sessionDTO!)` — this preserves the original ordering where channel reset happened before any new engine state flowed (matching the old `onRestart` callback that fired first in the restart button handler).
  Do not change `start`/`pause`/`resume`/`complete`/`toggleStar` semantics.

- [x] **Task 2: Drop `onDispose`/`onRestart` from `BreathSessionScreen`** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  - Remove the `onRestart` and `onDispose` `VoidCallback?` fields and their constructor parameters (lines 23-26); the constructor becomes `const BreathSessionScreen({super.key});`.
  - In `dispose()` (line 118), remove `widget.onDispose?.call();`. Keep the rest of the disposal sequence intact (`_coordinator.dispose()`, `_orbCoordinator.dispose()`, `_soundCoordinator.dispose()`, `_motionEngine.dispose()`, `_shapeShifter.dispose()`, `_scrollController.dispose()`, `WidgetsBinding.instance.removeObserver(this)`, `super.dispose()`).
  - In the restart `ControlButton.onPressed` (line 401), remove `widget.onRestart?.call();`. Leave `_coordinator.reset()`, `_orbCoordinator.reset()`, `_soundCoordinator.reset()`, and `viewModel.restartEngine()` — `restartEngine()` now drives the channel reset (Task 1). Do NOT touch `BreathSoundCoordinator`.

- [x] **Task 3: Rewire `BreathModule.buildSession` to attach the channel to the VM** (depends on Task 1, Task 2)
  Files: `lib/BreathModule/BreathModule.dart`
  - Delete the `late final BreathModuleStateChannel stateChannel;` local (line 38).
  - Inside the `breathViewModelProvider.overrideWith(() { … })` closure, keep building the channel from `vm.stream` + `App.shared.moduleStateChannel` + `App.shared.breathInstructionStream` + `sessionId`, then attach it to the VM before returning: `vm.attachModuleChannel(onDispose: channel.dispose, onReset: channel.reset);` (use a plain `final channel = BreathModuleStateChannel(...)` local scoped to the closure).
  - Change the child to `const BreathSessionScreen()` — drop the `onRestart`/`onDispose` named arguments.
  - Leave `BreathModuleStateChannel` (`lib/BreathModule/Core/BreathModuleStateChannel.dart`) unchanged — its `start`/`pause`/`resume`/`end`/`stop`/`reset` and the `_stateSub`/`_channelSub` bindings stay intact; it just becomes VM-lifecycle-owned.

### Phase 2: Validation

- [x] **Task 4: Verify analyzer is clean** (depends on Task 3)
  Files: (no file changes)
  Run `/usr/local/bin/flutter analyze` and confirm no new warnings/errors in `lib/BreathModule/` or `packages/breath_module/`. In particular confirm there are no remaining references to `widget.onRestart`/`widget.onDispose` or the removed `stateChannel` local.
