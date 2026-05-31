# Code Review: Implement `MeditationModuleStateChannel` adapter

**Plan:** `.ai-factory/plans/98-implement-meditationmodulestatechannel-adapter.md`
**Changed file under review:** `lib/MeditationModule/Core/MeditationModuleStateChannel.dart` (new)

## Scope of changes

`git status` / `git diff HEAD` show four added files; only one is code:

- `lib/MeditationModule/Core/MeditationModuleStateChannel.dart` — the adapter (reviewed in full).
- `.ai-factory/plans/...md`, `.ai-factory/plans/...json`, `.ai-factory/plan-reviews/...md` — process artifacts, no runtime impact.

## Verification against dependencies (read in full)

- **`ActivityType.meditation`** — exists (`lib/Core/Grpc/ActivityType.dart`). `ModuleStateChannel._mapActivityType` maps it to `proto.ActivityType.MEDITATION`. ✓
- **`ModuleStateChannel` API** — `start({required ActivityType type, String? refId})`, `end()`, `stop()` exist with the exact signatures used (`lib/Core/Grpc/ModuleStateChannel.dart:151,174,179`). ✓
- **Session types** — `MeditationSessionStatus { idle, active }` and `MeditationSessionState` exist as imported, exported from the package barrel (`meditation_module.dart:7`). ✓
- **VM stream** — `MeditationSessionViewModel.stream` is a broadcast `Stream<MeditationSessionState>`; `build()` returns the initial `idle` state **without** adding it to the controller, and `set state` guards `!_stateController.isClosed` before adding (`MeditationSessionViewModel.dart:11-27`). ✓
- **Dependency wiring** — `meditation_module` is a path dependency in `pubspec.yaml:45-46`, so the import resolves from `lib/`. ✓

## Correctness analysis

- **First-transition handling is correct.** `_previousStatus` starts `null`. The initial `idle` state is never emitted on the stream, so the adapter's first event is the first real change (the `idle → active` produced by `start()`). `active != null` clears the dedup guard, then `active && !_started` opens the session. No spurious early `end()` because the `idle` branch requires `_started`. ✓
- **`end()` fires exactly once** on `active → idle` (Stop button), guarded by `_started && !_ended`. ✓
- **`dispose()` is correct.** It calls `stop()` only when a session was started and not yet ended — so a normal Stop-then-pop is a no-op (server already got `end()`), while popping while still active interrupts the session via `stop()`. Matches spec §C lifecycle reasoning. ✓
- **No leaks.** The single broadcast subscription is cancelled in `dispose()`, which is wired to the screen's `onDispose` in the downstream assembly task. `set state`'s closed-controller guard prevents post-dispose `add` errors. ✓
- **Deliberate omissions honored.** No instruction stream, no `channel.state` subscription / `moduleSessionId` / pending logic, no pause/resume, no phase tracking, no `reset()`, no `ModuleState` import — all correctly absent, consistent with meditation having no ticks/instructions/restart.

## Runtime-break checks

- No migrations, no schema, no generated code involved.
- No type mismatches — all method signatures and enum members confirmed against source.
- No race condition: a single listener on a per-screen broadcast stream; state mutation is synchronous on the platform thread.
- Shared-channel contention (e.g. starting meditation while a breath activity is active) is governed by `ModuleStateChannel.start`'s own pending/active guard and is out of scope for this adapter — behaviorally identical to the breath adapter.

## Observations (non-blocking)

- **No in-screen restart by design.** After one `start → end` cycle, `_started` stays `true`, so tapping play again will not open a second server activity within the same adapter instance. This is intended (spec §C: "no restart in meditation"); each navigation into the session builds a fresh `ProviderScope` → fresh VM → fresh adapter, so users do not hit this in practice. Noted only so it is not mistaken for a bug.
- **`_stateSub.cancel()`** returns a `Future` that is intentionally not awaited in the `void dispose()` — same fire-and-forget pattern as the breath adapter; harmless.

The implementation is a faithful, correct lifecycle-only strip of `BreathModuleStateChannel`. No bugs, security issues, or correctness problems found.

REVIEW_PASS
