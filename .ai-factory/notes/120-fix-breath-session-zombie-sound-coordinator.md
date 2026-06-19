# Fix the breath-session zombie sound coordinator (stateChannel dispose leak)

**Date:** 2026-06-19
**Source:** Loki-confirmed diagnosis (`[ZOMBIE]` probes)

## Key Findings

- **Symptom:** opening the breath-session constructor from an active session and returning leaves a zombie `BreathSoundCoordinator` — the clock tick (`tick_clock.ogg`) keeps playing because the session screen's audio coordinator is never torn down.
- **Proven cause (Loki, 13:37:01):** `BreathSessionScreen.dispose()` aborts with `LateInitializationError: Local 'stateChannel' has not been initialized.`, thrown from `widget.onDispose?.call()` — i.e. *before* `_soundCoordinator.dispose()` and `WidgetsBinding.removeObserver(this)`. So the tick subscription stays alive (audible zombie) and the disposed `State` stays registered as a lifecycle observer (later receives `didChangeAppLifecycleState` → the stray `suspend` seen in logs).
- **Why the `late final` is unset:** in `BreathModule.buildSession` (`lib/BreathModule/BreathModule.dart`), `stateChannel` is a captured `late final` local assigned **only as a side-effect** of the `breathViewModelProvider.overrideWith(...)` initializer, and referenced by the `onRestart`/`onDispose` closures handed to `BreathSessionScreen`. On the constructor round-trip GoRouter re-invokes the route `builder` → a fresh `buildSession` (new `ProviderScope` + new `BreathSessionScreen` widget whose `onDispose` closure captures a **new, unassigned** `stateChannel` local). The `State` is reused (no second `SoundCoordinator initialize` in logs), so the new provider override is never read → the new `stateChannel` is never assigned → dispose reads it uninitialized and throws.
- **Confirmed NOT the cause:** it is not a `context.push` "screen stays mounted" issue (the screen *does* dispose), not pause-specific (direct back-out while paused disposes cleanly — runs #1/#2), and not `_channel.stop()` (that branch is skipped when `_started == false`). The two non-constructor exits ran `dispose` to completion including `after onDispose` and `SoundCoordinator dispose`.
- **Residual leak beyond the sound:** the *original* build's `stateChannel` (the one with live `_stateSub` on `vm.stream` and `_channelSub` on the shared `moduleStateChannel`) is also never disposed → subscription leak, independent of the audible tick.

## Details

### The change

Tie `BreathModuleStateChannel` disposal (and restart reset) to the **provider lifecycle** instead of the captured `late final` local and the build-timing-dependent `onRestart`/`onDispose` closures.

Constraint that shapes the fix: `BreathModuleStateChannel` is constructed from both `vm.stream` *and* app-layer singletons (`App.shared.moduleStateChannel`, `App.shared.breathInstructionStream`). The VM lives in the `breath_module` package and cannot reference `App.shared` (module boundary), so the channel **must** be created at the app layer in `BreathModule.buildSession` — it cannot move wholesale into the VM. Therefore the override closure (`() => BreathViewModel(...)`) is the construction site, but note that closure does **not** receive a `ref` — disposal must hang off the VM's `ref`, not the closure.

Anchor point that already exists: `BreathViewModel extends Notifier<BreathSessionState>` and its `build()` (`BreathSessionViewModel.dart:66`) already holds a `ref.onDispose(() { … })` block that tears down its own subscriptions, `_stateController`, and `tickService`. This is the deterministic teardown hook to reuse — it fires whenever the provider disposes, regardless of how many times GoRouter re-runs the route `builder`.

- In `BreathModule.buildSession`, keep creating the channel from `vm.stream` + `App.shared` deps, but **hand its `dispose`/`reset` to the VM** instead of capturing a `late final` referenced by screen closures. Concretely: give `BreathViewModel` a settable disposal/reset hook (e.g. `void Function()? onModuleDispose` / `onModuleReset`, or a small `attachModuleChannel(...)` method) set right after the channel is built in the override; the VM's existing `build()` `ref.onDispose` invokes the dispose hook, and `restartEngine()`/the restart path invokes the reset hook.
- Remove `BreathSessionScreen.onDispose` entirely (teardown is provider-owned, not screen-`State`-owned).
- Replace `onRestart` → `stateChannel.reset()`: route restart-reset through the VM (it already owns `restartEngine()`), not through a build-local closure.

### Files

- `lib/BreathModule/BreathModule.dart` — `buildSession` wiring (the core change): build the channel in the override, attach its dispose/reset to the VM, drop the `late final` local and the `onDispose`/`onRestart` closures bound to it.
- `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart` — add the dispose/reset hook; call the dispose hook from the existing `build()` `ref.onDispose`; call the reset hook from the restart path.
- `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart` — drop `onDispose`; remove/rewire `onRestart` so the restart button drives the VM, not a build-local.
- `lib/BreathModule/Core/BreathModuleStateChannel.dart` — no behavior change; `start/pause/resume/end/stop`, `reset()`, and the two subscriptions stay intact. It just becomes VM-lifecycle-owned.

### Guards

- The fix is **not** the diagnostic `try/catch` currently wrapping `widget.onDispose` in `BreathSessionScreen.dispose` — that only swallows the error and still leaks the real channel. It is removed in the probe rollback (note 121), which depends on this note landing first.
- Preserve live-session tracking semantics: `start`/`pause`/`resume`/`end`/`stop` and `reset()` must behave exactly as before; the channel still binds to `App.shared.moduleStateChannel` and `App.shared.breathInstructionStream`.
- Do **not** modify `BreathSoundCoordinator` — it is the victim, not the cause.
- Don't try to fight GoRouter's route rebuild; provider-owned disposal makes the rebuild harmless.

### Verify

- Repro path (session → constructor → back from constructor → back from session): `BreathSessionScreen.dispose` completes through audio teardown with **no** `LateInitializationError`; no zombie tick; no orphaned `_stateSub`/`_channelSub`.
- The two non-constructor exits still dispose cleanly; live-session `start`/`pause`/`end` still fire; restart still resets the channel.
- `flutter analyze` clean.

## Open Questions

- Whether `onRestart` is best folded entirely into `BreathViewModel` or kept as a thin screen callback that targets the VM — decide at `/aif-plan` time based on how `restartEngine()` already routes.
