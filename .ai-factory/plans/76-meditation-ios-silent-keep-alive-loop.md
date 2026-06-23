# Plan: Meditation iOS silent keep-alive loop

## Context
Meditation plays no audio, so the iOS `audio` background mode (note 138) has nothing to keep active and the app suspends ~1 min after lock. A silent looping track played for the duration of an active meditation holds the iOS audio session open, keeping the wall-clock timer (note 141) and biometric streaming alive while locked. iOS-only — Android is already covered by the foreground service (note 139).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Silent loop asset + player

- [x] **Task 1: Add the digital-silence loop asset**
  Files: `assets/audio/silence.flac`, `pubspec.yaml`
  Generate a true-silence FLAC of a few seconds (e.g. `ffmpeg -f lavfi -i anullsrc=r=44100:cl=mono -t 4 -c:a flac assets/audio/silence.flac`). Place it next to the existing breath assets (`ohm_*.flac`) in `assets/audio/`. The app pubspec already declares the `assets/audio/` directory under `flutter: assets:` (line 124), so the wildcard already bundles it — confirm the asset is picked up; only add an explicit entry if the wildcard does not cover it. The file must be genuinely silent (no audible content), not just low-volume.

- [x] **Task 2: Add `SilentKeepAlivePlayer` to `mind_audio`**
  Files: `packages/mind_audio/lib/src/silent_keep_alive_player.dart`, `packages/mind_audio/lib/mind_audio.dart`
  Add a minimal single-player class wrapping one `just_audio` `AudioPlayer`, modeled on the existing `AudioOneShot` (`packages/mind_audio/lib/src/audio_one_shot.dart`). Keep it asset-agnostic — accept the asset path via the constructor (`SilentKeepAlivePlayer({required String assetPath})`) so the package stays decoupled from app asset names (mirrors how `AudioLooper`/`AudioCatalog` take injected sources). API:
  - `start()` — lazily load the source on first call (`AudioSource.asset(assetPath)`), set `LoopMode.one`, and `play()` (fire-and-forget, `unawaited`). Re-callable after `stop()` for re-arm across repeated meditations (seek to zero + play).
  - `stop()` — `player.stop()` so nothing is playing and iOS can release/deactivate the audio session.
  - `dispose()` — dispose the underlying player (fire-and-forget, like `AudioOneShot.dispose`).
  Set volume to 0 as a belt-and-suspenders guard in addition to the silent asset. Export it from the `mind_audio.dart` barrel alongside the other `src/` exports. Use `logPrint` (from `package:mind_logger/mind_logger.dart`) for any load/play failure, matching `AudioOneShot`.

### Phase 2: Wire into the meditation feature

- [x] **Task 3: Add a status-keyed keep-alive coordinator** (depends on Task 2)
  Files: `lib/MeditationModule/Core/MeditationKeepAliveCoordinator.dart`
  Create a small coordinator modeled on `lib/MeditationModule/Core/MeditationModuleStateChannel.dart`. Constructor-injected (per RULES.md rule 3): `MeditationKeepAliveCoordinator({required Stream<MeditationSessionState> stateStream, required SilentKeepAlivePlayer player})`. It subscribes to `stateStream` itself and, on status change, calls `player.start()` on `MeditationSessionStatus.active` and `player.stop()` on `MeditationSessionStatus.idle` (track `_previousStatus` to fire only on transitions, exactly like `MeditationModuleStateChannel._onState`). `dispose()` cancels the subscription and calls `player.dispose()`. Import `MeditationSessionState`/`MeditationSessionStatus` from `package:meditation_module/meditation_module.dart` (the `show` form already used in `MeditationModuleStateChannel`).

- [x] **Task 4: Wire the coordinator into the session, iOS-only** (depends on Task 3)
  Files: `lib/MeditationModule/MeditationModule.dart`
  In `MeditationModule.buildSession`, when `Platform.isIOS` (import `dart:io`), construct a `SilentKeepAlivePlayer(assetPath: 'assets/audio/silence.flac')` and a `MeditationKeepAliveCoordinator(stateStream: vm.stream, player: player)` inside the `meditationSessionViewModelProvider.overrideWith` callback (alongside the existing `MeditationModuleStateChannel`). On Android, build nothing (the FGS, note 139, covers it). Extend the screen teardown so `MeditationSessionScreen(onDispose: ...)` disposes both the existing `stateChannel` and the keep-alive coordinator (null-safe — the coordinator only exists on iOS). Do not add any module state or wiring to `App.dart` (RULES.md rule 2); `buildSession` is the assembly point.
