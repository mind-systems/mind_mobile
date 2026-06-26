# Plan: Headless breath-activity test harness + seam audit

## Context
Build a test-only `BreathActivityHarness` that replicates `BreathModule.buildSession()` wiring with fakes (no `App.shared`, no Widget) so the breath activity can be driven headless under a plain `flutter test`, and audit that the existing constructor-DI'd interfaces suffice for the upcoming lifecycle refactor.

## Settings
- Testing: yes (this milestone's deliverable is test infrastructure + a smoke test)
- Logging: none
- Docs: no

## Tasks

### Phase 1: Seam audit

- [x] **Task 1: Audit the breath-activity seams and record the verdict**
  Files: `.ai-factory/notes/03-breath-headless-activity-harness.md`
  Confirm every dependency `BreathModule.buildSession()` injects (`lib/BreathModule/BreathModule.dart:34-60`, factory body `46-55`) is fakeable headless:
  - `ITickService` (exported from `packages/breath_module/lib/breath_module.dart:36`) — injected into `BreathViewModel`. This is a declared abstract interface.
  - `IBreathSessionService` + `IBreathSessionCoordinator` (`breath_module.dart:12-13`) — injected into `BreathViewModel`. Both are declared abstract interfaces.
  - `ModuleStateChannel` (`lib/Core/Grpc/ModuleStateChannel.dart`) + `BreathModuleInstructionStream` (`lib/BreathModule/Core/BreathModuleInstructionStream.dart`) — injected into `BreathModuleStateChannel`. **Note:** these are *concrete classes*, not declared abstract interfaces; they are fakeable via Dart's implicit per-class interface plus a `noSuchMethod` override (as the existing `_FakeChannel`/`_FakeInstructionStream` already prove). Record this distinction in the note so the verdict is not mistaken for "all seams are declared interfaces."
  Verify no consumer the lifecycle refactor touches injects a **concrete** where a fake is required (the existing private fakes in `test/BreathModule/breath_module_state_channel_test.dart:18,56` and `test/BreathModule/Presentation/BreathSession/breath_session_state_machine_test.dart:10` already prove the channel/instruction/tick seams are fakeable; `test/BreathModule/Presentation/BreathSession/breath_view_model_publication_test.dart:49-81` proves the service/coordinator seams are fakeable). Expected outcome: **no interface extraction needed**. Append a short "Seam audit verdict" subsection to the note recording this. If — and only if — a touched consumer is found injecting a concrete, document the narrow interface to extract (behavior-preserving, default = real impl) instead, and add a follow-up task.

### Phase 2: Shared test fakes

- [x] **Task 2: Consolidate reusable fakes + DTO builders into a shared support file** (depends on Task 1)
  Files: `test/BreathModule/Fakes/BreathActivityFakes.dart`
  Create public, reusable versions of the fakes currently duplicated as private classes across the test suite, placed in the existing `test/BreathModule/Fakes/` directory (established convention — see `FakeSmoothedRrSource.dart`):
  - `FakeTickService implements ITickService` — implement **all five** interface members (no `noSuchMethod` escape; `ITickService` is a pure abstract interface): `tickStream` (broadcast `StreamController<TickData>`), `source => TickSource.timer`, `nominalIntervalMs => 1000`, `sourceChanges => const Stream.empty()`, `trySwitchTo` returns `false`, plus a `tick([intervalMs])` helper and a `dispose()` that closes the controller (port from `test/BreathModule/Presentation/BreathSession/breath_session_state_machine_test.dart:10-32`).
  - `FakeModuleStateChannel implements ModuleStateChannel` — records `startCalls`/`pauseCount`/`unpauseCount`/`endCount`/`stopCount`, exposes broadcast `state`/`events` controllers, and **keeps the `noSuchMethod` override** (`ModuleStateChannel` is a concrete class — the override covers members not explicitly faked) (port from `test/BreathModule/breath_module_state_channel_test.dart:18-54`).
  - `FakeInstructionStream implements BreathModuleInstructionStream` — records `sendSample(...)` calls with a `phaseTickCalls` view, and **keeps the `noSuchMethod` override** (port from `test/BreathModule/breath_module_state_channel_test.dart:56-68`).
  - `FakeBreathSessionService implements IBreathSessionService` — returns a supplied `BreathSessionDTO` from `getSession`/`starSession`; `observeSession`/`observeSessionDeletion` return `const Stream.empty()` (port from `test/BreathModule/Presentation/BreathSession/breath_view_model_publication_test.dart:63-81`).
  - `FakeBreathSessionCoordinator implements IBreathSessionCoordinator` — records `openConstructor`/`shareSession`/`dismiss` calls (extend the no-op `_FakeCoordinator` at `test/BreathModule/Presentation/BreathSession/breath_view_model_publication_test.dart:49-56` with call recording).
  - `makeExercise(...)` and `makeSession(...)` DTO builders (port from `test/BreathModule/Presentation/BreathSession/breath_session_state_machine_test.dart:38-63`).
  Keep these additive — do not modify the existing test files in this milestone.

### Phase 3: Harness + smoke test

- [x] **Task 3: Implement `BreathActivityHarness`** (depends on Task 2)
  Files: `test/BreathModule/Support/BreathActivityHarness.dart`
  Replicate the exact wiring of `BreathModule.buildSession()` (`lib/BreathModule/BreathModule.dart:34-59`) with fakes — no `App.shared`, no `ProviderScope`/Widget:
  - Construct a `ProviderContainer` overriding `breathViewModelProvider.overrideWith(() {...})` with the same factory shape as `BreathModule.dart:46-55`: build a `BreathViewModel(tickService: FakeTickService, service: FakeBreathSessionService, coordinator: FakeBreathSessionCoordinator, sessionId: ...)`, then a `BreathModuleStateChannel(channel: FakeModuleStateChannel, stateStream: vm.stream, instructionStream: FakeInstructionStream, sessionId: ...)`, then `vm.attachModuleChannel(onDispose: channel.dispose, onReset: channel.reset)`.
  - Read `container.read(breathViewModelProvider.notifier)` to obtain the VM. **Subscribe to `vm.stream` for the recorded-state channel _before_ calling `await vm.initState()`** — `vm.stream` is a broadcast controller (`BreathSessionViewModel.dart:57`) that does not replay; the initial `SessionLoadState.ready` emission fires inside `initState()` → `_setupEngine`, so a late subscription would miss it. Then `await vm.initState()`.
  - **Input surface:** `tick([intervalMs])`, `resume()`, `pause()`, `complete()`, `restartEngine()` — delegating to the fake tick service and the VM's public controls (`BreathSessionViewModel.dart:276-286`). Accept a caller-supplied `BreathSessionDTO` (default built via `makeSession`/`makeExercise`).
  - **Three output channels:**
    1. the `BreathSessionState` sequence — subscribe to `vm.stream` and record into a list the test can read;
    2. the channel call-log — expose the `FakeModuleStateChannel` (and `FakeInstructionStream`) so tests read `startCalls`/`pauseCount`/`unpauseCount`/`endCount`/`stopCount`/`phaseTickCalls`;
    3. a placeholder hook for the future `isLive` signal (note `[[05-breath-derive-lifecycle-islive]]`) — expose a typed getter that current callers can read without it being wired to real logic yet.
  - Provide `dispose()` that calls `container.dispose()` so `BreathViewModel.build()`'s `ref.onDispose` (`BreathSessionViewModel.dart:78-88`) runs — cancelling subscriptions, disposing the state machine and tick service, and closing the state controller.

- [x] **Task 4: Add a smoke test exercising the harness** (depends on Task 3)
  Files: `test/BreathModule/Support/breath_activity_harness_test.dart`
  Construct the harness under a plain `flutter test` (no platform bindings). Drive `resume → tick × N → complete` and assert all three output channels are observable: the recorded `BreathSessionState` sequence advances through phases and reaches `BreathSessionStatus.complete`; the channel call-log shows `start` then `end`; and the `isLive` hook getter is readable. Dispose the harness (and thus the `ProviderContainer`) in `tearDown`.
</content>
</invoke>
