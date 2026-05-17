# Plan Review: Add tick one-shot sounds to `BreathSoundCoordinator`

**Plan file:** `.ai-factory/plans/70-add-tick-one-shot-sounds-to-breathsoundcoordinator.md`
**Risk Level:** 🟢 Low

## Context Gates

- **ARCHITECTURE.md** — no boundary violations. `BreathSoundCoordinator` lives inside the `breath_module` package and continues to operate only on `BreathSessionViewModel` + `BreathSessionState` (a DTO). No domain-model leak. ✓
- **RULES.md** — Project rule about stateless Module Services does not apply: this is a **Coordinator**, not a Service. The added `StreamSubscription` and `dispose` plumbing is consistent with the existing `_stateListener` pattern. ✓
- **ROADMAP.md** — milestone 12.5 (`tickSource` on state) is noted as prerequisite and confirmed by `BreathSessionState.tickSource` at line 38 of `Models/BreathSessionState.dart`. ✓

## Codebase Verification

Verified against `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`:
- `_player` field rename targets (lines 10, 28, 29, 36–39, 50, 52, 108–113, 122–131) are exactly those listed in Task 1. ✓
- `viewModel.tickStream` exists on `BreathSessionViewModel` (line 229, returns `Stream<void>`). ✓
- `state.tickSource` exists with default `TickSource.timer` (matches `_currentTickSource` initial value). ✓
- `TickSource` enum is at `packages/breath_module/lib/src/CommonModels/TickSource.dart` — relative import `../../CommonModels/TickSource.dart` from `Audio/` is correct. ✓
- Asset files exist: `assets/audio/tick_clock.wav` and `assets/audio/tick_heartbeat.wav` in the consuming app, with `assets/audio/` declared in root `pubspec.yaml` line 104. ✓
- Existing `_phaseAssets` use the same asset-path convention (`'assets/audio/ohm_*.wav'`) and are resolved via `just_audio`'s `setAsset` against the app's asset bundle — pattern matches. ✓

## Findings

### Minor Issues

1. **`late AudioPlayer _tickPlayer` changes lifecycle robustness vs the existing nullable `_loopPlayer`.**
   The existing code makes `_player` nullable so that `reset()` and `dispose()` can be called safely even if `initialize()` was never called (both methods read into a local `final player = _player;` and null-check). The plan introduces `late AudioPlayer _tickPlayer;`. If `reset()` or `dispose()` is invoked before `initialize()`, `_tickPlayer.stop()` / `_tickPlayer.dispose()` will throw `LateInitializationError`.
   Suggest one of:
   - Make it nullable: `AudioPlayer? _tickPlayer;`, guard with local `final p = _tickPlayer; if (p != null) ...` — matches the existing pattern.
   - Or add `bool _initialized = false;` gate so reset/dispose early-return when not initialized.
   The screen wires init/dispose symmetrically today, but mirroring the existing nullable convention removes a footgun.

2. **Race between fire-and-forget `_loadTickAsset` and the first tick.**
   `unawaited(_loadTickAsset(_currentTickSource))` returns immediately; `setAsset` does real I/O. If `_onTick` fires before the asset finishes loading (e.g., the very first tick after `initialize`), `_tickPlayer.seek(Duration.zero).then(play)` runs against an empty source. In practice `just_audio` either queues or logs a benign warning, but consider awaiting load on first attach — or accept the silent first tick as part of the design and call it out in the plan.

3. **Tick-source change during active playback.**
   Task 4 calls `_loadTickAsset` synchronously after a change. If a tick is mid-playback when this fires, `setAsset` interrupts. The plan correctly notes this branch is expected to fire only during restart (cold path), so impact is negligible — no action needed, but worth confirming the assumption holds across all `restartEngine()` paths.

### Non-Issues / Confirmed Safe

- **`reset()` deliberately keeps `_tickSub` alive** — correct. After `restartEngine()`, the next `_onStateChanged` repopulates `_currentStatus`/`_currentPhase`, and `_onTick` correctly silences itself until then because both mirrors are reset to `null` (neither branch of the guard matches `null`).
- **Re-entrant `initialize()` is still guarded** — `if (_loopPlayer != null) return;` (renamed) sits at the top of `initialize`, so the new tick setup also short-circuits on repeat calls. ✓
- **`dispose()` ordering** — plan explicitly cancels `_tickSub` before disposing `_tickPlayer`, preventing a late tick from racing against a disposed player. ✓
- **`_onTick` guard order** — `_currentStatus` is only assigned inside `_onStateChanged` *after* the `loadState != ready` gate, so ticks arriving before the first ready state see `_currentStatus == null` and bail out. No load-state check needed in `_onTick`. ✓
- **No new asset registration needed** — `assets/audio/` is already declared in root `pubspec.yaml`; the new `.wav` files are already on disk. ✓
- **`BreathSoundCoordinator` is package-internal** — the rename `_player → _loopPlayer` has no external callers. Confirmed via the existing field being private and used only inside the file.

## Positive Notes

- Clean separation: one player for looping phase audio, a separate one for one-shot ticks. Avoids interfering with the existing fade/loop logic entirely.
- The `_currentTickSource` mirror + diff-on-change pattern mirrors the existing `_currentPhase`/`_currentStatus` style — consistent with the file's idiom.
- Fire-and-forget `setAsset` keeps the tick handler hot path (seek + play) cheap, which is the right trade-off for a per-tick handler.
- Plan correctly identifies that ticks must keep firing across `reset()` (restart) and only be cancelled in `dispose()`.

## Recommendation

Address Finding #1 (nullable `_tickPlayer` to mirror `_loopPlayer`) before implementation; #2 and #3 are acceptable as designed but should be acknowledged in the implementer's mind. Plan is otherwise complete, accurate, and well-scoped.

PLAN_REVIEW_PASS
