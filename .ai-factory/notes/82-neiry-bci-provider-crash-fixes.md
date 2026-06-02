# NeiryBciProvider — PPG Not Activating + Disconnect Crash Fixes

**Date:** 2026-06-03
**Source:** Cross-project bug report from Neiry team (notes 80 and 81)

## Key Findings

- `CardioClassifier` is created after `device.start()` in `connect()`, so the SDK's internal `StartPPG` hardware mode switch fires too late — the PPG LED does not activate for the current session. Fix: instantiate all four classifiers before `await _device!.start()`.
- `disconnect()` and `_teardownAfterUnexpectedDrop()` both omit two required SDK teardown steps: `unregisterCallbacks()` (must precede any Dart subscription cancellation) and `stopStream()` (must precede `disconnect()`). Violations produce `0xebadde09` (deleted JNI ref) or `SIGABRT` in `libCapsuleClient.so` on Android.
- Both `unregisterCallbacks()` and `stopStream()` are already public on `neiry_kit`'s `Device` class.
- Only `lib/Bci/NeiryBciProvider.dart` changes.

## Details

### Fix 1 — PPG activation (connect sequence)

**File:** `lib/Bci/NeiryBciProvider.dart` lines 156–161

Current (broken) order:
```dart
await _device!.connect();
await _device!.start();              // streaming begins
_nfbClassifier = neiry.NfbClassifier(_device!);
_cardioClassifier = neiry.CardioClassifier(_device!);   // StartPPG fires here — too late
_emotionsClassifier = neiry.EmotionsClassifier(_device!);
_memsClassifier = neiry.MEMSClassifier(_device!);
```

Fixed order — move all four classifier instantiations before `start()`:
```dart
await _device!.connect();
_nfbClassifier = neiry.NfbClassifier(_device!);
_cardioClassifier = neiry.CardioClassifier(_device!);   // StartPPG fires here — before start()
_emotionsClassifier = neiry.EmotionsClassifier(_device!);
_memsClassifier = neiry.MEMSClassifier(_device!);
await _device!.start();             // streaming begins with PPG already active
```

The existing `catch` cleanup block (lines 162–185) already disposes any classifiers that were created before rethrowing — no change needed there. The comment at line 205 ("All four classifiers are guaranteed non-null here") remains true.

### Fix 2 — Teardown crashes (disconnect + unexpected drop)

SDK invariants enforced silently — violation crashes native layer:

| # | Rule |
|---|------|
| A | `unregisterCallbacks()` before any Dart subscription `.cancel()` |
| B | `stopStream()` before `disconnect()` |

**`disconnect()` — lines 554–566:**

Add `await _device?.unregisterCallbacks()` before calling `_cancelDeviceSubscriptions()`. Add `await _device?.stopStream()` before `await _device?.disconnect()` inside the `try` block.

```dart
@override
Future<void> disconnect() async {
  await _device?.unregisterCallbacks();    // stop SDK background thread first
  await _cancelDeviceSubscriptions();
  try {
    await _device?.stopStream();           // stop native streaming before release
    await _device?.disconnect();
    await _device?.dispose();
  } catch (e) {
    logPrint('NeiryBciProvider: disconnect error: $e');
  }
  _device = null;
  _connectionStateController.add(BciConnectionState.disconnected);
}
```

**`_teardownAfterUnexpectedDrop()` — inside the `Future.microtask` block, lines 464–502:**

On an unexpected drop the native side is already gone, so both calls may throw — wrap each in `try/catch` and continue regardless.

```dart
unawaited(Future.microtask(() async {
  try { await device?.unregisterCallbacks(); } catch (_) {}

  await connectionSub?.cancel();
  await resistanceSub?.cancel();
  // ... (all other sub cancellations unchanged) ...

  try { await nfbClassifier?.dispose(); } catch (e) { logPrint(...); }
  // ... (all other classifier disposes unchanged) ...

  try { await device?.stopStream(); } catch (_) {}
  try {
    await device?.disconnect();
    await device?.dispose();
  } catch (e) {
    logPrint('NeiryBciProvider: unexpected drop dispose error: $e');
  }
}));
```

### neiry_kit API (already implemented)

- `Device.unregisterCallbacks()` — `Future<void>`, calls `DeviceMethods.unregisterCallbacks` on the platform channel. Stops all SDK background threads.
- `Device.stopStream()` — `Future<void>`, stops native streaming without releasing the device handle. Safe to call before `disconnect()`.

Both are in `neiry_kit/lib/src/api/device.dart`.
