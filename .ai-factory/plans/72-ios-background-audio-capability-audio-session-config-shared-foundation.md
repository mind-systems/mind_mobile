# Plan: iOS background-audio capability + audio-session config (shared foundation)

## Context
Give the app an active iOS audio session (category **playback + `mixWithOthers`**) plus the `audio` background mode so any continuous `just_audio` playback survives a screen lock without ducking/interrupting the user's own music. This is the shared iOS foundation for the breath loop (note 140) and the meditation silent loop (note 142).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Audio session configuration in mind_audio

- [x] **Task 1: Add the `audio_session` dependency to mind_audio**
  Files: `packages/mind_audio/pubspec.yaml`
  Run `flutter pub add audio_session` from inside `packages/mind_audio/` (never hand-edit `pubspec.yaml`). Take whatever version the resolver picks as compatible with the existing `just_audio: ^0.10.5` — no manual pin (they share an author and are co-tested). The dependency belongs in `mind_audio` because the configuration helper added in Task 2 lives there; the root app already consumes it via `mind_audio: { path: packages/mind_audio }`.

- [x] **Task 2: Add `configureAudioSession()` one-shot helper and export it** (depends on Task 1)
  Files: `packages/mind_audio/lib/src/audio_session_config.dart`, `packages/mind_audio/lib/mind_audio.dart`
  Create `audio_session_config.dart` exposing a top-level `Future<void> configureAudioSession()` that configures the global session with an **explicit** config — category **playback** (continues in background) plus `mixWithOthers` (never ducks/interrupts the user's own audio):
  ```dart
  await AudioSession.instance.then((s) => s.configure(const AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.playback,
    avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
  )));
  ```
  Do NOT use `AudioSessionConfiguration.music()` (it interrupts other audio) and do NOT use the `ambient` category (it stops in background). The call is harmless on Android, so no platform guard is required. Add `export 'src/audio_session_config.dart';` to `mind_audio.dart` alongside the existing exports. Do not touch `audio_looper.dart` (crossfade/fade logic stays as-is).

### Phase 2: App wiring + iOS capability

- [x] **Task 3: Call `configureAudioSession()` once at app start** (depends on Task 2)
  Files: `lib/Core/App.dart`
  Add `import 'package:mind_audio/mind_audio.dart';` and call `await configureAudioSession();` inside `App.initialize()` early — after `WidgetsFlutterBinding.ensureInitialized();` and before any player/audio code runs. Keep the call as a single-line statement consistent with the file's initializer style rule (no multi-line named calls, no trailing commas on initializer lines).

- [x] **Task 4: Add `UIBackgroundModes: [audio]` to iOS Info.plist** (depends on none)
  Files: `ios/Runner/Info.plist`
  Add the background-audio capability so iOS does not suspend the Dart isolate after lock:
  ```xml
  <key>UIBackgroundModes</key>
  <array>
    <string>audio</string>
  </array>
  ```
  Place it as a top-level entry inside the root `<dict>` (e.g. near the other `UI*` keys). Android is unaffected — it uses the foreground service (note 139).

## Verification (manual, physical iOS device required)
Background audio is unreliable on the simulator. On a physical device: play your own music, start any continuous app audio, lock the device → app audio keeps playing past 1 minute AND your music is not paused or ducked. This milestone alone changes nothing user-visible for breath/meditation yet (breath still self-pauses — note 140; meditation has no audio — note 142).
