# AudioLooper — Implementation Spec

**Date:** 2026-05-19
**Source:** Phase 13 roadmap planning

## Key Findings

- `AudioLooper` is a direct extraction of the ping-pong crossfade mechanics from `BreathSoundCoordinator._switchToPhase` + `_fadePlayer` + `_cancelFadeFor`.
- `_switchGen` (concurrent call guard) moves here from `BreathSoundCoordinator` — the coordinator retains only the domain-level bail (`_currentStatus != BreathSessionStatus.breath`).
- The early fade-out pattern (start fading the outgoing player *before* any `await`) is preserved — it eliminates the late-start artifact fixed in Phase 12.

## Details

### File

`packages/mind_audio/lib/src/audio_looper.dart`

Export from `packages/mind_audio/lib/mind_audio.dart`.

### Public API

```dart
class AudioLooper {
  Future<void> initialize(List<AudioSource> sources);
  void crossfadeTo(int index, Duration fadeDuration);
  void fadeOut(Duration duration);
  void fadeIn(Duration duration);
  void stop();
  void dispose();
}
```

### Internal fields

```dart
AudioPlayer? _playerA;
AudioPlayer? _playerB;
AudioPlayer? _activePlayer;
AudioPlayer? _inactivePlayer;
Timer? _fadeTimerA;
Timer? _fadeTimerB;
int _switchGen = 0;
Future<void>? _loadFuture;
```

### `initialize(List<AudioSource> sources)`

```dart
Future<void> initialize(List<AudioSource> sources) async {
  _playerA = AudioPlayer();
  _playerB = AudioPlayer();
  unawaited(_playerA!.setLoopMode(LoopMode.one));
  unawaited(_playerA!.setVolume(0.0));
  unawaited(_playerB!.setLoopMode(LoopMode.one));
  unawaited(_playerB!.setVolume(0.0));
  _activePlayer = _playerA;
  _inactivePlayer = _playerB;
  _loadFuture = Future.wait([
    _playerA!.setAudioSources(sources, preload: true),
    _playerB!.setAudioSources(sources, preload: true),
  ]);
  unawaited(_loadFuture!);
}
```

### `crossfadeTo(int index, Duration fadeDuration)`

Direct extraction of `BreathSoundCoordinator._switchToPhase`. Key invariants:

1. **Fade-out fires before any `await`** — outgoing player starts fading at the exact moment the phase change is detected, not after seek latency.
2. **Gen check after `_loadFuture`** — if a newer call arrived while waiting, bail silently.
3. **`unawaited(inactive.play())`** — do not `await play()`. Awaiting it caused a hung Future in Phase 12 (the previous `await inactive.play()` bug).

```dart
void crossfadeTo(int index, Duration fadeDuration) {
  final gen = ++_switchGen;
  final active = _activePlayer;
  final inactive = _inactivePlayer;
  if (active == null || inactive == null) return;

  // Start fading out the outgoing player immediately — before any await.
  _fadePlayer(active, 0.0, fadeDuration);

  unawaited(() async {
    if (_loadFuture != null) await _loadFuture;
    if (gen != _switchGen) return;

    _cancelFadeFor(inactive);
    await inactive.setVolume(0.0);
    await inactive.seek(Duration.zero, index: index);
    unawaited(inactive.play()); // never await play() — see Phase 12 bug history

    _activePlayer = inactive;
    _inactivePlayer = active;

    if (gen != _switchGen) return;
    _fadePlayer(_activePlayer!, 1.0, fadeDuration);
  }());
}
```

### `fadeOut(Duration duration)` / `fadeIn(Duration duration)`

```dart
void fadeOut(Duration duration) => _fadePlayer(_activePlayer!, 0.0, duration);
void fadeIn(Duration duration)  => _fadePlayer(_activePlayer!, 1.0, duration);
```

### `stop()`

```dart
void stop() {
  _fadeTimerA?.cancel(); _fadeTimerA = null;
  _fadeTimerB?.cancel(); _fadeTimerB = null;
  for (final p in [_playerA, _playerB]) {
    if (p != null) {
      unawaited(p.stop());
      unawaited(p.setVolume(0.0));
    }
  }
  _activePlayer = _playerA;
  _inactivePlayer = _playerB;
}
```

### `dispose()`

Cancel timers, dispose both players, null all fields.

### `_fadePlayer` / `_cancelFadeFor` (private)

Same 16ms-step timer implementation as the current `BreathSoundCoordinator._fadePlayer`. Each player has its own `Timer?` field (`_fadeTimerA` / `_fadeTimerB`). `_cancelFadeFor(player)` cancels the right timer based on which player is passed.
