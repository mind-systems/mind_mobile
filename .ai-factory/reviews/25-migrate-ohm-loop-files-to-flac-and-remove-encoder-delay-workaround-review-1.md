# Code Review: Migrate ohm loop files to FLAC and remove encoder-delay workaround

## Scope
- `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
- `packages/mind_audio/lib/src/audio_catalog.dart`
- `packages/mind_audio/lib/src/audio_track.dart`

Verified against `git status` / `git diff HEAD` — these three are the only modified source files; the rest of the staged set is plan/plan-review markdown.

## Verification

### `BreathSoundCoordinator.dart`
- `_phaseAssets` (lines 31–36) now points at `assets/audio/ohm_inhale.flac`, `ohm_exhale.flac`, `ohm_hold.flac`. Keys, ordering, and the `// rest → silence` comment are preserved. ✅
- `_phaseOrder` (lines 40–44) and `_tickAssets` (lines 46–49) are unchanged. The fixed `[inhale, exhale, hold]` index mapping used by `_looper.crossfadeTo(_phaseOrder.indexOf(state.phase), …)` (lines 169, 188) still aligns with the playlist order built in `_initAudio`. ✅
- `_initAudio` builds the playlist via `_phaseOrder.map((p) => _catalog.sourceFor(AudioTrack(_phaseAssets[p]!)))` — the positional-only `AudioTrack` constructor is honored. ✅
- The two `AudioTrack(_tickAssets[_currentTickSource]!)` call sites (one-shot load in init and tick-source change) likewise use only the positional constructor. ✅
- No other edits in this file, matching the plan's "no other change" guarantee. ✅

### `audio_catalog.dart`
- `dart:convert` and `package:flutter/services.dart` imports are removed; only `package:just_audio/just_audio.dart` and the local `audio_track.dart` remain — both still required (`AudioSource`, `AudioTrack`). ✅
- `AssetAudioCatalog.sourceFor()` reduces to `return AudioSource.asset(track.assetPath);`. The try/catch, `rootBundle` read, `jsonDecode`, `loopEndMs` branch, and `ClippingAudioSource` wrap are all gone. ✅
- Class-level dartdoc no longer mentions `.meta.json`, `loop_end_ms`, `ClippingAudioSource`, OGG, encoder delay, or `rootBundle`; it now reads "Returns a plain [AudioSource.asset] for the track's asset path." ✅
- `AudioCatalog` abstract class and its dartdoc are unchanged, as the plan required. ✅

### `audio_track.dart`
- `loopEnd` field and its dartdoc are removed; the class-level dartdoc is rewritten to mention only `assetPath` with a FLAC example, dropping every reference to `loopEnd`, OGG, encoder delay, `ClippingAudioSource`, and WAV loops. ✅
- Constructor is now `const AudioTrack(this.assetPath);` (no named parameter). ✅
- `@immutable` and the `package:flutter/foundation.dart` import are retained. ✅

### Cross-repo audit
- `Grep` across `*.dart` for `loopEnd`, `ClippingAudioSource`, `meta\.json`, `loop_end_ms` returns zero matches — no stale references remain anywhere in the source tree.
- `ls assets/audio/` shows only `ohm_inhale.flac`, `ohm_exhale.flac`, `ohm_hold.flac`, `tick_clock.ogg`, `tick_heartbeat.ogg`. No `.opus` remnants, no `.meta.json` sidecars. The new `_phaseAssets` paths all resolve.
- `pubspec.yaml:106` bundles the directory via the `assets/audio/` glob, so no `pubspec.yaml` edit was required. ✅
- `packages/mind_audio/lib/mind_audio.dart` re-exports `audio_track.dart` and `audio_catalog.dart` — both still parse with their reduced surface, and the only external consumer (`BreathSoundCoordinator`) uses the simplified shapes correctly.
- `packages/mind_audio/test/mind_audio_test.dart` is an empty `void main()`; no test fixtures reference the removed symbols.

### Runtime considerations
- `just_audio` plays FLAC natively on both iOS (AVFoundation) and Android (ExoPlayer); no codec plugin or platform glue is required.
- `AudioLooper` configures `LoopMode.one` and never relies on `ClippingAudioSource`-style trimming, so removing the wrap is safe — FLAC is sample-exact, eliminating the original click rationale.
- `sourceFor` still returns `Future<AudioSource>`; all callers (`Future.wait(...)`, `.then(...)` in `BreathSoundCoordinator`) continue to compose correctly.

## Notes
- `AssetAudioCatalog.sourceFor` is now effectively synchronous but is still declared `async` (auto-wraps the return value into a `Future`). This is harmless and idiomatic — preserving the `async` keeps the implementation easy to extend if a future catalog needs real async work. Not a defect.

REVIEW_PASS
