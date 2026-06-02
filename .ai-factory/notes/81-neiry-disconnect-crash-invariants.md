# Neiry Disconnect Crash — Missing Teardown Invariants A and B

**Date:** 2026-06-03
**Source:** cross-project audit of NeiryBciProvider vs. neiry_kit crash investigation

## Key Findings

- `NeiryBciProvider.disconnect()` and `_teardownAfterUnexpectedDrop()` both skip two required steps: `device.unregisterCallbacks()` (Invariant A) and `device.stopStream()` (Invariant B). Skipping them causes two distinct native crashes on Android.
- The Capsule C SDK enforces these invariants silently — violations produce `0xebadde09` (background thread uses a deleted JNI ref) or `SIGABRT` in `libCapsuleClient.so`.
- The correct 5-step sequence and its rationale are documented in `neiry_kit/docs/guides/teardown.md` and neiry_kit note `28-teardown-invariants-scan-crash-hardening.md`.

## Details

### SDK Invariants

| # | Requirement | Crash if violated |
|---|---|---|
| A | `nativeUnregisterDeviceCallbacks` must be called before cancelling any stream subscription or deleting any JNI EventSink ref | `0xebadde09` — background SDK thread fires into deleted JNI global ref |
| B | All classifiers must be disposed before `nativeReleaseDevice` | `SIGABRT` — `IsClassifierSupported` reads a freed device handle |
| C | `nativeReleaseDevice` must be called synchronously after `nativeDisconnectDevice` | `Fatal signal 64` — stale GATT JNI refs |

### Current `NeiryBciProvider.disconnect()` (lines 554–566)

```dart
Future<void> disconnect() async {
  await _cancelDeviceSubscriptions();  // ← cancels subs + disposes classifiers
  try {
    await _device?.disconnect();       // ← nativeDisconnect + nativeRelease
    await _device?.dispose();
  } catch (e) { ... }
  _device = null;
  _connectionStateController.add(BciConnectionState.disconnected);
}
```

**Missing**: no `await _device?.unregisterCallbacks()` before `_cancelDeviceSubscriptions()`. Invariant A requires that SDK background threads are stopped before any Dart subscription is cancelled. Without it, the SDK thread can fire a callback into a subscription that has just been torn down.

**Missing**: no `await _device?.stopStream()` before `_device?.disconnect()`. `device.start()` was called in `connect()`, so streaming is active. The disconnect sequence must stop native streaming before releasing the device handle.

### Current `_teardownAfterUnexpectedDrop()` (lines 429–503)

```dart
void _teardownAfterUnexpectedDrop() {
  // ... capture locals, null fields synchronously ...
  unawaited(Future.microtask(() async {
    await connectionSub?.cancel();   // ← cancels subs first
    // ...
    await nfbClassifier?.dispose();  // ← then disposes classifiers
    // ...
    await device?.disconnect();      // ← then disconnect
    await device?.dispose();
  }));
}
```

Same violations: no `unregisterCallbacks()` before subscription cancellation, and no `stopStream()` before `disconnect()`. On an unexpected native drop the device is already disconnected at the native level, but `unregisterCallbacks()` is still needed to stop the SDK background thread from delivering further callbacks into already-cancelled Dart subscriptions.

### Correct sequence

```dart
// 1. Stop SDK background threads — BEFORE any Dart teardown
await device.unregisterCallbacks();

// 2. Cancel all stream subscriptions — safe now, background threads stopped
await _cancelAllSubscriptions();

// 3. Dispose classifiers — device handle still alive, IsClassifierSupported works
await _disposeAllClassifiers();

// 4. Stop native streaming (stop without release) — only if start() was called
await device.stopStream();

// 5. Disconnect and release device handle
await device.disconnect();

// 6. Dart cleanup
await device.dispose();
```

`device.unregisterCallbacks()` is a method added to `neiry_kit/lib/src/api/device.dart` specifically for this sequence. It calls `DeviceMethods.unregisterCallbacks` on the platform channel.

`device.stopStream()` stops native streaming without releasing the device handle — it is the internal step 1 of `device.disconnect()` in the neiry_kit plugin. Calling it explicitly before disconnect ensures the session is cleanly stopped.

### For `_teardownAfterUnexpectedDrop()`

On an unexpected native disconnect, `device.stopStream()` and `device.unregisterCallbacks()` may throw (native side is already gone). Wrap them in `try/catch` and continue regardless. The important thing is that Dart subscriptions are not cancelled until after the unregister attempt.

```dart
unawaited(Future.microtask(() async {
  try { await device?.unregisterCallbacks(); } catch (_) {}

  await connectionSub?.cancel();
  // ... cancel all subs ...

  try { await nfbClassifier?.dispose(); } catch (_) {}
  // ... dispose all classifiers ...

  try { await device?.stopStream(); } catch (_) {}
  try {
    await device?.disconnect();
    await device?.dispose();
  } catch (e) {
    logPrint('NeiryBciProvider: unexpected drop dispose error: $e');
  }
}));
```

### neiry_kit references

- `neiry_kit/docs/guides/teardown.md` — full invariant table and correct sequence
- `neiry_kit/.ai-factory/notes/26-teardown-scan-crash-fixes.md` — session findings from initial crash investigation
- `neiry_kit/.ai-factory/notes/28-teardown-invariants-scan-crash-hardening.md` — final hardening note with all three invariants
- `neiry_kit/lib/src/api/device.dart` — `unregisterCallbacks()` and `stopStream()` are already implemented
