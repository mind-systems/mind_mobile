# Plan: Give-up-surface golden-master tests

## Context
Lock the three silently-failing give-up surfaces of task 26 (type-scoped adapter reset, carried-path budget enforcement, `SessionStartFailed` emission + snackbar wire) with additive golden-master tests that go **green on the current committed tree** (carrying the `93f3e92` give-up behaviour) — so note 28's pending-start state lift can refactor the internals under a pinned contract. The deliverable is test code only; **no production code changes**, and no existing assertion in `start_race_contract_test.dart` may be weakened.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Reference material (read before implementing)
- Spec note: `.ai-factory/notes/27-rootchild-startrace-giveup-golden-master.md` (the three surfaces, the exact scenarios, and the guards).
- Existing golden master + pumping style: `test/Core/Grpc/start_race_contract_test.dart` — `fakeAsync` + `async.flushMicrotasks()` after every frame push / `async.elapse(...)`; local `_starts(call)` helper; `f.channel.dispose()` at the end of every test.
- Shared harness (do **not** modify): `test/Core/Grpc/Support/reconnect_concurrency_harness.dart` — provides `wireConcurrent()` (one real `ModuleStateChannel` + both real adapters), `connectAndFlush`, `disconnectAndFlush`, `runningBreathState()`, `activeMeditationState()`, `childActiveFrame(type, id)`.
- Production surfaces under test (read-only, for behaviour): give-up path `lib/Core/Grpc/ModuleStateChannel.dart` — `_onConfirmTimeout` (`:502`, 3-attempt budget, 5s confirm timer), `_giveUp` (`:523`), `_resolveSettling` carried-path give-up (`:563-571`); type-scoped reset `lib/BreathModule/Core/BreathModuleStateChannel.dart:52-60` and `lib/MeditationModule/Core/MeditationModuleStateChannel.dart:34-42`; snackbar wire `lib/Core/App.dart:323` (`events.where((e) => e is SessionStartFailed).map((_) {})` → `GlobalListeners.sessionStartFailedStream`).

## Key mechanics (observed, for the implementer)
- **Give-up budget:** `channel.start(...)` sends attempt 1 immediately; each 5s confirm-timeout with no confirming frame (while `isConnected`) sends the next attempt; on the timeout after attempt 3, `_giveUp(type)` removes the pending and emits `SessionStartFailed(type)`. So driving a start then `async.elapse(Duration(seconds: 5))` **three** times (total 15s) reaches give-up.
- **Observable "still live" seam:** each adapter exposes a public `moduleSessionId` getter; a confirming `childActiveFrame(type, id)` sets `channel.state`'s `moduleSessionId`, which the adapter records via its `channel.state` listener → `adapter.moduleSessionId == id`. On `reset()`/`_reset()` it becomes `null`. This is the golden-master seam — no private field access needed.
- **Carried-path give-up:** with an unconfirmed breath start at 3 attempts, a `disconnected` → `connected` cycle opens a reconnect settling window (`_settlingActive`, carried timers cancelled); when the 3s window closes, `_resolveSettling` sees `attempts >= 3` and calls `_giveUp` instead of a 4th `_sendStart`.
- **Snackbar wire:** the exact App.dart:323 transform is `channel.events.where((e) => e is SessionStartFailed).map((_) {})`. Reproduce that transform in the test and assert it emits when give-up fires — this pins the stream feeding `GlobalListeners` without standing up a widget.
- **Ordering pin:** always `connectAndFlush(f, async)` before driving any adapter state, or `channel.start` is dropped by the null-sink guard (see the `wireConcurrent` doc comment).

## Tasks

### Phase 1: Golden-master coverage

- [x] **Task 1: New sibling test file + type-scoped adapter reset tests**
  Files: `test/Core/Grpc/start_race_giveup_contract_test.dart` (new)
  Create a sibling test file in the same directory, importing the shared harness (`Support/reconnect_concurrency_harness.dart`), `ModuleStateChannel`, `ModuleStateEvent` (`SessionStartFailed`), `ActivityType`, and the generated proto — mirroring the import block and `fakeAsync` pumping style of `start_race_contract_test.dart`. Add local helpers only (do not touch the harness): a `_starts(call)` copy and a small `_collectFailures(channel)` that subscribes to `channel.events` and pushes each `SessionStartFailed` into a list.
  Add a group `give-up surface — type-scoped adapter reset (note 27)` with two tests:
  1. *Meditation give-up must not reset a live breath session.* `wireConcurrent()` → `connectAndFlush` → drive `runningBreathState()` and confirm it with `childActiveFrame(proto.ActivityType.BREATH, 'breath-1')` (asserts `f.breathAdapter.moduleSessionId == 'breath-1'`). Then drive `activeMeditationState()` to arm a meditation start, and `async.elapse(Duration(seconds: 5))` three times (flushing microtasks each time) to force the meditation give-up. Assert a `SessionStartFailed` for meditation was emitted **and** `f.breathAdapter.moduleSessionId == 'breath-1'` (the live breath session was not cleared).
  2. *Breath give-up must not reset a live meditation session (symmetric).* Confirm a live meditation child with `childActiveFrame(proto.ActivityType.MEDITATION, 'med-1')`, drive `runningBreathState()` to arm a breath start, elapse 3×5s to force the breath give-up. Assert `SessionStartFailed` for breath emitted **and** `f.meditationAdapter.moduleSessionId == 'med-1'`.
  End each test with `f.channel.dispose()`. Add a header comment stating this is additive golden-master coverage (note 27) that must be green on the current tree, and that the assertions lock the `event.type == ...` filter in each adapter.

- [x] **Task 2: Carried-path budget enforcement test**
  Files: `test/Core/Grpc/start_race_giveup_contract_test.dart`
  Add a group `give-up surface — carried-path budget (note 27)` with one test: `wireConcurrent()` → `connectAndFlush` → subscribe with `_collectFailures` → drive `runningBreathState()` (attempt 1 on the wire). `async.elapse(Duration(seconds: 5))` twice (attempts 2 and 3) — do **not** elapse a third time (that would trigger the `_onConfirmTimeout` give-up before the reconnect). Then `disconnectAndFlush(f, async)` and `f.connManager.pushConnected()` + flush to open a reconnect settling window while the carried pending survives at 3 attempts. `async.elapse(Duration(seconds: 3))` to close the settling window.
  Assert: total `activityStart`s across **all** `f.service.calls` (sum `_starts(call).length` over `f.service.calls`) is `<= 3` — no 4th send — **and** exactly one `SessionStartFailed(breath)` was collected (the carried budget gave up via `_resolveSettling` → `_giveUp`, not a re-send). End with `f.channel.dispose()`. Comment the test as pinning the INV-12 overshoot that review 2 caught reactively.

- [x] **Task 3: Give-up emission + snackbar-wire test**
  Files: `test/Core/Grpc/start_race_giveup_contract_test.dart`
  Add a group `give-up surface — SessionStartFailed emission + snackbar wire (note 27)` with one test: `wireConcurrent()` → `connectAndFlush`. Subscribe two collectors before driving anything: (a) `_collectFailures(f.channel)` for the typed events, and (b) a collector on the **exact App.dart:323 transform** `f.channel.events.where((e) => e is SessionStartFailed).map((_) {})` to prove the snackbar-feeding stream fires. Drive `runningBreathState()`, elapse 3×5s to force give-up.
  Assert: the typed collector holds a `SessionStartFailed` whose `type == ActivityType.breath` (correct type), **and** the transform collector emitted exactly one unit event (the `GlobalListeners.sessionStartFailedStream` path is reached). Add a comment: INV-12's existing test only bounds wire count `<= 3` and never asserts the give-up event or the snackbar wire — this closes that gap. End with `f.channel.dispose()`.

## Verify
- `flutter test test/Core/Grpc/` (full path `/usr/local/bin/flutter`) is green — the three new tests plus every pre-existing test in `start_race_contract_test.dart` — on the current tree, with **no production code change**.
