# Code Review: Headless breath-activity test harness + seam audit

**Scope:** Test-only changes — three new files under `test/BreathModule/`, plus a seam-audit verdict appended to the note. No production code changed.

- `test/BreathModule/Fakes/BreathActivityFakes.dart` (new)
- `test/BreathModule/Support/BreathActivityHarness.dart` (new)
- `test/BreathModule/Support/breath_activity_harness_test.dart` (new)
- `.ai-factory/notes/03-breath-headless-activity-harness.md` (verdict appended)

## Verification performed

Each new file was read in full and cross-checked against the live production wiring it replicates.

| Claim under test | Source of truth | Result |
|---|---|---|
| Harness factory shape matches `BreathModule.buildSession()` (build VM → build channel with `stateStream: vm.stream` → `attachModuleChannel(onDispose: dispose, onReset: reset)`) | `lib/BreathModule/BreathModule.dart:34-60` | ✅ Faithful |
| `BreathModuleStateChannel` ctor params `{channel, stateStream, instructionStream, sessionId}` | `lib/BreathModule/Core/BreathModuleStateChannel.dart:32-43` | ✅ Match |
| `BreathViewModel` ctor `{tickService, service, coordinator, sessionId}`, `stream` getter (broadcast), `attachModuleChannel`, `initState`, `resume/pause/complete/restartEngine` | `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart:57,60,69-74,276-286` | ✅ Match |
| `ref.onDispose` cancels subs + disposes SM + tick service + closes controller | `BreathSessionViewModel.dart:78-88` | ✅ Confirmed — `container.dispose()` is the correct single teardown |
| Initial SM status is `pause`; `resume()` (non-rest phase) → `breath`; `complete()` → `complete` unconditionally | `BreathSessionStateMachine.dart:118,142,164-206,208-231` | ✅ Confirmed — smoke-test assertions hold |
| `FakeTickService` implements all 5 `ITickService` members incl. `nominalIntervalMs` (no `noSuchMethod` escape) | `BreathActivityFakes.dart:29-52` | ✅ Complete |
| `FakeModuleStateChannel` / `FakeInstructionStream` keep `noSuchMethod` (concrete classes faked via implicit interface) | `BreathActivityFakes.dart:98,129` | ✅ Present — channel SUT only calls explicitly-faked members, so `noSuchMethod` is never hit at runtime |
| `subscribe to vm.stream before initState()` so initial `ready` emission is captured | `BreathActivityHarness.dart:123-130`; `build()` does not emit, first emission is in `initState()→_setupEngine` | ✅ Correct ordering |
| Headless under plain `flutter test` (no platform bindings) | `ProviderContainer`, streams, `Stopwatch`, `DateTime.now`, `pumpEventQueue` need no widget binding | ✅ Confirmed |

### Smoke-test trace (manually walked)
`resume → tick×3 → complete` on the default session (inhale 2 + exhale 2, cycle = 4 ticks, repeat 1):
1. `init()` emits `pause/ready` → recorded; channel sees pause, no lifecycle call.
2. `resume()` emits `breath/ready` → `wasPaused && isActive && !_started` ⇒ `channel.start(...)`, `_started=true`. `startCalls` length 1. ✅
3. 3 ticks advance phase within `breath` (active↔active) — no spurious start/end. Cycle not exhausted (3 < 4), so no auto-complete. ✅
4. `complete()` emits `complete/ready` → `_started && !_ended` ⇒ `channel.end(...)`, `endCount=1`. `states.last.status == complete`. ✅
5. `tearDown` → `dispose()` → `ref.onDispose`; session already `_ended`, so `channel.stop()` is correctly **not** called.

All three assertions in the smoke test are satisfied. No `ModuleState` is seeded, so `_moduleSessionId` stays null and no `sendSample` fires — the test asserts only `start`/`end`, so this is consistent (not a gap).

## Findings

No bugs, security issues, or correctness problems. The changes are test-only, additive, and do not modify the existing golden-master suites.

### Non-blocking observations (no action required)

1. **`overrideWith(() => _vm)` returns a pre-built Notifier instance.** `BreathModule.buildSession` constructs the VM *inside* the factory; the harness constructs it outside and returns the same instance. Functionally identical for the harness's single-read, no-invalidation lifecycle (Riverpod binds `ref` and calls `build()` once). If a future test ever invalidates/rebuilds this provider, the factory would hand back an already-built Notifier and Riverpod would re-`build()` it — which can throw. Not reachable today; worth a one-line caveat if the harness grows a "restart container" capability. (`BreathActivityHarness.dart:119`)

2. **States-recorder subscription is never explicitly cancelled.** `_vm.stream.listen(states.add)` (`:130`) relies on `_stateController.close()` during dispose to terminate it. Correct and leak-free for a broadcast controller — flagged only for completeness.

3. **Doc/setup ergonomics.** The class doc describes a "two-phase setup" (`BreathActivityHarness()` then `await init()`), which the smoke test follows. The constructor does substantial wiring; this is fine for a test helper and matches the note's spec. No change needed.

## Context gates

- **RULES.md:** ✅ Honored — all deps injected via constructor; the channel is wired through `attachModuleChannel` exactly as production does; no `App.dart` changes; fakes carry no production state.
- **ARCHITECTURE.md:** ✅ Test-only infrastructure replicating the existing module-boundary wiring; no seam crossed or weakened.
- **Seam audit verdict:** ✅ The note correctly records that all five injected dependencies are fakeable (three declared interfaces + two concrete classes fakeable via implicit interface + `noSuchMethod`) and that no interface extraction was required — matching the production wiring read during this review.

REVIEW_PASS
</content>
