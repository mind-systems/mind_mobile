# Code Review #3: Refactor `BreathSoundCoordinator` to delegate audio mechanics

**Plan:** `.ai-factory/plans/23-refactor-breathsoundcoordinator-to-delegate-audio-mechanics-to-audiolooper-audiooneshot.md`
**Prior reviews:** `review-1.md`, `review-2.md`
**Files changed in this revision (since review #2):**
- `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart` — N1 patched in the tick-source-change branch.

The other two staged files (`BreathSessionScreen.dart`, `BreathSessionViewModel.dart`) are unchanged since review #2.

---

## Verification of all prior findings

### Review #1

| Finding | Status |
|---|---|
| **P1** — Dispose-during-init race (use-after-dispose + leaks) | **FIXED** ✓ — `_isDisposed` set at top of `dispose()` (line 121); checked at line 97 (after `Future.wait`) and inside the `then` callback for the tick load (line 103). Race windows around the async boundary are all guarded. |
| **P2** — Initial-state-event loss during catalog-load window | **FIXED** ✓ — `_onStateChanged(viewModel.currentState)` priming call at line 109 immediately after listener attach. New `BreathViewModel.currentState` getter at `BreathSessionViewModel.dart:229`. Both run in the same microtask, so no interleaving. |
| **P3** — `mind_audio` import ordering | **FIXED** ✓ — at `BreathSessionScreen.dart:3`, grouped with the other `package:` imports. |
| **P4** — `AudioOneShot.dispose()` non-idempotency | Informational only; pre-existing in `mind_audio`, not introduced by this refactor. Single-call from `State.dispose()` means no exposure in practice. |

### Review #2

| Finding | Status |
|---|---|
| **N1** — Tick-source-change branch in `_onStateChanged` lacked `_isDisposed` guard | **FIXED** ✓ — `_onStateChanged` lines 146-153 now mirror the exact `(src) async { if (_isDisposed) return; await _oneShot.load(src); }` pattern used in `_initAudio`. |
| **N2** — `BreathViewModel.currentState` is a redundant alias for `state` | Stylistic only; not addressed. Acceptable. |

---

## What I checked this round

- Re-read both modified files in full (`BreathSoundCoordinator.dart`, `BreathSessionScreen.dart`) and confirmed the `BreathSessionViewModel.dart` diff is limited to the one-line `currentState` getter.
- Re-walked the dispose-vs-init interleaving for the new `(src) async { if (_isDisposed) return; ... }` callback in the tick-source branch:
  - Window: state-change emits → `_catalog.sourceFor(...)` starts → user navigates away → `dispose()` runs → `sourceFor` resolves → `.then` callback fires → `_isDisposed=true` → returns without calling `_oneShot.load`. ✓
- Verified `_looper.initialize` still has no `await` in its body — so the synchronous prelude (creating both `AudioPlayer`s and assigning `_activePlayer = _playerA`) completes before subsequent statements observe it. The priming `_onStateChanged(viewModel.currentState)` at line 109, if it triggers any `fadeIn/fadeOut/crossfadeTo`, hits a non-null `_activePlayer`. ✓
- Verified `reset()` is safe before `_initAudio` resolves: `_looper.stop()` is null-safe; `_oneShot.stop()` operates on a non-nullable player constructed in the field initializer. ✓
- Verified `_isInitialized` correctly prevents double-init: re-entering `initialize` short-circuits, so duplicate listener registrations are impossible. ✓
- Verified `just_audio` import is genuinely orphan-free: `AudioPlayer`, `AudioSource`, `LoopMode`, `ClippingAudioSource` no longer appear in the file. ✓
- Verified `dart:math` retained (used by `pow` in `_computeFadeDuration`) and `dart:async` retained (used by `StreamSubscription`, `unawaited`, `Future`). ✓

---

## Verdict

All correctness findings from reviews #1 and #2 are addressed. P4 and N2 remain informational/stylistic only and were explicitly take-it-or-leave-it in their original write-ups. The refactor is functionally complete and the asynchronicity introduced by the catalog is correctly bracketed by both `_isInitialized` (guard against re-entry) and `_isDisposed` (guard against late completion).

REVIEW_PASS
