# Plan Review: Headless breath-activity test harness + seam audit

**Plan:** `.ai-factory/plans/03-headless-breath-activity-test-harness-seam-audit.md`
**Risk Level:** 🟢 Low
**Verdict:** Solid and well-grounded. One minor compile-gotcha to fix in the task spec; the rest are accuracy nits and an optional refinement.

## Verification performed

Every file path, line-number citation, and API claim in the plan was checked against the live codebase:

| Plan claim | Result |
|---|---|
| `BreathModule.buildSession()` wiring at `BreathModule.dart:34-59` | ✅ Confirmed (buildSession spans 34–60; the factory body is 46–55) |
| `ITickService` exported from `breath_module.dart`; `IBreathSessionService`/`IBreathSessionCoordinator` exported | ✅ Confirmed (all three in the export list) |
| `_FakeChannel implements ModuleStateChannel` at `breath_module_state_channel_test.dart:18`; `_FakeInstructionStream` at `:56` | ✅ Confirmed (incl. `noSuchMethod` at 53 / 67) |
| `FakeTickService` at `breath_session_state_machine_test.dart:10-32`; `makeExercise`/`makeSession` at `:38-63` | ✅ Confirmed (actual path `test/BreathModule/Presentation/BreathSession/...`) |
| Service/coordinator fakes at `breath_view_model_publication_test.dart:49-81` | ✅ Confirmed (incl. the `ProviderContainer` + `overrideWith` pattern at 113–126) |
| VM public controls at `BreathSessionViewModel.dart:276-286` (`pause`/`resume`/`complete`/`restartEngine`) | ✅ Confirmed |
| `ref.onDispose` at `BreathSessionViewModel.dart:78-88` | ✅ Confirmed (cancels subs, disposes SM + tick service, closes controller) |
| VM ctor `{tickService, service, coordinator, sessionId}`; `attachModuleChannel({onDispose, onReset})`; `vm.stream` getter; `initState()` | ✅ All confirmed |
| `BreathModuleStateChannel` ctor `{channel, stateStream, instructionStream, sessionId, stopwatchFactory?, clock?}` | ✅ Confirmed |
| Headless under plain `flutter test` (no platform bindings) | ✅ Confirmed — VM/Riverpod/`Stopwatch`/`DateTime.now` need no bindings |

## Context Gates

- **Architecture (ARCHITECTURE.md):** ✅ No boundary issue. This is test-only infrastructure that replicates the existing module-boundary wiring; it does not cross or weaken the domain/module seam.
- **Rules (RULES.md):** ✅ No violation. The rule "all dependencies injected via constructor" is honored — the harness reproduces `buildSession`'s constructor DI exactly (channel built inside the provider factory, wired via `attachModuleChannel`). No App.dart changes, no stateful module Service.
- **Roadmap (ROADMAP.md):** ✅ Linked. The milestone appears verbatim in Phase 58 ("Headless breath-activity test harness + seam audit", line 16) with `Spec: .ai-factory/notes/03-breath-headless-activity-harness.md` — the exact file Task 1 appends to. Forward reference `[[05-breath-derive-lifecycle-islive]]` is also a real roadmap entry / note. Milestone linkage is solid.

## Critical Issues

None. No missing migrations (test-only Flutter change), no security surface, no runtime-breaking API misuse.

## Findings (non-blocking)

### 1. WARN — `FakeTickService` spec omits the required `nominalIntervalMs` member (Task 2)
`ITickService` declares **five** members: `tickStream`, `source`, `nominalIntervalMs`, `sourceChanges`, `trySwitchTo`, `dispose`. The Task 2 bullet for `FakeTickService` enumerates every member **except `int get nominalIntervalMs`**. Because `ITickService` is a pure abstract interface (no `noSuchMethod` escape in the existing fakes), a fake that omits `nominalIntervalMs` will **not compile**.

The cited port source (`breath_session_state_machine_test.dart:10-32`) *does* implement it (`nominalIntervalMs => 1000` at line 20), so an implementer who ports faithfully will be fine — but the enumerated checklist should not silently drop a required member. **Fix:** add `nominalIntervalMs => 1000` (or similar) to the Task 2 `FakeTickService` bullet.

### 2. INFO — Imprecise framing of `ModuleStateChannel` / `BreathModuleInstructionStream` as "abstract interface" (Task 1)
Task 1 says every injected dependency is "reachable through an abstract interface." That is exact for the three `breath_module` interfaces, but `ModuleStateChannel` (`lib/Core/Grpc/ModuleStateChannel.dart`) and `BreathModuleInstructionStream` are **concrete classes**, not abstract interfaces. They are still fakeable — Dart synthesizes an implicit interface for every class, and the existing `_FakeChannel implements ModuleStateChannel` / `_FakeInstructionStream implements BreathModuleInstructionStream` (which rely on `noSuchMethod` to cover unimplemented members) prove it compiles. So the audit verdict ("fakeable, no extraction needed") holds; only the wording is loose. Worth a one-line clarification in the seam-audit note so the verdict isn't mistaken for "all seams are already declared interfaces."

Consequence for Task 2: the `FakeModuleStateChannel` and `FakeInstructionStream` ports **must keep the `noSuchMethod` override** (present in the cited ranges `:18-54` and `:56-68`). The plan's port-from references are correct; just don't drop `noSuchMethod` when consolidating.

### 3. INFO — Test-file citations are filename-only; full paths differ
The plan cites `breath_session_state_machine_test.dart` and `breath_view_model_publication_test.dart` by filename. Both actually live under `test/BreathModule/Presentation/BreathSession/`, not at `test/BreathModule/`. All line numbers verified accurate. Filenames are unique in the repo, so this won't mislead an implementer — noted only for precision.

### 4. INFO — `vm.stream` subscription timing for the recorded-state channel (Task 3)
`vm.stream` is a **broadcast** controller (`BreathSessionViewModel.dart:57`) — it does not replay past events. The first state emission (`SessionLoadState.ready` + initial `pause`) happens inside `await vm.initState()` → `_setupEngine`. If the harness subscribes to `vm.stream` *after* `initState()`, that initial emission is missed. The Task 4 smoke-test assertions (advance through phases, reach `complete`, see `start`→`end`) all hold regardless, because those occur during `resume → tick → complete` which run after subscription. But if a future characterization test (milestone 04) wants the *full* sequence including the initial state, the harness should subscribe **before** `initState()`. Cheap to do now: have the harness set up the recording subscription in its constructor/init, before driving. Worth a sentence in Task 3.

## Positive Notes

- **Correctly rejects the roadmap's loose "reuse `_FakeChannel`/`_FakeInstructionStream`" instruction.** Those are library-private (`_`-prefixed) classes in a test file and cannot be imported across test libraries. Task 2's consolidation into *public* fakes in `test/BreathModule/Fakes/` is the right call and an improvement over the roadmap wording.
- **Wiring replication is faithful.** The Task 3 factory shape (build VM → build channel with `stateStream: vm.stream` → `attachModuleChannel(onDispose: channel.dispose, onReset: channel.reset)` → return vm) matches `BreathModule.dart:46-55` exactly, including the subtle ordering where the channel subscribes to `vm.stream` before `build()` runs (safe — `_stateController` is a field initializer).
- **Dispose path is correct.** Disposing the `ProviderContainer` triggers `ref.onDispose` (`:78-88`), which the plan correctly identifies as the single teardown that cancels subscriptions, disposes the state machine + tick service, and closes the controller. `tearDown` placement in Task 4 is right.
- **Phased dependencies are sound** (audit → fakes → harness → smoke test), and the additive constraint ("do not modify existing test files") avoids destabilizing the large, well-pinned `breath_module_state_channel_test.dart` golden master.
- **`isLive` placeholder** is appropriately scoped as a typed getter not yet wired to real logic, correctly deferring to milestone 05.

## Recommendation

Proceed. Apply fix #1 (add `nominalIntervalMs` to the `FakeTickService` spec) before implementation; #2–#4 are clarifications that improve the note/harness but do not block. None require re-planning.
