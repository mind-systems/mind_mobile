# Code Review #2: Refactor `BreathSoundCoordinator` to delegate audio mechanics

**Plan:** `.ai-factory/plans/23-refactor-breathsoundcoordinator-to-delegate-audio-mechanics-to-audiolooper-audiooneshot.md`
**Prior review:** `.ai-factory/reviews/23-refactor-breathsoundcoordinator-to-delegate-audio-mechanics-to-audiolooper-audiooneshot-review-1.md`
**Files changed since last review:**
- `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart` (P1/P2 fixes applied)
- `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart` (P3 fix applied)
- `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart` (new `currentState` getter added)

## Verification of prior-review fixes

### P1 — Dispose-during-init race → FIXED ✓

`_isDisposed` flag added at line 29; set first thing in `dispose()` (line 121); checked after the only `await` in `_initAudio` (line 97) and inside the `then` callback on the tick-load chain (line 103). Trace:

- Window 1 (dispose during `await Future.wait`): caught by line 97 — `_looper.initialize`, tick load, and listener attaches are all skipped. ✓
- Window 2 (dispose between `_looper.initialize` and listener attach): no async boundary here — lines 98-110 are synchronous, so dispose cannot interleave. ✓
- Window 3 (dispose during `_catalog.sourceFor` of tick): caught by line 103 — `_oneShot.load` is not called. ✓

The `unawaited(_looper.initialize(sources))` call after the disposal check is correct: `AudioLooper.initialize` has no `await` in its body, so its synchronous prelude (`_playerA = AudioPlayer(); _playerB = AudioPlayer(); … _activePlayer = _playerA;`) runs before the call returns. Any subsequent `fadeIn/fadeOut` from priming or listener events sees a non-null `_activePlayer`. ✓

One residual: the `setAudioSources` futures kicked off inside `AudioLooper.initialize` will resolve after `_looper.dispose()` if dispose lands in the narrow window between `unawaited(_looper.initialize(sources))` and `_looper.dispose()`. just_audio's `AudioPlayer.dispose()` cancels in-flight loads internally and logs (not crashes) on use-after-dispose, so this is acceptable.

### P2 — Initial-state-event loss → FIXED ✓

`_onStateChanged(viewModel.currentState)` priming call added at line 109, immediately after listener attach. New `BreathViewModel.currentState` getter exposes `state` (BreathSessionViewModel.dart:229). Since both lines (108-109) run in the same microtask, no state emission can interleave; the listener will see future events while priming covers any state set before listener attach. `_onStateChanged` is idempotent against repeated calls because it diffs against `_currentPhase`/`_currentStatus` and short-circuits on no-change, so double-firing for the same state is harmless. ✓

### P3 — Import ordering → FIXED ✓

`import 'package:mind_audio/mind_audio.dart';` now sits at `BreathSessionScreen.dart:3`, between the other `package:` imports and above the relative imports. Matches Dart import-grouping convention. ✓

### P4 — `AudioOneShot.dispose()` idempotency → still informational (not addressed, not required)

No change. Pre-existing in `mind_audio`. Single-call from State.dispose() means no practical exposure.

---

## New findings

### N1 — Tick-source-change branch in `_onStateChanged` lacks `_isDisposed` guard (minor regression)

**File:** `BreathSoundCoordinator.dart:144-151`

```dart
if (state.tickSource != _currentTickSource) {
  _currentTickSource = state.tickSource;
  unawaited(
    _catalog
        .sourceFor(AudioTrack(_tickAssets[_currentTickSource]!))
        .then(_oneShot.load),       // ← no _isDisposed check
  );
}
```

`_initAudio` (line 99-106) protects the analogous tick-load chain with an inner `if (_isDisposed) return;` inside the `then` callback. The runtime equivalent inside `_onStateChanged` does not. The race window opens if:

1. A tick-source change is emitted by the ViewModel.
2. `_onStateChanged` fires, kicks off `_catalog.sourceFor(...).then(_oneShot.load)`.
3. The user navigates away → `dispose()` runs → `_oneShot.dispose()` is called.
4. `sourceFor` resolves → `_oneShot.load(src)` is called on a disposed `AudioPlayer`.

just_audio logs a warning rather than crashing on use-after-dispose, so this won't surface as a user-visible bug. However, the old code did guard this (`if (player == null) return;` inside `_loadTickAsset` against the nulled `_tickPlayer`), so this is a mild regression in defensive correctness.

**Suggested fix** — mirror the pattern used in `_initAudio`:

```dart
unawaited(
  _catalog
      .sourceFor(AudioTrack(_tickAssets[_currentTickSource]!))
      .then((src) async {
        if (_isDisposed) return;
        await _oneShot.load(src);
      }),
);
```

Or, even cleaner, extract a small private `_loadTickSource()` helper that both call sites share. Severity: low — log noise only, not a crash.

### N2 — `BreathViewModel.currentState` getter is redundant with `viewModel.state` (style)

**File:** `BreathSessionViewModel.dart:229`

```dart
BreathSessionState get currentState => state;
```

`BreathViewModel` extends `Notifier<BreathSessionState>`, and Riverpod 3.x exposes `state` as a public getter on `Notifier`. `viewModel.state` would have worked at the priming call site without adding this wrapper. Not wrong — just a thin alias that duplicates an existing API surface. If the intent was to make external access more explicit/discoverable, a doc comment would be more idiomatic than a new getter. Severity: trivial — no functional impact.

---

## Other things checked (no findings)

- **`reset()` while init in flight** — `_looper.stop()` is null-safe (both players null until init completes), `_oneShot.stop()` is safe (player is non-nullable, set at construction). No crash.
- **`dispose()` called twice** — `_isDisposed=true` is set unconditionally, but the rest of dispose is null-safe. `_oneShot.dispose()` is the only non-idempotent call (P4); same as before.
- **`_onStateChanged` priming on initial state** — `state.loadState != SessionLoadState.ready` returns at the load gate; safe no-op until session is loaded.
- **Removed fields and methods** — verified none of `_loopPlayerA/B`, `_activeLoop`, `_inactiveLoop`, `_fadeTimerA/B`, `_switchGen`, `_tickPlayer`, `_loadFuture`, `_switchToPhase`, `_fadePlayer`, `_cancelFadeFor`, `_loadTickAsset` remain. Clean cut.
- **`just_audio` import removed** — confirmed at line 4; no `AudioPlayer`, `AudioSource`, `LoopMode` types remain in the file.
- **`dart:math` retained** — used by `pow` in `_computeFadeDuration` (line 80). ✓
- **`dart:async` retained** — used by `StreamSubscription`, `unawaited`, `Future`. ✓
- **Constructor call site** — `BreathSessionScreen.dart:67-71` matches spec.
- **Behaviour on `complete` / `rest` status** — preserved via `_looper.fadeOut(500ms)`.
- **`suspend()`/`resume()` semantics** — preserved; `_isSuspended` gating in `_onTick` unchanged.

---

## Verdict

P1 and P2 (the only correctness-affecting findings from review #1) are correctly addressed. P3 cosmetic fix applied. N1 is a minor defensive-correctness regression worth tightening but does not cause user-visible failures; N2 is purely stylistic. The refactor is functionally sound — no migrations, no contract changes, no type mismatches, and the listener / dispose ordering now matches the asynchronicity introduced by the catalog.

Recommended before merge: apply the small N1 patch (six extra characters of dispose-safety). N2 is take-it-or-leave-it.
