# Code Review: Fix PPG not activating + Android disconnect crashes in `NeiryBciProvider`

**Scope:** `lib/Bci/NeiryBciProvider.dart` (only changed code file). Verified against `neiry_kit/lib/src/api/device.dart` and the classifier constructors.

## What the change does
1. `connect()` — moves the four classifier instantiations to before `await _device!.start()`. Verified correct: `CardioClassifier(device)` only requires `device.isConnected` (throws otherwise), not a started stream (`cardio_classifier.dart:72-78`). So creating classifiers after `connect()` and before `start()` is valid, and the `StartPPG` mode switch now fires before streaming begins.
2. `_teardownAfterUnexpectedDrop()` — adds `try { await device?.unregisterCallbacks(); } catch (_) {}` as the first microtask statement (before sub cancels) and `try { await device?.stopStream(); } catch (_) {}` before the disconnect/dispose block. Ordering matches the SDK invariants documented at `device.dart:180-191` and `222-234`.
3. `disconnect()` — adds `await _device?.unregisterCallbacks();` as the first statement and `await _device?.stopStream();` before `disconnect()`.

The SDK methods exist with the expected `Future<void>` signatures (`device.dart:186, 228`). Classifiers are disposed (inside `_cancelDeviceSubscriptions` / the microtask) before `stopStream`/`disconnect` release the handle, matching `stopStream`'s documented contract. No compilation or type issues.

## Findings

### 1. [Medium] `unregisterCallbacks()` in `disconnect()` is unguarded — a native throw aborts the whole cleanup

`lib/Bci/NeiryBciProvider.dart:556`

```dart
Future<void> disconnect() async {
  await _device?.unregisterCallbacks();   // ← outside any try/catch
  await _cancelDeviceSubscriptions();
  try {
    await _device?.stopStream();
    await _device?.disconnect();
    await _device?.dispose();
  } catch (e) { logPrint(...); }
  _device = null;
  _connectionStateController.add(BciConnectionState.disconnected);
}
```

`unregisterCallbacks()` is a platform-channel call (`_channel.invokeMethod`) that also runs `_checkNotDisposed()` — it can throw a `PlatformException` (or `StateError`) if the native side has already gone away. A realistic trigger: the headband is powered off and the user taps "disconnect" in the UI before the unexpected-drop connection event has been processed.

Because this first `await` is outside the `try`, a throw propagates out of `disconnect()` and skips everything after it: `_cancelDeviceSubscriptions()` never runs (subscriptions + classifiers leak), `_device` is never nulled, and `BciConnectionState.disconnected` is never emitted. The UI stays "connected", and a subsequent `connect()` throws the `StateError('already connected')` guard — the device can no longer be reconnected without an app restart.

Note the asymmetry with `_teardownAfterUnexpectedDrop()`, where the same call is deliberately wrapped in `try/catch`. The explicit-disconnect path is just as exposed to a dead native side.

**Suggested fix:** wrap it so cleanup always proceeds:
```dart
try { await _device?.unregisterCallbacks(); } catch (e) {
  logPrint('NeiryBciProvider: unregisterCallbacks error: $e');
}
await _cancelDeviceSubscriptions();
```
(Per `device.dart:184`, a later `disconnect()` re-runs unregister internally as a no-op, so skipping it on error is safe.)

This matches the plan/spec as written (the spec also left it unwrapped), so it is spec-conformant — but it is a genuine robustness gap worth addressing before merge.

## Notes (non-blocking)
- The same unguarded-pre-`try` pattern technically applies to `_cancelDeviceSubscriptions()` in `disconnect()`, but that is pre-existing and its inner `sub.cancel()`/`dispose()` calls are individually guarded, so the practical risk is far lower than the new platform-channel call.
- `_doDispose()` (line 576) was intentionally left untouched per the plan's scope note. It still lacks `unregisterCallbacks()`/`stopStream()`, but `dispose()` is the terminal app-teardown path and out of scope for this milestone — flagging only for awareness, not as a finding.

## Verdict
The three tasks are implemented correctly and the PPG-ordering and teardown-ordering fixes are sound. Finding #1 is a medium-severity robustness regression risk in the explicit `disconnect()` path; recommend wrapping `unregisterCallbacks()` in `try/catch` for parity with the unexpected-drop path.
