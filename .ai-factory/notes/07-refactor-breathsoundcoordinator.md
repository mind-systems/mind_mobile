# Refactor BreathSoundCoordinator — Full Spec

## Files that change

| File | Change |
|------|--------|
| `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart` | Major refactor |
| `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart` | Constructor call site only (line 66) |

These two files must ship atomically — the constructor signature change breaks compilation at the call site.

---

## New constructor

```dart
BreathSoundCoordinator({
  required this.viewModel,
  required AudioLooper looper,
  required AudioOneShot oneShot,
  AudioCatalog? catalog,
}) : _looper = looper,
     _oneShot = oneShot,
     _catalog = catalog ?? AssetAudioCatalog();
```

`catalog` is optional — production omits it and gets `AssetAudioCatalog()`. Tests can inject a mock.

---

## New fields

```dart
final AudioLooper    _looper;
final AudioOneShot   _oneShot;
final AudioCatalog   _catalog;   // shared by initialize() and _loadTickAsset()
```

---

## Fields to REMOVE

```
_loopPlayerA, _loopPlayerB
_activeLoop, _inactiveLoop
_fadeTimerA, _fadeTimerB
_switchGen
_tickPlayer
_loadFuture
```

---

## Methods to REMOVE

```
_switchToPhase()
_fadePlayer()
_cancelFadeFor()
_loadTickAsset()   → replaced inline below
```

---

## Method changes

### `initialize(BreathSessionState initialState)`

Remove: player creation, `setLoopMode`, `setAudioSources`, `_tickPlayer = AudioPlayer()`, `_loadTickAsset` call.

Add:

```dart
final sources = await Future.wait(
  _phaseOrder.map((p) => _catalog.sourceFor(AudioTrack(_phaseAssets[p]!))),
);
unawaited(_looper.initialize(sources));

_currentTickSource = initialState.tickSource;
unawaited(
  _catalog
    .sourceFor(AudioTrack(_tickAssets[_currentTickSource]!))
    .then(_oneShot.load),
);
```

The `Future.wait` for sources is fire-and-forget into `_looper.initialize()` — same async pattern as the current `_loadFuture`.

---

### `_onStateChanged(BreathSessionState state)` — status branch

Replace `_fadePlayer(_activeLoop!, ...)` calls:

| Was | Becomes |
|-----|---------|
| `_fadePlayer(_activeLoop!, 0.0, Duration(ms: 200))` | `_looper.fadeOut(const Duration(milliseconds: 200))` |
| `_fadePlayer(_activeLoop!, 1.0, Duration(ms: 200))` | `_looper.fadeIn(const Duration(milliseconds: 200))` |
| `_fadePlayer(_activeLoop!, 0.0, Duration(ms: 500))` | `_looper.fadeOut(const Duration(milliseconds: 500))` |

Replace `unawaited(_switchToPhase(phase, fadeDuration))`:

```dart
// Domain bail stays in coordinator — AudioLooper does not know about BreathSessionStatus
if (_currentStatus != BreathSessionStatus.breath) return;
_looper.crossfadeTo(_phaseOrder.indexOf(phase), fadeDuration);
```

---

### `_onStateChanged` — tick-source change branch

Replace `unawaited(_loadTickAsset(_currentTickSource))`:

```dart
unawaited(
  _catalog
    .sourceFor(AudioTrack(_tickAssets[_currentTickSource]!))
    .then(_oneShot.load),
);
```

---

### `_onTick()`

Replace:
```dart
unawaited(player.seek(Duration.zero).then((_) => player.play()));
```
With:
```dart
_oneShot.play();
```

---

### `suspend()`

Replace `unawaited(_tickPlayer?.stop())` with `_oneShot.stop()`. Keep `_isSuspended = true`.

---

### `resume()`

No change — just `_isSuspended = false`.

---

### `reset()`

Replace player stops with:
```dart
_looper.stop();
_oneShot.stop();
```

Keep `_currentPhase = null`, `_currentStatus = null`, fade timer cancels are now handled inside `_looper.stop()`.

---

### `dispose()`

Replace player dispose calls with:
```dart
_looper.dispose();
_oneShot.dispose();
```

Keep `_tickSub?.cancel()`, `_stateListener?.call()`, null-out fields.

---

## Fields to KEEP unchanged

```
viewModel
_phaseOrder, _phaseAssets, _tickAssets
_computeFadeDuration()
_onStateChanged() structure (step 1–4 logic)
_currentPhase, _currentStatus
_isSuspended
_currentTickSource
_stateListener
_tickSub
_kFadeCoeff, _kMinFadeMs, _kMaxFadeMs
_ts() helper
```

---

## BreathSessionScreen.dart — line 66 only

```dart
// Before
_soundCoordinator = BreathSoundCoordinator(viewModel: viewModel);

// After
_soundCoordinator = BreathSoundCoordinator(
  viewModel: viewModel,
  looper: AudioLooper(),
  oneShot: AudioOneShot(),
);
```

Add `import 'package:mind_audio/mind_audio.dart'`.

Do **NOT** touch lines 75, 102, 113, 119, 280 — `initialize`, `dispose`, `suspend`, `resume`, `reset` signatures are unchanged.
