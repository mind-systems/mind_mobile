# Plan: Invert lifecycle: end only on explicit finish (drop stop-on-dispose)

## Context
A child session must stay live on the server when the user navigates away from its screen, so concurrent children work (start breathing mid-meditation, meditation keeps running). Today both module adapters send `stop()` on `dispose()`, ending the session on screen exit — this plan removes that implicit teardown and keeps only the explicit-finish `end` paths.

## Settings
- Testing: no (only migrate existing characterization assertions to the inverted behavior — no new coverage)
- Logging: minimal
- Docs: no

## Navigation-path audit (recon result — no separate task)
Only two teardown `stop()` calls exist in the whole module surface, both in `dispose()`:
- `lib/BreathModule/Core/BreathModuleStateChannel.dart:171`
- `lib/MeditationModule/Core/MeditationModuleStateChannel.dart:74`

Both `dispose()` methods are invoked purely as Riverpod/screen teardown:
- Breath: `BreathModule.buildSession` wires `vm.attachModuleChannel(onDispose: channel.dispose, ...)` (`lib/BreathModule/BreathModule.dart:54-58`) — fires on provider dispose (screen exit).
- Meditation: `MeditationSessionScreen(onDispose: () { stateChannel.dispose(); keepAlive?.dispose(); })` (`lib/MeditationModule/MeditationModule.dart:59-62`) — fires on screen dispose.

No coordinator, screen pop, or route change sends `end`/`stop` independently. The explicit-finish `end` paths are the only remaining terminators and must be preserved:
- Breath: `→completed` transition → `_channel.end(...)` (`BreathModuleStateChannel.dart:117-123`).
- Meditation: `active → idle` transition → `_channel.end(...)` (`MeditationModuleStateChannel.dart:62-69`).

FGS/biometrics gating is explicitly out of scope and untouched.

## Tasks

### Phase 1: Drop dispose-time stop in both adapters

- [x] **Task 1: Remove dispose-time `stop()` in `BreathModuleStateChannel`**
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  In `dispose()` (`:168-176`), delete the `if (_started && !_ended) { logPrint(...); _channel.stop(sessionId: _childSessionId); }` block (`:169-172`). Keep the three `.cancel()` calls (`_stateSub`, `_channelSub`, `_eventsSub`). Do NOT touch the explicit-finish `end` path in `_handleLifecycle` (`→completed`, `:117-123`), the `reset()` method, the stopwatch, or instruction markers. After this, leaving the breath screen while a session is started-and-not-ended sends nothing — the child stays live.

- [x] **Task 2: Remove dispose-time `stop()` in `MeditationModuleStateChannel`**
  Files: `lib/MeditationModule/Core/MeditationModuleStateChannel.dart`
  In `dispose()` (`:73-78`), delete `if (_started && !_ended) _channel.stop(sessionId: _childSessionId);` (`:74`). Keep the three `.cancel()` calls. Do NOT touch the explicit-finish `end` path in `_onState` (`active → idle`, `:62-69`), the re-arm bookkeeping, or the `ModuleSessionAbandoned` reset handler.

### Phase 2: Migrate the golden-master test suites to the inverted behavior

- [x] **Task 3: Update `breath_module_state_channel_test.dart` dispose assertions** (depends on Task 1)
  Files: `test/BreathModule/breath_module_state_channel_test.dart`
  In the `dispose() / stop()` group (`:641`), flip the two assertions that now expect no stop: `breath -> dispose` (`:668-677`, was `stopCount, 1`) and `breath -> pause -> dispose` (`:680-690`, was `stopCount, 1`) must now assert `expect(f.channel.stopCount, 0)`. The cases already asserting `stopCount, 0` (before-emission, non-ready-only, after-complete) stay unchanged. Update each test description to reflect "does not call channel.stop on dispose". Leave the `dispose() subscription bookkeeping` group (`:1291`) as-is — subscription cancellation is unchanged.

- [x] **Task 4: Update `meditation_module_state_channel_test.dart` dispose assertions** (depends on Task 2)
  Files: `test/MeditationModule/meditation_module_state_channel_test.dart`
  In the `dispose` group (`:339`), flip the `should call channel.stop exactly once when dispose is invoked while the session is active` case (`:351-359`) to assert `expect(f.channel.stopCount, 0)` and rename it accordingly. The before-emission (`:341-347`) and after active-to-idle (`:363-373`) cases already assert `0` and stay. The post-dispose no-further-dispatch / moduleSessionId cases (`:377`, `:392`) verify subscription teardown and stay unchanged.
