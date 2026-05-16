# Plan Review: Create `BreathSoundCoordinator`

**Plan file:** `.ai-factory/plans/66-create-packages-breath-module-lib-src-breathsession-audio-breathsoundcoordinator-dart.md`
**Risk:** 🟢 Low

## Verified against codebase

- `packages/breath_module/lib/src/BreathSession/Animation/BreathAnimationCoordinator.dart` — confirms the lifecycle template the plan mirrors (constructor → `initialize(initialState)` → `_onStateChanged` listener via `viewModel.listen(...)` → `reset()` / `dispose()` that calls `_stateListener?.call()`).
- `BreathViewModel.listen(...)` (in `BreathSessionViewModel.dart`) returns `void Function()` — matches the plan's `_stateListener` field type.
- `BreathSessionState` exposes every field the plan reads: `loadState`, `status`, `phase`, `remainingTicks`, `currentIntervalMs`. Enums (`SessionLoadState.ready`, `BreathSessionStatus.{pause,breath,rest,complete}`, `BreathPhase.{inhale,hold,exhale,rest}`) all exist.
- `packages/breath_module/pubspec.yaml` already declares `just_audio: ^0.10.5` (milestone 12.1 ✅).
- Audio assets exist at `assets/audio/ohm_inhale.wav`, `ohm_exhale.wav`, `ohm_hold.wav` and `assets/audio/` is declared in the root `pubspec.yaml` (12.2 ✅). Reading those assets from inside the package with `_player.setAsset('assets/audio/...')` (no `package:` prefix) resolves to the host app's manifest — correct.
- `Audio/` directory does not exist yet — Task 1 creates it.
- `static const Map<BreathPhase, String>` with enum keys is valid Dart (Dart 2.13+ supports const maps keyed by enums).

## Context gates

- **ARCHITECTURE.md** — no boundary violations. The coordinator lives inside `packages/breath_module/lib/src/BreathSession/` alongside `Animation/`, depends only on the in-package `BreathViewModel` and state model, and never reaches into `lib/`. Consistent with the documented "package = self-contained presentation layer" rule.
- **RULES.md / project conventions** — folder-naming (PascalCase `Audio/`), file-naming (`BreathSoundCoordinator.dart`), and import-style (relative `../...`) all match `BreathAnimationCoordinator` precedent. No `flutter pub` manipulation of `pubspec.yaml` is required (assets and dep are already in place).
- **ROADMAP.md** — plan corresponds 1:1 to milestone **12.3**. Out-of-scope work (wiring into screen = 12.4, tick sounds = 12.6) is explicitly deferred — matches the plan's Context paragraph.

## Issues found

### 🟡 Minor — initial-emission audio lag

Task 3 says "Leave `_currentPhase` and `_currentStatus` `null` so the first event in `_onStateChanged` triggers the appropriate transition." Given the early-`return` ladder in Task 4, the first event does **not** trigger a phase load — the status branch consumes it. Worst-case trace on session start:

1. Emission #1 (load → ready, status=pause, phase=inhale): status branch fires (`null → pause`), `_fadeTo(0.0, 200ms)`, **return**. `_currentPhase` is still `null`.
2. User taps play → emission #2 (status=breath, phase=inhale): status branch fires (`pause → breath`), `_fadeTo(1.0, 200ms)` on a player with **no asset loaded**, **return**.
3. Emission #3 (next tick, status=breath, phase=inhale): status unchanged, phase branch finally fires, `_switchToPhase(inhale)` loads the asset and starts playback.

Effect: ~1 tick of silence at the start of the first inhale, and a `setVolume(1.0)` call on an empty player. Not a bug, but the plan's wording promises behavior the logic doesn't deliver. Options for the implementer:

- Accept and update the comment in Task 3 to reflect the two-emission warm-up.
- Or, in Task 4 status-change branch, when transitioning to `breath` and `_phaseAssets.containsKey(state.phase)` and `state.phase != _currentPhase`, fall through to the phase branch (i.e., set `_currentPhase = state.phase; _switchToPhase(state.phase);`) before returning. One extra `if` covers the warm-up.

Either resolution is acceptable; I'd recommend option 2 since the cost is trivial.

### 🟡 Minor — `_player.volume` getter at `_fadeTo` entry

`AudioPlayer.setVolume(v)` returns `Future<void>` and is called fire-and-forget throughout. The `volume` getter on `just_audio` reflects the last-issued value synchronously (cached in plugin state), so capturing `startVolume = _player.volume` at the start of a new fade is safe. Worth noting because if a future migration replaces `just_audio` with a plugin that defers state, this assumption breaks. Not blocking.

### 🟢 Informational — fade-out re-trigger on every remaining tick

Tasks 4.4 will re-arm `_fadeTo(0.0, remainingTicks*intervalMs)` on each of the last 3 ticks (3→2→1). Each call cancels the previous timer and starts a shorter fade from the current (lower) volume, which collapses to a clean continuous fade. Intentional and correct — flagging only so reviewers don't mistake it for a bug.

### 🟢 Informational — `discarded_futures` lint

Task 4 calls `_switchToPhase(state.phase);` without `await` and without `unawaited(...)`. Task 7 already accounts for this via `unawaited` / `// ignore: discarded_futures`. Same applies to `_player.stop()` / `_player.setVolume(0.0)` in `reset()` and `_player.setLoopMode(...)` in `initialize()`. Task 7's scope covers them.

### 🟢 Informational — player keeps looping inaudibly after rest/complete

The plan fades volume to 0 on `complete` / `rest` but never calls `_player.stop()`. Background looping at volume 0 is wasteful but won't leak (dispose handles it). Acceptable for this milestone; tick-sound milestone (12.6) can revisit if power profiling shows it matters.

## Positive notes

- Lifecycle parity with `BreathAnimationCoordinator` (initialize / reset / dispose, `_stateListener` cancel pattern) is exact — easy to wire later and to reason about.
- Early-return ladder in `_onStateChanged` keeps the branches mutually exclusive and easy to audit.
- Asset-path approach (host-app paths, no `package:` prefix) matches the explicit roadmap 12.2 note and avoids duplicating assets inside the package.
- Out-of-scope wiring (12.4 / 12.6) is correctly excluded; this milestone produces exactly one new file.
- Volume bounds analysis in Task 5 is correct — linear interpolation between two `[0,1]` endpoints stays in `[0,1]`.

PLAN_REVIEW_PASS
