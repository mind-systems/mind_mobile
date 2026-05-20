# Plan: Implement `AudioLooper` in `mind_audio`

## Context
Extract the ping-pong crossfade mechanics from `BreathSoundCoordinator` into a standalone, domain-free `AudioLooper` class inside `packages/mind_audio`. This is a pure mechanical extraction — `_switchGen` concurrent-call guard moves here; the coordinator will later keep only domain-level decisions. Full reference spec lives in `.ai-factory/notes/09-audio-looper.md`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Implementation

- [x] **Task 1: Create `AudioLooper` class with fields and `initialize`**
  Files: `packages/mind_audio/lib/src/audio_looper.dart`
  Create a new file. Add the required imports (`dart:async`, `package:just_audio/just_audio.dart`). Declare `class AudioLooper` with the internal fields exactly as specified in `.ai-factory/notes/09-audio-looper.md` (Internal fields section): `AudioPlayer? _playerA`, `AudioPlayer? _playerB`, `AudioPlayer? _activePlayer`, `AudioPlayer? _inactivePlayer`, `Timer? _fadeTimerA`, `Timer? _fadeTimerB`, `int _switchGen = 0`, `Future<void>? _loadFuture`. Implement `Future<void> initialize(List<AudioSource> sources)` using the body from the note: create both players, set `LoopMode.one` and volume `0.0` on both (unawaited), assign `_activePlayer = _playerA` and `_inactivePlayer = _playerB`, store `_loadFuture = Future.wait([...setAudioSources(sources, preload: true)...])`, and `unawaited(_loadFuture!)`. Pattern reference for player setup: `BreathSoundCoordinator.initialize` lines 82–98 in `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`.

- [x] **Task 2: Implement private `_fadePlayer` and `_cancelFadeFor`** (depends on Task 1)
  Files: `packages/mind_audio/lib/src/audio_looper.dart`
  Port the 16ms-step timer fade logic verbatim from `BreathSoundCoordinator._fadePlayer` (lines 289–313) and `_cancelFadeFor` (lines 279–287). Each player has its own dedicated timer field (`_fadeTimerA` / `_fadeTimerB`); `_cancelFadeFor(player)` cancels the matching timer based on which player is passed; the periodic timer assigns itself to the right field. Remove all `kDebugMode` / `debugPrint` calls — the note specifies minimal logging and these are coordinator-level diagnostics.

- [x] **Task 3: Implement `crossfadeTo`** (depends on Task 2)
  Files: `packages/mind_audio/lib/src/audio_looper.dart`
  Copy the `crossfadeTo(int index, Duration fadeDuration)` skeleton from `.ai-factory/notes/09-audio-looper.md` (crossfadeTo section). Key invariants to preserve exactly:
  1. `final gen = ++_switchGen;` and bail with `gen != _switchGen` after the awaited `_loadFuture` (and again after the swap, matching the coordinator's second gen check at line 273 of `BreathSoundCoordinator.dart`).
  2. `_fadePlayer(active, 0.0, fadeDuration)` fires synchronously **before** any `await` — this preserves the Phase 12 fix for the late-start artifact.
  3. The async work (`await _loadFuture`, `await inactive.setVolume(0.0)`, `await inactive.seek(Duration.zero, index: index)`, then `unawaited(inactive.play())`) runs inside an `unawaited(() async { ... }())` IIFE so `crossfadeTo` returns `void` per the public API in the note.
  4. Swap `_activePlayer` ↔ `_inactivePlayer` after `play()` is dispatched, then `_fadePlayer(_activePlayer!, 1.0, fadeDuration)`.
  Domain-level bails (`_currentStatus != BreathSessionStatus.breath`) stay in the coordinator — do NOT add them here.

- [x] **Task 4: Implement `fadeOut`, `fadeIn`, `stop`, `dispose`** (depends on Task 3)
  Files: `packages/mind_audio/lib/src/audio_looper.dart`
  - `void fadeOut(Duration duration)` → `_fadePlayer(_activePlayer!, 0.0, duration)`
  - `void fadeIn(Duration duration)`  → `_fadePlayer(_activePlayer!, 1.0, duration)`
  - `void stop()` — cancel both fade timers (null them), iterate over `[_playerA, _playerB]` calling `unawaited(p.stop())` and `unawaited(p.setVolume(0.0))` for non-null entries, reset `_activePlayer = _playerA`, `_inactivePlayer = _playerB`. Mirrors `BreathSoundCoordinator.reset` lines 111–130 minus the tick player and the `_currentPhase` / `_currentStatus` resets (those are domain state).
  - `void dispose()` — cancel both fade timers, capture both player refs locally, null all fields (`_playerA`, `_playerB`, `_activePlayer`, `_inactivePlayer`, `_loadFuture`), then `unawaited(p.dispose())` on each captured player. Mirrors `BreathSoundCoordinator.dispose` lines 132–158 minus tick / listener / status bookkeeping.

- [x] **Task 5: Export `AudioLooper` from the package barrel** (depends on Task 4)
  Files: `packages/mind_audio/lib/mind_audio.dart`
  Add `export 'src/audio_looper.dart';` after the existing `audio_catalog.dart` export so `package:mind_audio/mind_audio.dart` exposes the new class. No other changes — `flutter pub get` is not required (no `pubspec.yaml` edits).
