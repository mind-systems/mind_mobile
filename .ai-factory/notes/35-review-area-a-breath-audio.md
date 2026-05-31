# Code Review — Area A: Breath Audio Engine (Phases 12–13)

**Date:** 2026-05-31
**Source:** conversation context (roadmap review, branch `bci-integration`)
**Scope:** `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`, `packages/mind_audio/lib/src/{audio_looper,audio_one_shot,audio_catalog,audio_track}.dart`

## Verdict

Core mechanics are correct and match the documented Phase 12 bug history. Ping-pong crossfade, generation guard, immediate outgoing fade, `_loadFuture` await before seek, and disposal guards all hold up. Findings below are cleanup + one moderate concurrency risk — no crashers, no silent-audio regressions spotted in static read.

## Key Findings

- **[Moderate] Tick-source change re-buffers the one-shot unawaited, with no guard against a concurrent `play()`.** In `BreathSoundCoordinator._onStateChanged` step 2, a `tickSource` change fires `_oneShot.load(src)` (→ `_player.setAudioSource`) fire-and-forget. Meanwhile `_onTick` calls `_oneShot.play()` (seek+play on the *same* player) on the live tick stream. With the Phase 22 heart-button toggling source at runtime, a fast double-toggle can race `setAudioSource` against `play()` → a glitched/no-op tick (not a crash). No re-entrancy guard or load-in-flight flag exists.
- **[Low / cleanup] Leftover debug instrumentation in `BreathSoundCoordinator`.** The `_ts()` helper + numerous `if (kDebugMode) debugPrint('${_ts()} [Sound] ...')` lines (initialize, status, phase, `_onTick`) survive. Phase 16 explicitly stripped `[BREATH-PROBE]` logs; these `[Sound]` logs are the same class of throwaway instrumentation and should go (or move behind a single trace flag).
- **[Low / simplification] `AudioCatalog` + `AudioTrack` are now near-vestigial.** After the Phase 13 FLAC migration removed `.meta.json`/`ClippingAudioSource`, `AssetAudioCatalog.sourceFor` is a one-liner (`AudioSource.asset(track.assetPath)`) and `AudioTrack` wraps a single `String assetPath`. The abstraction is a harmless extension seam but no longer earns its keep; candidate to inline if no second catalog type is planned.
- **[Low / brittleness] `fadeOut`/`fadeIn` use `_activePlayer!` non-null assertion.** Safe under current lifecycle (the state listener is cancelled before `_looper.dispose()` nulls the players), but a future caller invoking a fade post-dispose would hit a null-check throw. Cheap to make null-safe.

## Details

### What's solid (verified by read)
- `AudioLooper.crossfadeTo`: `gen = ++_switchGen` guard correctly drops stacked-up crossfades (only the latest wins); outgoing fade starts *before* any `await` (kills the late-start gap from Phase 12 bug history); `unawaited(inactive.play())` never awaits play() (the hung-play bug); swap of active/inactive only after seek. Two-player ceiling means ≥3 crossfades inside one fade window drop intermediates — by design.
- `_loadFuture = Future.wait([A.setAudioSources, B.setAudioSources])` is assigned synchronously inside `initialize()` (no await precedes it), so even though the coordinator calls `unawaited(_looper.initialize(...))`, a subsequent `crossfadeTo` sees a non-null `_loadFuture` and awaits both players ready — fixes the "first cycle silent because B still loading" bug.
- Disposal guards: `_initAudio` checks `_isDisposed` after the `Future.wait` of catalog sources and inside the one-shot load `.then`; `dispose()` cancels `_tickSub` + `_stateListener` before disposing players. No listener fires post-dispose.
- Mute correctness: `_onStateChanged` updates `_currentStatus`/`_currentPhase` *before* the `if (!isMuted.value)` audio guard, so unmute (`toggleMute`) can restore the correct loop track. `_onTick` reads `isMuted.value` live.

### Tick assets stay `.ogg`
`_tickAssets` point at `tick_clock.ogg` / `tick_heartbeat.ogg` (one-shots, unaffected by FLAC migration per Phase 13). Loop assets are `ohm_*.flac`. Consistent with the migration spec.

### `reset()` does not clear `isMuted`
By design (mute is a per-screen user preference, survives session restart). Not a bug — noted for completeness.

## Open Questions

- Should the one-shot re-buffer on tick-source change be serialized (drop a `Future` token / await previous load) to harden the Phase 22 runtime-toggle path? Needs a quick check of how often `toggleHeartTickSource` can realistically fire back-to-back.
- Keep `AudioCatalog`/`AudioTrack` as a seam for future non-asset sources (network/TTS), or inline now?
