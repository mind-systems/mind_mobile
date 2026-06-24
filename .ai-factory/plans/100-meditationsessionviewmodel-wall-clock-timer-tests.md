# Test Plan: MeditationSessionViewModel wall-clock timer tests

## Context
`packages/meditation_module/lib/src/MeditationSession/MeditationSessionViewModel.dart` is a Riverpod `Notifier<MeditationSessionState>` that manages a meditation session timer. `start()` captures `_startedAt = _clock()` and arms a 1-second periodic timer; each timer fire recomputes elapsed time as a **wall-clock delta** (`_clock().difference(_startedAt!).inSeconds`) rather than a `++` accumulator. There are currently zero tests for this file. The core regression guard: advancing the fake clock by 30 s while firing only 5 timer callbacks must yield `30`, not `5`.

> **IMPORTANT DISCREPANCY — read before writing assertions.** The milestone wording says `state.elapsedSeconds == 30`. The actual code does **not** store elapsed time on the state object. `MeditationSessionState` has only two fields: `status` (`idle`/`active`) and `poseId`. Elapsed time lives on a public `ValueNotifier<int>` exposed as `vm.elapsedSeconds`. **All elapsed-time assertions must read `vm.elapsedSeconds.value`, never `state.elapsedSeconds`.**

### Test Infra status (prerequisite already satisfied)
The constructor already exposes the two injection seams the milestone requires — no refactor needed:
```dart
MeditationSessionViewModel({
  required this.poseId,
  DateTime Function() clock = DateTime.now,
  Timer Function(Duration, void Function(Timer)) timerFactory = Timer.periodic,
})
```
Note the `timerFactory` callback type is `void Function(Timer)` (Timer.periodic style), **not** `void Function()` as in `ActiveRrSource`. The spy must capture a `void Function(Timer)` and pass the fake timer back in when firing it.

### Test harness guidance (use the `active_rr_source_test.dart` pattern)
- **Mutable clock holder:** a `late DateTime now;` variable; pass `clock: () => now;`. Advance simulated time by reassigning `now` (e.g. `now = now.add(const Duration(seconds: 30))`).
- **Spy timer factory + fake timer:** mirror `_FakeTimer` (tracks `cancelled` / `isActive`) and a `spyFactory` that captures `(Duration, void Function(Timer))` into lists. To "fire a tick", call the captured callback manually with the fake timer instance. This is what decouples clock-advance count from callback-fire count — `fake_async`'s `elapse` couples them and **cannot** express "advance 30 s, fire 5 times", so prefer the manual fake. No new package dependency is required.
- **Mounting the Notifier:** `start()`/`stop()` assign `state`, which requires the notifier to be mounted by Riverpod, and `build()` calls `ref.onDispose`. Construct via a `ProviderContainer` with `meditationSessionViewModelProvider.overrideWith(() => MeditationSessionViewModel(...))`, then `container.read(...notifier)` to get the VM (this triggers `build()`) and `container.read(provider)` for state. Register `addTearDown(container.dispose)`.
- **Import** the VM via `package:meditation_module/meditation_module.dart` (re-exports `MeditationSessionViewModel`, `MeditationSessionState`, `MeditationSessionStatus`, and the provider).
- `_startedAt` is private and not directly observable — verify it indirectly through the elapsed-delta behavior described in each task.

## Settings
- Testing: yes
- Logging: minimal
- Docs: no

## Test Command
`/usr/local/bin/flutter test test/MeditationModule/meditation_session_viewmodel_timer_test.dart`

## Target Spec File
`test/MeditationModule/meditation_session_viewmodel_timer_test.dart` (app-level test dir, alongside the existing `meditation_module_state_channel_test.dart`)

## Tasks

### Phase 1: MeditationSessionViewModel — start() arming & clock capture

- [x] **Task 1: `start()` arms timer, captures start instant, and activates**
  Files: `test/MeditationModule/meditation_session_viewmodel_timer_test.dart`
  Test cases:
  - `should set status to active when start() is called` (read `container.read(provider).status == MeditationSessionStatus.active`)
  - `should reset elapsedSeconds to 0 when start() is called`
  - `should arm exactly one periodic timer with a 1-second interval when start() is called` (assert spy captured one timer with `Duration(seconds: 1)`)
  - `should capture _startedAt from clock() at start so the first fire counts from that instant` (set `now = T`, `start()`, advance `now` to `T + 3s`, fire the captured callback once → `elapsedSeconds.value == 3`)
  - `should emit the active state to the stream when start() is called` (listen to `vm.stream`, expect a `MeditationSessionState` with `status == active`)

### Phase 2: MeditationSessionViewModel — timer callback wall-clock delta (core regression guard)

- [x] **Task 2: timer callback recomputes elapsedSeconds as `now − startedAt`**
  Files: `test/MeditationModule/meditation_session_viewmodel_timer_test.dart`
  Test cases:
  - `should set elapsedSeconds to the wall-clock delta on each timer fire` (advance `now` to `+5s`, fire once → `5`; advance to `+9s`, fire again → `9`)
  - `should report 30 when clock advances 30s but only 5 callbacks fire` (KEY GUARD: `start()` at `T`, set `now = T + 30s`, fire the captured callback 5 times → `elapsedSeconds.value == 30`, proving wall-clock delta, not a per-fire accumulator that would give `5`)
  - `should recompute from the delta and ignore externally mutated elapsedSeconds when a tick fires` (after a fire, set `vm.elapsedSeconds.value = 99`, advance `now` to `+2s`, fire → `2`, not `100`; guards against an accidental `++` accumulator revert)
  - `should read the same _startedAt for multiple fires in rapid succession with no clock change` (advance `now` to `+4s`, fire 3 times back-to-back without changing `now` → `elapsedSeconds.value == 4` after each fire)
  - `should monotonically increase elapsedSeconds across successive fires as the clock advances` (fire at `+1s`→1, `+2s`→2, `+10s`→10; never backslides)

### Phase 3: MeditationSessionViewModel — stop() teardown

- [x] **Task 3: `stop()` cancels the timer, clears start instant, and idles**
  Files: `test/MeditationModule/meditation_session_viewmodel_timer_test.dart`
  Test cases:
  - `should cancel the armed timer when stop() is called` (assert the captured `_FakeTimer.isActive == false` / `cancelled == true` after `stop()`)
  - `should set status to idle when stop() is called`
  - `should preserve the last elapsedSeconds value after stop()` (advance to `+3s`, fire → 3, `stop()` → `elapsedSeconds.value` is still `3`; `stop()` does NOT reset to 0 by design)
  - `should emit the idle state to the stream when stop() is called`
  - `should clear _startedAt so no further elapsed updates occur after stop()` (verify indirectly: after `stop()` the timer is cancelled, so advancing `now` and not re-firing leaves `elapsedSeconds.value` unchanged; do not manually fire a cancelled timer's callback — that would dereference the now-null `_startedAt`)

### Phase 4: MeditationSessionViewModel — restart after stop()

- [x] **Task 4: `start()` after `stop()` re-captures a fresh start instant**
  Files: `test/MeditationModule/meditation_session_viewmodel_timer_test.dart`
  Test cases:
  - `should reset elapsedSeconds to 0 when start() is called again after stop()`
  - `should re-arm a fresh periodic timer on restart` (spy captured a second timer; the new one is active)
  - `should re-capture _startedAt from the current clock on restart` (first cycle: start at `T`, advance to `T+3s`, fire → 3, `stop()`; advance the gap so `now = T+10s`, `start()` again, advance to `now = T+12s`, fire → `2`, proving elapsed counts from the new start instant, not the original `T`)
  - `should set status back to active on restart`
