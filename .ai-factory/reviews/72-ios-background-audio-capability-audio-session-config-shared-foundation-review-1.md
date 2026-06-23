# Code Review: iOS background-audio capability + audio-session config (shared foundation)

**Scope reviewed:** `git diff HEAD` — `ios/Runner/Info.plist`, `lib/Core/App.dart`, `packages/mind_audio/lib/mind_audio.dart`, `packages/mind_audio/lib/src/audio_session_config.dart`, `packages/mind_audio/pubspec.yaml` (plus plan/JSON artifacts, not code).

## Verification performed

- **Dependency resolution** — `pubspec.lock` resolves `audio_session 0.2.3` alongside `just_audio 0.10.5`; no constraint conflict. `flutter pub add` correctly landed the dep in `packages/mind_audio/pubspec.yaml` (not the root app), matching the plan's ownership reasoning.
- **Static analysis** — `flutter analyze` on `App.dart`, `audio_session_config.dart`, and `mind_audio.dart` reports **no issues**. The `const AudioSessionConfiguration(...)` with `AVAudioSessionCategory.playback` and `AVAudioSessionCategoryOptions.mixWithOthers` compiles (both are const-constructible in `audio_session 0.2.3`).
- **Policy correctness** — config uses the explicit `playback + mixWithOthers` policy required by spec note 138. It does **not** use `AudioSessionConfiguration.music()` (would interrupt other audio) nor the `ambient` category (would stop in background). This is the correct "never duck/interrupt the user's music, survive screen lock" combination.
- **Call ordering** — `await configureAudioSession()` runs after `WidgetsFlutterBinding.ensureInitialized()` (required: the plugin uses platform channels) and before any `AudioPlayer`/`AudioLooper` is constructed (players are built later at session start, not in `initialize()`). Ordering is correct. The single-line, no-trailing-comma form respects the `App.dart` STYLE RULE banner.
- **Info.plist** — `UIBackgroundModes` → `[audio]` added as a well-formed top-level key inside the root `<dict>`. Valid plist; this is the required capability so iOS does not suspend the isolate after lock.
- **Export wiring** — `export 'src/audio_session_config.dart';` added to the barrel; `App.dart` imports `package:mind_audio/mind_audio.dart` and the top-level function is reachable.
- **Guards honored** — `audio_looper.dart` is untouched; crossfade/fade logic unchanged. Android path is unaffected (no Android fields set → `audio_session` does not request Android audio focus; Android keep-alive is the foreground service per note 139).

## Correctness / runtime risk

- No missing migrations, type mismatches, or race conditions. `configureAudioSession()` is an idempotent one-shot with no shared mutable state.
- `await session.configure(...)` could throw if the platform channel is unavailable, but `initialize()` only runs from the real app entrypoint (not tests), and an audio-session failure surfacing during startup is acceptable and visible. No silent-swallow concern.

## Minor (non-blocking) notes

- The doc comment in `audio_session_config.dart` says the configuration is "a no-op on that platform [Android]." More precisely, the config sets only iOS (`avAudioSession*`) fields, leaving Android audio-focus fields unset, so `audio_session` simply does not manage Android focus — functionally harmless, which matches intent. Wording nit only; no code change needed.

## Conclusion

Implementation matches the plan task-for-task and the spec note's policy. Dependency resolves, analyzer is clean, ordering and platform guards are correct. Background-audio behavior itself is only verifiable on a physical iOS device (simulator is unreliable), as the plan states — that is a manual verification step, not a code defect.

REVIEW_PASS
