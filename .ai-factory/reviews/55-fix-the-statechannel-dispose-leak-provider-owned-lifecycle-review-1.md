# Code Review: Fix the stateChannel dispose leak (provider-owned lifecycle)

**Plan:** `55-fix-the-statechannel-dispose-leak-provider-owned-lifecycle.md`
**Files changed (code):** 3
- `lib/BreathModule/BreathModule.dart`
- `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
- `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`

**Risk Level:** 🟢 Low

## Summary

The implementation matches the plan exactly and correctly moves `BreathModuleStateChannel` teardown/reset onto the `BreathViewModel` provider lifecycle. The root cause — `widget.onDispose?.call()` reading an unassigned `late final stateChannel` and throwing `LateInitializationError` before `_soundCoordinator.dispose()` could run — is eliminated by removing the screen-owned callbacks entirely. No bugs, security issues, or correctness regressions found.

## Correctness Verification

- **Hook wiring is sound.** In `BreathModule.buildSession`, the override closure constructs `vm` first, then the channel from `vm.stream` (the `_stateController` broadcast stream is initialized as a field initializer, so it is live the moment `vm` exists), then calls `vm.attachModuleChannel(...)` before returning. Riverpod invokes `build()` (which registers `ref.onDispose`) only after the override function returns the notifier, so `_onModuleDispose`/`_onModuleReset` are guaranteed set before the dispose callback can ever read them. The callback also reads the fields lazily at dispose time, so ordering is doubly safe.

- **Dispose ordering is correct and load-bearing.** `_onModuleDispose?.call()` is the **first** statement in the `ref.onDispose` block — the channel cancels `_stateSub` (on `vm.stream`) and `_channelSub` (on the app-lived `App.shared.moduleStateChannel.state`) and runs `_channel.stop()` (only when `_started && !_ended`) *before* `_stateController.close()`. No event is pushed into a closing controller; the app-lived channel subscription that was the actual leak is now cancelled deterministically.

- **Restart semantics preserved.** `restartEngine()` keeps its `if (_sessionDTO == null) return;` guard and invokes `_onModuleReset?.call()` before `_setupEngine`. The channel's flags (`_started`, `_ended`, `_previousStatus`, …) are therefore cleared before `_setupEngine` emits the new state through `set state` (which fans out to all `_stateController` subscribers). This matches the original "reset before new state flows" ordering. The only ordering shift versus the old button handler — channel reset now runs *after* the coordinator/orb/sound `reset()` calls instead of before — is behaviorally inert: those coordinators and the channel are mutually independent (neither touches the other's state), and no state is emitted on `vm.stream` between them.

- **Null-hook safety in tests / standalone use.** `attachModuleChannel` is only called from `buildSession`. Unit tests (`breath_animation_coordinator_restart_test.dart`, `breath_view_model_publication_test.dart`) construct the VM and call `restartEngine()` directly without a channel, so `_onModuleReset?.call()` and `_onModuleDispose?.call()` are no-ops. No test compilation or runtime fallout.

- **Screen teardown now completes.** With `widget.onDispose?.call()` removed, `dispose()` flows straight through `_coordinator.dispose()` → `_orbCoordinator.dispose()` → `_soundCoordinator.dispose()` → … → `WidgetsBinding.instance.removeObserver(this)` → `super.dispose()`. The zombie tick (`_soundCoordinator` never disposed) and the orphaned lifecycle-observer registration are both resolved.

- **No dangling references / dead imports.** `BreathSessionScreen` is constructed only in `buildSession`, now as `const BreathSessionScreen()`. The const constructor is valid (the class holds no instance fields; `name`/`path` are statics). `BreathModule.dart` still imports and uses `BreathModuleStateChannel`. No remaining references to `widget.onRestart`/`widget.onDispose` or the deleted `stateChannel` local.

- **No migrations / proto / schema / DTO changes.** Pure Dart lifecycle refactor; module boundary preserved (opaque `void Function()` hooks keep the concrete channel type out of the `breath_module` package).

## Non-Blocking Observations

1. **Latent twin in `MeditationModule` (out of scope).** `MeditationModule.buildSession` uses the same `late final stateChannel` + `MeditationSessionScreen(onDispose:)` pattern and additionally captures the channel in `MeditationSessionCoordinator(getSessionId: …)`. The identical fragility likely applies there; worth a follow-up so the pattern fix is not forgotten on the meditation side. (Note: the meditation coordinator's external read of `stateChannel.moduleSessionId` means the breath approach is not a drop-in copy there.)

2. **Setter rationale.** A one-line comment on `attachModuleChannel` explaining it must be a post-construction setter (the channel needs `vm.stream`, which doesn't exist until the VM is constructed) would pre-empt future "why not constructor injection?" questions. Optional.

REVIEW_PASS
