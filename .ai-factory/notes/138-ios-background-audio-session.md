# iOS background-audio capability + audio-session configuration

**Date:** 2026-06-22
**Source:** conversation context

## Key Findings

- The app has **no iOS background-execution capability at all**: `ios/Runner/Info.plist` has no `UIBackgroundModes` key, and `packages/mind_audio` creates `just_audio` `AudioPlayer()` instances with no `audio_session` package and no audio-category configuration. When the screen locks, iOS suspends the Dart isolate ~1 min after `paused` (confirmed by logs: last line 1 min after `app paused`, then a 28-min gap).
- This task is the **shared iOS foundation** for keeping a session alive in background. Consumers: the breath loop keeps playing (note 140) and meditation plays a silent loop (note 142). Without an active audio session + the `audio` background mode, neither survives the lock.

## Details

### Current state
- `ios/Runner/Info.plist` — no `UIBackgroundModes`, no audio keys.
- `packages/mind_audio/lib/src/audio_looper.dart:20-34` — `AudioLooper.initialize()` builds two `AudioPlayer()` with `LoopMode.one`; volumes fade-managed. No global audio-session category is ever set.
- Root `pubspec.yaml` — `just_audio: ^0.10.5` (transitively via `mind_audio`); **no** `audio_session`.

### Change
1. Add the `audio_session` package — `flutter pub add audio_session` (never hand-edit `pubspec.yaml`).
2. Expose a one-shot `configureAudioSession()` in `packages/mind_audio` (e.g. `lib/src/audio_session_config.dart`, exported from `mind_audio.dart`) that configures `AudioSession.instance` with category **playback** (continues in background) **+ `mixWithOthers`** so the app **never** ducks or interrupts the user's own audio (decided: a user may play their own music under a session and we leave it untouched). Use an explicit config, NOT `AudioSessionConfiguration.music()` — `.music()` interrupts other audio. Concretely:
   ```dart
   await AudioSession.instance.then((s) => s.configure(const AudioSessionConfiguration(
     avAudioSessionCategory: AVAudioSessionCategory.playback,
     avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
   )));
   ```
   Do **not** use the `ambient` category — it stops in background.
3. Call `configureAudioSession()` once at app start from `App.initialize()` (`lib/Core/App.dart`), before any player is used.
4. Add `UIBackgroundModes` to `ios/Runner/Info.plist`:
   ```xml
   <key>UIBackgroundModes</key>
   <array>
     <string>audio</string>
   </array>
   ```

### Guards
- **Always `mixWithOthers`** — we never pause/duck the user's audio, for both breath and meditation. This is the single global session policy; the meditation silent loop (note 142) inherits it.
- Physical iOS device required to verify (background audio is unreliable on the simulator).
- Do **not** change `AudioLooper` crossfade/fade logic or `BreathSoundCoordinator`.
- Android is unaffected (it uses the foreground service, note 139) — no `audio_session` config needed there, but the call is harmless cross-platform.
- Version: take whatever `flutter pub add audio_session` resolves as latest compatible with `just_audio ^0.10.5` (they share an author and are co-tested) — no manual pin.
- This task alone changes nothing user-visible for breath/meditation yet (breath still self-pauses — note 140; meditation has no audio — note 142). Its standalone value: any continuous `just_audio` playback now survives a screen lock on iOS, mixing with the user's audio.

### Verify
- Play your own music, then play any continuous app audio and lock the device → app audio keeps playing past 1 minute AND your music is not paused/ducked (today the app audio stops).

## Open Questions
- None.
