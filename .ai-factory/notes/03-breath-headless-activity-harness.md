# Headless breath-activity test harness + seam audit (T1)

**Date:** 2026-06-24
**Source:** conversation context (breath lifecycle FSM refactor planning)

## Key Findings

- The breath activity is **already DI-via-constructor at every seam**: `BreathViewModel` takes `ITickService` / `IBreathSessionService` / `IBreathSessionCoordinator` (all interfaces, exported from `packages/breath_module/lib/breath_module.dart`), and `BreathModuleStateChannel` takes a `ModuleStateChannel` + `BreathModuleInstructionStream` + a plain `Stream<BreathSessionState>`. The **only** thing fused to `App.shared` is `BreathModule.buildSession()` (`lib/BreathModule/BreathModule.dart:31-54`), which also returns a `Widget` (`ProviderScope`) — so it cannot be reused headless.
- Therefore readiness is **not** blocked by a missing interface; it is blocked by the absence of a **test-only assembler** that wires the same pieces with fakes. Additive, no prod change.
- Reusable fakes already exist: `_FakeChannel implements ModuleStateChannel` + `_FakeInstructionStream` (`test/BreathModule/breath_module_state_channel_test.dart:18,56`) and `FakeTickService` (`test/BreathModule/Presentation/BreathSession/breath_session_state_machine_test.dart:10`).

## Details

### Target — `BreathActivityHarness` (test helper, `test/BreathModule/Support/`)

Replicates the exact wiring of `BreathModule.buildSession()` with fakes (no `App.shared`, no Widget):

1. `FakeTickService` (on-demand ticks).
2. A fake `IBreathSessionService` returning a supplied `BreathSessionDTO` from `getSession`, with no-op `observeSession`/`observeSessionDeletion`/`starSession`.
3. A fake `IBreathSessionCoordinator` (records `openConstructor`/`shareSession`/`dismiss`).
4. A `BreathViewModel` inside a `ProviderContainer` overriding `breathViewModelProvider` (same shape as `BreathModule.dart:40`); read `.notifier` to instantiate.
5. A `BreathModuleStateChannel(channel: _FakeChannel, stateStream: vm.stream, instructionStream: _FakeInstructionStream, sessionId: ...)` + `vm.attachModuleChannel(onDispose: channel.dispose, onReset: channel.reset)`.
6. `await vm.initState()`.

**Three output channels exposed** (the contract surface):
- the recorded `BreathSessionState` sequence (subscribe `vm.stream`);
- the `_FakeChannel` call-log (`startCalls`/`pauseCount`/`unpauseCount`/`endCount`/`stopCount`);
- a hook for the future `isLive` signal ([[167-breath-derive-lifecycle-islive]]).

**Input surface:** `tick()`, `resume()`, `pause()`, `complete()`, `restartEngine()`, plus a DTO builder (reuse `makeExercise`/`makeSession` from the SM test).

### Seam audit

Confirm `IBreathSessionCoordinator` (`openConstructor`/`shareSession`/`dismiss`) / `ITickService` / `IBreathSessionService` suffice for every input the lifecycle refactor exercises. If any consumer the refactor touches injects a **concrete** where a fake is required, extract a narrow interface (behavior-preserving, default = real impl). Expected outcome: **no extraction needed** — record the verdict in this note.

## Guards

- Test-only; no prod change beyond any interface extraction the audit forces (behavior-preserving, default = real).
- Do **NOT** reuse `BreathModule.buildSession` — it is `App.shared`-fused and returns a Widget.
- Riverpod: dispose the `ProviderContainer` in `tearDown` so `BreathViewModel.build()`'s `ref.onDispose` (`BreathSessionViewModel.dart:77-88`) runs (cancels subs, disposes the SM + tick service).

## Verify

- Harness constructs under a plain `flutter test` with no platform bindings.
- A smoke test drives `resume → tick×N → complete` and reads all three output channels.
