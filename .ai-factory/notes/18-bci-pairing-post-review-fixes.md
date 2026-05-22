# BciPairing — Post-Review Fixes

**Date:** 2026-05-22
**Used by:** ROADMAP Phase 17 post-review milestone

## Fix 1: Remove docstrings

**Files:**
- `packages/bci_module/lib/src/BciPairing/IBciPairingService.dart`
- `packages/bci_module/lib/src/BciPairing/Models/BciCalibrationProgressDTO.dart`

**Problem:** Both files contain multi-line Dart docstrings (`///`). Project style is no docs.

**`IBciPairingService.dart`** — remove the 3-line class docstring above `abstract class IBciPairingService` and the 3-line method docstring above `observeChanges()`. Keep the file otherwise unchanged.

**`BciCalibrationProgressDTO.dart`** — remove the 4-line class docstring above the class declaration. Keep the file otherwise unchanged.

## Fix 2: Null `_eventsSubscription` on dispose — `BciPairingViewModel`

**File:** `packages/bci_module/lib/src/BciPairing/BciPairingViewModel.dart`

**Problem:** `ref.onDispose` cancels `_eventsSubscription` but does not null it out:

```dart
ref.onDispose(() => _eventsSubscription?.cancel());
```

If Riverpod ever rebuilds the notifier (calls `build()` again after provider invalidation), the previous `onDispose` fires and cancels the subscription, but `_eventsSubscription` remains non-null pointing at a dead subscription. The next call to `initState()` hits the guard `if (_eventsSubscription != null) return;` and silently skips re-subscription — the ViewModel goes deaf.

**Fix:** Null the field in the dispose callback:

```dart
ref.onDispose(() {
  _eventsSubscription?.cancel();
  _eventsSubscription = null;
});
```
