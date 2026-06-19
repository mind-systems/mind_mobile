# Plan Review: Fix the stateChannel dispose leak (provider-owned lifecycle)

**Plan:** `55-fix-the-statechannel-dispose-leak-provider-owned-lifecycle.md`
**Files Reviewed:** 5 (VM, Screen, BreathModule, BreathModuleStateChannel, router; cross-checked MeditationModule + RULES.md)
**Risk Level:** 🟢 Low

## Verdict

The plan is accurate, well-scoped, and correctly diagnoses the failure mode. Every file path, line-number citation, and API reference matches the current codebase. The fix is sound and addresses both symptoms (leaked channel + zombie `BreathSoundCoordinator`). No blocking issues.

## Context Gates

- **Architecture** (`.ai-factory/ARCHITECTURE.md`): PASS. The plan respects the domain/module boundary. `BreathModuleStateChannel` lives in `lib/BreathModule/Core/` and imports `package:breath_module` types; the package (`BreathViewModel`) cannot import from `lib/`. The plan's opaque `void Function()` hooks (`onModuleDispose`/`onModuleReset`) keep the concrete channel type out of the package — boundary preserved.
- **Rules** (`.ai-factory/RULES.md`): PASS (with a note). Rule 3 ("let the class manage the subscription itself") is honored — the channel still subscribes to `vm.stream` in its own constructor; the VM only triggers `dispose`/`reset` at lifecycle points. Using a setter (`attachModuleChannel`) instead of constructor injection is *forced* by a chicken-and-egg: the channel needs `vm.stream`, which does not exist until the VM is constructed. This is the correct resolution, not a rule violation.
- **Roadmap** (`.ai-factory/ROADMAP.md`): present; this is a `fix`-class change. No milestone linkage stated in the plan — non-blocking (WARN), mention in the commit if a roadmap entry exists.

## Correctness Verification

- **Task 1 line refs accurate.** VM `build()` `ref.onDispose` block is lines 67–76; `restartEngine()` is lines 270–273. Both match.
- **Dispose ordering is correct.** Calling `_onModuleDispose?.call()` first cancels the channel's `_stateSub`/`_channelSub` and runs `_channel.stop()` (if active & not ended) before `_stateController.close()` at line 73. No events are delivered to a closing controller. Cancelling `_channelSub` (a subscription on the app-lived `App.shared.moduleStateChannel.state`) is exactly what closes the leak.
- **Restart ordering is correct.** `restartEngine()` guards `if (_sessionDTO == null) return;`. Inserting `_onModuleReset?.call()` after the guard and before `_setupEngine` ensures the channel's flags reset *before* `_setupEngine` emits new state via `state =` (which fans out to all `_stateController` subscribers). This matches the plan's stated intent and the original "reset before new state flows" ordering.
- **Zombie `BreathSoundCoordinator` is genuinely fixed.** In the current screen `dispose()`, `widget.onDispose?.call()` is the *first* statement (line 119); if the `late final stateChannel` was unassigned it threw `LateInitializationError` and aborted the rest of the sequence — so `_soundCoordinator.dispose()` (line 122) never ran. Removing that line lets `dispose()` flow cleanly through all coordinator teardowns. Confirmed the plan keeps lines 120–127 intact.
- **No external consumers of the Breath channel.** Unlike `MeditationModule` (whose coordinator reads `stateChannel.moduleSessionId`), `BreathSessionCoordinator` does not reference `stateChannel`. Deleting the `late final` local in `buildSession` is safe — nothing else captures it.
- **No dangling references after removal.** Grep confirms the only call sites of `widget.onRestart`/`widget.onDispose` and the `stateChannel` local are the three the plan edits. The `import ... BreathModuleStateChannel.dart` in `BreathModule.dart` stays valid (channel still constructed in the closure).
- **VM constructor signature unchanged** → no test or call-site fallout from the VM side. `BreathSessionScreen` is only constructed in `BreathModule.buildSession`; the router uses `.path`/`.name` statics, which are untouched.
- **No migrations / schema / proto changes.** Pure Dart lifecycle refactor.

## Non-Blocking Suggestions (optional)

1. **Add `flutter test` to Task 4 validation.** Task 4 runs only `flutter analyze`. There is an existing test that explicitly simulates the restart sequence (`test/BreathModule/Presentation/BreathSession/breath_animation_coordinator_restart_test.dart`). It does not construct the screen with the removed params (verified — line 202 is a comment), so it should still compile, but moving channel reset into `restartEngine()` is a behavioral change worth covering with a one-line `flutter test` run. Cheap insurance.
2. **Latent twin in `MeditationModule` (out of scope).** `MeditationModule.buildSession` uses the identical `late final stateChannel` + screen-`onDispose` pattern, and additionally captures `stateChannel` eagerly in `MeditationSessionCoordinator(getSessionId: …)`. The same fragility likely applies there. Not part of this plan — flag as a follow-up candidate so the pattern fix is not forgotten on the meditation side.
3. **Document the setter rationale.** A one-line comment on `attachModuleChannel` noting *why* it is a post-construction setter (channel needs `vm.stream`) will pre-empt future "why isn't this constructor-injected per RULES.md rule 3?" questions.

## Positive Notes

- Correctly identifies that teardown ordering (channel before `_stateController.close()`) is load-bearing and spells it out per task.
- Respects the module boundary by using opaque callbacks rather than leaking the channel type into the package.
- Preserves all unrelated disposal/animation/sound semantics explicitly ("Do NOT touch `BreathSoundCoordinator`"), reducing blast radius.
- Logging setting "minimal" is appropriate — the channel already emits lifecycle logs via `logPrint`; no new logging needed.

PLAN_REVIEW_PASS
