# Code Review (2): Fix PPG not activating + Android disconnect crashes in `NeiryBciProvider`

**Scope:** `lib/Bci/NeiryBciProvider.dart` (only changed code file). Re-verified against `neiry_kit/lib/src/api/device.dart` and the classifier constructors. This is a re-review after the fix applied in response to review-1.

## Status of the prior finding (review-1, Medium)
**Resolved.** `disconnect()` now guards the platform-channel call:

```dart
Future<void> disconnect() async {
  try { await _device?.unregisterCallbacks(); } catch (e) {
    logPrint('NeiryBciProvider: unregisterCallbacks error: $e');
  }
  await _cancelDeviceSubscriptions();
  try {
    await _device?.stopStream();
    await _device?.disconnect();
    await _device?.dispose();
  } catch (e) { logPrint('NeiryBciProvider: disconnect error: $e'); }
  _device = null;
  _connectionStateController.add(BciConnectionState.disconnected);
}
```

A throw from `unregisterCallbacks()` (e.g. native side already gone) no longer aborts the method — subscription/classifier cleanup runs, `_device` is nulled, and `BciConnectionState.disconnected` is still emitted, so the device can be reconnected. This brings the explicit-disconnect path to parity with the wrapped call in `_teardownAfterUnexpectedDrop()`. Per `device.dart:184`, a later `disconnect()` re-runs unregister internally as a no-op, so skipping it on error is safe.

## Verification of all three tasks

1. **Classifier reorder (`connect()`)** — correct. `CardioClassifier(device)` requires only `device.isConnected` (throws `StateError` otherwise, `cardio_classifier.dart:72-78`), not a started stream, so instantiating the four classifiers after `connect()` and before `start()` is valid. The `StartPPG` mode switch now fires before streaming begins. The `catch` cleanup block is untouched and still disposes any classifier created before a failure.

2. **`_teardownAfterUnexpectedDrop()`** — correct. `unregisterCallbacks()` added as the first microtask statement (before any `sub.cancel()`); `stopStream()` added before the `disconnect()`/`dispose()` block. Both wrapped in `try/catch` since the native side may already be gone. Final order — unregister → cancel subs → dispose classifiers → stopStream → disconnect → dispose — matches the SDK invariants at `device.dart:180-191` and `222-234`.

3. **`disconnect()`** — correct and now robust (see above). `stopStream()` precedes `disconnect()`; classifiers are disposed inside `_cancelDeviceSubscriptions()` before the handle is released by `disconnect()`, matching `stopStream`'s documented contract.

SDK methods exist with the expected `Future<void>` signatures (`device.dart:186, 228`). All new calls are null-safe (`_device?.` / captured `device?.`). No type, compile, or scope issues; `_doDispose()` and `_cancelDeviceSubscriptions()` left untouched per the plan's scope note.

## Non-blocking observation (not a defect)
In `disconnect()`, `stopStream()` shares the `try` with `disconnect()`/`dispose()`, so a `stopStream()` throw would skip `disconnect()`/`dispose()` (handle not explicitly released; `_device = null` still drops the Dart reference). This matches the spec exactly ("inside the existing try block") and does **not** risk the native crash this milestone targets — if `stopStream()` fails, `disconnect()` is simply not called, so the "stopStream before disconnect" invariant is never violated. In `_teardownAfterUnexpectedDrop()` the two are deliberately in separate `try` blocks because there the native side is expected to be dead. The asymmetry is intentional and acceptable.

## Verdict
The prior finding is fixed and no new defects were found. The fixes are correct and respect the SDK ordering invariants.

REVIEW_PASS
