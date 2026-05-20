# Code Review: Refactor `BreathSoundCoordinator` to delegate audio mechanics

**Plan:** `.ai-factory/plans/23-refactor-breathsoundcoordinator-to-delegate-audio-mechanics-to-audiolooper-audiooneshot.md`
**Spec:** `.ai-factory/notes/07-refactor-breathsoundcoordinator.md`
**Files changed:**
- `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart` (rewritten)
- `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart` (constructor call site + import)

## Summary of what was checked

I read both modified files in full plus the collaborators they touch (`AudioLooper`, `AudioOneShot`, `AudioCatalog`, `BreathViewModel.stream` semantics). The refactor follows the spec faithfully: constructor signature, removed fields/methods, `_isInitialized` flag, and the listener-attach ordering all match the plan. The previously flagged NPE race (status events arriving before `AudioLooper._activePlayer` is assigned) is correctly mitigated — `_looper.initialize(sources)` is called **before** `_tickSub` / `_stateListener` attach, and `AudioLooper.initialize` has no `await` in its body, so its synchronous prelude assigns `_activePlayer = _playerA` before any subsequent statement runs.

That said, the move from a fully-synchronous `initialize` to an async `_initAudio` introduces a few new lifecycle races that the plan did not address. Findings below in severity order.

---

## P1 — Dispose-during-init race (real bug)

**File:** `BreathSoundCoordinator.dart:84-105, 114-121`
**Symptom:** Use-after-dispose on `AudioOneShot` + leaked `AudioPlayer` instances + leaked `StreamSubscription` if the screen is disposed while `_initAudio` is still awaiting the catalog future.

The old `initialize(...)` was end-to-end synchronous: every player, subscription, and listener was attached before the method returned. Calling `dispose()` immediately after `initialize()` cleaned up everything.

The new code splits work across an async boundary:

```dart
void initialize(BreathSessionState initialState) {
  if (_isInitialized) return;
  _isInitialized = true;
  _currentTickSource = initialState.tickSource;
  ...
  unawaited(_initAudio());          // returns immediately
}

Future<void> _initAudio() async {
  final sources = await Future.wait( /* catalog awaits rootBundle.loadString */ );
  unawaited(_looper.initialize(sources));         // ← runs after dispose if interleaved
  unawaited(_catalog.sourceFor(...).then(_oneShot.load));  // ← calls .load on disposed player
  _tickSub = viewModel.tickStream.listen((_) => _onTick());  // ← leaked
  _stateListener = viewModel.listen(_onStateChanged);        // ← leaked
}
```

Interleaving sequence that triggers it:

1. `WidgetsBinding.addPostFrameCallback` fires → `_soundCoordinator.initialize(initialState)` kicks off `_initAudio`.
2. `_initAudio` awaits `Future.wait([_catalog.sourceFor(...) × 3])` — each call awaits `rootBundle.loadString('<asset>.meta.json')`. That's three sequential I/O ops on the platform channel; not free.
3. User pops the route (or hot-reloads, or `GoRouter` rebuilds the subtree) → `BreathSessionScreen.dispose()` runs → `_soundCoordinator.dispose()` runs:
   - `_tickSub?.cancel()` — no-op (still null).
   - `_stateListener?.call()` — no-op (still null).
   - `_looper.dispose()` — null-safe; nulls everything internally.
   - `_oneShot.dispose()` — disposes `_player`.
4. Microtask scheduler resumes `_initAudio` after dispose:
   - `_looper.initialize(sources)` — constructs **two new `AudioPlayer` instances** that will never be disposed.
   - `_catalog.sourceFor(...).then(_oneShot.load)` — calls `setAudioSource` on a disposed `AudioPlayer` (`just_audio` throws / logs an error on use-after-dispose).
   - `_tickSub` / `_stateListener` — attached to a `viewModel` whose owning screen is gone; the subscriptions are never cancelled. They'll keep the `BreathSoundCoordinator` alive (and via `viewModel.listen` keep a reference to `_onStateChanged`), leaking memory.

The old code had no such window because everything ran in one synchronous frame. This is a **regression** introduced by the refactor.

**Suggested fix** — add a disposal sentinel checked inside `_initAudio`:

```dart
bool _isDisposed = false;

Future<void> _initAudio() async {
  final sources = await Future.wait(
    _phaseOrder.map((p) => _catalog.sourceFor(AudioTrack(_phaseAssets[p]!))),
  );
  if (_isDisposed) return;
  unawaited(_looper.initialize(sources));
  if (_isDisposed) return;
  unawaited(_catalog
      .sourceFor(AudioTrack(_tickAssets[_currentTickSource]!))
      .then((src) {
        if (_isDisposed) return;
        return _oneShot.load(src);
      }));
  _tickSub = viewModel.tickStream.listen((_) => _onTick());
  _stateListener = viewModel.listen(_onStateChanged);
}

void dispose() {
  _isDisposed = true;
  _tickSub?.cancel();
  _tickSub = null;
  _stateListener?.call();
  _stateListener = null;
  _looper.dispose();
  _oneShot.dispose();
}
```

(Or hold the `_initAudio` future and `await` it in `dispose()` before tearing down — but the sentinel is cheaper and matches the cancellation idiom already used by `AudioLooper._switchGen`.)

---

## P2 — Initial-state-event loss inside the init window

**File:** `BreathSoundCoordinator.dart:92-105` + `BreathSessionViewModel.dart:35,71`
**Symptom:** Phase / status transitions that fire between `_soundCoordinator.initialize(...)` and `_stateListener` actually attaching are silently dropped. In practice the first audible inhale could be skipped on fast device boots.

`BreathViewModel._stateController` is a plain `StreamController.broadcast()` — **no replay, no `valueStream`**. Events emitted with no listener attached are lost. Confirmed at `BreathSessionViewModel.dart:35` and the emitter at `:71`.

The post-frame callback in `BreathSessionScreen.initState` runs both calls back-to-back:

```dart
_soundCoordinator.initialize(initialState);   // kicks off async _initAudio
viewModel.initState();                        // also async — awaits service.getSession
```

`viewModel.initState()` typically wins the race (network/DB call dominates), but on a warm cache it can resolve before `_initAudio`'s three `rootBundle.loadString` awaits. When `viewModel.initState` resolves, it calls `_setupEngine`, which assigns `state = BreathSessionState(loadState: ready, status: ..., phase: ...)` — emitting on the stream with no listener attached. The very first `breath`-status / `inhale`-phase transition is then lost; the next audible event is the first phase tick (~seconds later, depending on tick interval), so the user can miss the inhale crossfade entirely.

The old code attached listeners synchronously inside `initialize`, so this window did not exist.

**Suggested fix** — after attaching `_stateListener`, prime `_onStateChanged` once with the current state. The cleanest place is at the end of `_initAudio`:

```dart
_stateListener = viewModel.listen(_onStateChanged);
// Catch up on any state emitted during the catalog-load window.
_onStateChanged(viewModel.state);
```

`BreathViewModel` extends `Notifier<BreathSessionState>` (Riverpod), so `viewModel.state` returns the current synchronous value. Priming once is idempotent because `_onStateChanged` already diffs against `_currentPhase` / `_currentStatus`.

Alternatively, attach the listener synchronously inside `initialize` and gate `_onStateChanged` on a separate `_audioReady` flag set after `_looper.initialize(sources)` — that was Option B in the plan-review #1 but was not chosen. It also fixes this, but trades against a longer-lived guard that future readers must understand.

---

## P3 — `BreathSessionScreen.dart` import ordering

**File:** `BreathSessionScreen.dart:9-14`
**Symptom:** No functional issue; just style.

`import 'package:mind_audio/mind_audio.dart';` was inserted between two project-relative imports:

```dart
import 'Animation/OrbAnimationCoordinator.dart';
import 'package:mind_audio/mind_audio.dart';
import 'Audio/BreathSoundCoordinator.dart';
```

`flutter_lints` (and most Dart projects) group `package:` imports above relative imports. The neighbouring imports in this file are sorted that way (lines 1-4 are `package:`, 5-17 are relative). The new import should sit alongside the other `package:` imports near the top.

---

## P4 — `AudioOneShot.dispose()` non-idempotency

**File:** `BreathSoundCoordinator.dart:114-121` + `packages/mind_audio/lib/src/audio_one_shot.dart:27-29`
**Symptom:** Calling `BreathSoundCoordinator.dispose()` twice will call `AudioPlayer.dispose()` twice on the same instance. `just_audio` logs a warning on use-after-dispose. Not a crash, not a leak — just noise.

Not strictly introduced by this refactor (the underlying `AudioOneShot` already has this property), and Flutter's State.dispose() is single-call in normal use, so this is **informational only**. Worth noting because the previous `BreathSoundCoordinator.dispose()` was idempotent for the loop players (`if (playerA != null)` guards). If you ever want symmetric idempotency, `AudioOneShot` should null-guard its internal player on `dispose`.

---

## Positive notes

- The NPE race called out by plan-review #1 is correctly mitigated: `_looper.initialize(sources)` is `async` but has no `await` in its body, so `_activePlayer = _playerA` is set before the call returns; listeners attach only after.
- Constructor signature matches the spec verbatim, including the optional `AudioCatalog?` with `AssetAudioCatalog()` default.
- All removed fields/methods (`_loopPlayerA/B`, `_activeLoop`, `_inactiveLoop`, `_fadeTimerA/B`, `_switchGen`, `_tickPlayer`, `_loadFuture`, `_switchToPhase`, `_fadePlayer`, `_cancelFadeFor`, `_loadTickAsset`) are gone; nothing residual.
- The previously misleading `if (_currentStatus != BreathSessionStatus.breath) return;` guard was correctly omitted from the synchronous `crossfadeTo` site.
- `reset()` correctly drops the manual fade-timer cancels (delegated to `AudioLooper.stop()`).
- `dart:math` retained (used by `pow` in `_computeFadeDuration`); `just_audio` import removed cleanly (verified no `AudioPlayer` / `AudioSource` / `LoopMode` references remain).
- Debug logs were trimmed of references to removed fields (`_activeLoop`, `_loopPlayerA`, `volA`/`volB`) and now log `currentPhase` / `currentStatus` instead — useful and consistent with the new design.
- `_isInitialized` flag is in place; double-init is correctly guarded.
- Constructor call site in `BreathSessionScreen.dart:67-71` matches the spec; the untouched `_soundCoordinator.{initialize,suspend,resume,reset,dispose}` call sites are still wired correctly.

---

## Recommended actions before merge

1. **Fix P1** — add `_isDisposed` sentinel checked after each await in `_initAudio`, set in `dispose()`. This is a genuine regression.
2. **Fix P2** — prime `_onStateChanged(viewModel.state)` immediately after attaching `_stateListener`, to recover the events that occurred during the catalog-load window.
3. **Fix P3** — move the `mind_audio` import next to the other `package:` imports.
4. P4 is informational; no action required unless you want idempotent dispose across the audio layer.

Items 1 and 2 are the only ones that affect correctness. The plan's Task 8 (manual smoke test) is the only thing that would catch them at runtime, and only on the specific timing of "rapid navigate-away" / "warm session-load cache" respectively — both are realistic on user devices.