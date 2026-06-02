# Neiry PPG Not Activating — CardioClassifier Created After start()

**Date:** 2026-06-03
**Source:** cross-project audit of NeiryBciProvider vs. neiry_kit bug history

## Key Findings

- `NeiryBciProvider.connect()` calls `device.start()` before instantiating any classifiers. On Android, `CardioClassifier` creation calls `clCCardio_Create`, which fires an internal `on_mode_switched: mode=StartPPG` hardware event. When this happens after `start()`, the PPG LED does not activate reliably — the heart-rate sensor stays off for the current session.
- The fix is to instantiate all classifiers **before** calling `device.start()`. The neiry_kit plugin already allows this: classifier factories now guard on `device.isConnected`, not `device.isStarted`.
- This matches the confirmed root cause and fix in neiry_kit's example app. See neiry_kit roadmap task **"Fix classifier singleton lifecycle — create at connect, not at start"**.

## Details

### Current code in `lib/Bci/NeiryBciProvider.dart` (lines 155–186)

```dart
await _device!.connect();
await _device!.start();                            // ← streaming starts here
_nfbClassifier = neiry.NfbClassifier(_device!);
_cardioClassifier = neiry.CardioClassifier(_device!);  // ← PPG mode switch, AFTER start
_emotionsClassifier = neiry.EmotionsClassifier(_device!);
_memsClassifier = neiry.MEMSClassifier(_device!);
```

### Why this breaks PPG

The Capsule C SDK's `clCCardio_Create` triggers an internal `StartPPG` device mode switch. The sequence matters:

- **Correct**: Create classifier → mode set → `start()` → streaming begins with PPG active
- **Current**: `start()` → streaming begins → classifier created → mode switch happens mid-stream → PPG does not light up for this session

On a subsequent Disconnect + Reconnect cycle this can correct itself, but the first (or current) session after connect has no heart-rate data.

### Fix

Move all four classifier instantiations to run **before** `device.start()`:

```dart
await _device!.connect();
// Classifiers instantiated at connect time — PPG mode switch fires here, before start
_nfbClassifier = neiry.NfbClassifier(_device!);
_cardioClassifier = neiry.CardioClassifier(_device!);
_emotionsClassifier = neiry.EmotionsClassifier(_device!);
_memsClassifier = neiry.MEMSClassifier(_device!);
await _device!.start();   // streaming begins with PPG already active
```

The existing `try/catch` cleanup block in `connect()` handles the failure path correctly — it disposes classifiers that were already instantiated before rethrowing.

Also update the classifier guard inside `_subscribeDeviceStreams()`: the comment at line 205 says "All four classifiers are guaranteed non-null here" — this stays true; only the ordering inside the `try` block changes.

### neiry_kit reference

- Roadmap task: **"Fix classifier singleton lifecycle — create at connect, not at start"** (Phase example-app hardening)
- The fix changed all 6 classifier factory constructors from `if (!device.isStarted)` → `if (!device.isConnected)` exactly to enable this pattern.
