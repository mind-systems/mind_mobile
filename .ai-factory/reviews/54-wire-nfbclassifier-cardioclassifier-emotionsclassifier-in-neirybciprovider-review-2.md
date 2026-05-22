# Code Review 2: Wire NfbClassifier, CardioClassifier, EmotionsClassifier in NeiryBciProvider

**Plan file:** `.ai-factory/plans/54-wire-nfbclassifier-cardioclassifier-emotionsclassifier-in-neirybciprovider.md`

**Changed files** (`git diff HEAD`):
- `lib/Bci/IBciDeviceProvider.dart` (modified) — unchanged since review-1
- `lib/Bci/NeiryBciProvider.dart` (modified) — revised since review-1
- Plan / plan-review / review-1 artifacts (new)

## Delta vs review-1

The implementation has been revised to address all five findings from review-1:

| Finding | Status | Evidence |
|---|---|---|
| F1 — Asymmetric teardown ordering in `connect()` catch block | **Fixed** | Lines 141–156: classifiers disposed before `_device?.disconnect()/dispose()`. Now matches `_cancelDeviceSubscriptions()` ordering. |
| F2 — Unwrapped `_device?.disconnect()/dispose()` in catch block | **Fixed** | Lines 153–156: wrapped in `try { … } catch (_) {}`. |
| F3 — `errorStream` not subscribed on `NfbClassifier` / `EmotionsClassifier` | **Fixed** | Lines 186–188 and 199–201: `_nfbErrorSub` / `_emotionsErrorSub` subscribe with `logPrint` listener. New `StreamSubscription<String>?` fields declared on lines 48 and 51. Cancellation added in `_cancelDeviceSubscriptions()` (lines 320–321, 326–327). |
| F4 — Compact single-line `try { … } catch (…) {}` formatting | **Fixed** | All try/catch blocks expanded to multi-line, consistent with surrounding code. |
| F5 — Non-null assertion invariant in `_subscribeDeviceStreams()` undocumented | **Fixed** | Lines 179–180: comment explains the invariant. |

## Per-file review

### `lib/Bci/IBciDeviceProvider.dart`

Unchanged since review-1: three new abstract getters (`nfbStream`, `cardioStream`, `emotionsStream`) plus three new `Models/` imports. No defects.

### `lib/Bci/NeiryBciProvider.dart`

- **Field declarations (lines 28–51):** Three classifier fields, three broadcast controllers, five new `StreamSubscription` fields (state + error for NFB and Emotions, state-only for Cardio — Cardio has no `errorStream` per its dartdoc). All types correctly typed against the neiry_kit stream element types.
- **Getter wiring (lines 70–77):** Three `@override` getters delegate to the respective controllers.
- **Classifier instantiation (lines 137–139):** After `await _device!.start()` succeeds; `_device.isConnected` is true at this point, so the factory constructors will not throw their `StateError` guard.
- **Catch block teardown (lines 140–158):** Disposes classifiers first (with per-classifier try/catch swallow), then device (also wrapped in try/catch), then nulls `_device`. Order matches normal teardown paths. Each classifier field is nulled immediately after its disposal attempt, preventing stale references on retry.
- **`_subscribeDeviceStreams()` (lines 163–202):** Three state-stream subs with `_onXxxState` handlers and `onError → logPrint`. Two error-stream subs with bare listener that logs the string payload. Non-null assertions documented.
- **Mapping handlers (lines 254–284):** Direct field-to-field copies. `timestamp` intentionally dropped. No filtering — downstream `BciDataService` will gate cardio readings.
- **`_cancelDeviceSubscriptions()` (lines 311–347):** Cancels all five new subscriptions (state + error), then disposes the three classifiers (each in its own try/catch with `logPrint` on failure), then nulls the fields.
- **`_doDispose()` (lines 372–390):** Calls `_cancelDeviceSubscriptions()` first, then disposes the device, then closes all controllers including the three new ones. Broadcast controllers remain open across reconnects.

## Findings

### F6 (minor) — Error subscriptions lack their own `onError` handler

```dart
_nfbErrorSub = _nfbClassifier!.errorStream.listen(
  (e) => logPrint('NeiryBciProvider: nfb error: $e'),
);
_emotionsErrorSub = _emotionsClassifier!.errorStream.listen(
  (e) => logPrint('NeiryBciProvider: emotions error: $e'),
);
```

Every other `.listen()` call in this file passes an `onError:` callback, including the matching state-stream subscriptions just above (`_nfbSub`, `_cardioSub`, `_emotionsSub`). The two new error-stream subscriptions do not.

`NfbClassifier.errorStream` and `EmotionsClassifier.errorStream` are backed by `EventChannel.receiveBroadcastStream(...)` — those can themselves emit errors (e.g. `PlatformException` from the platform side, or a channel decoding error in `_eventStream`'s `.map((raw) => decode(...))`). Without an `onError` callback, such an error will become an **unhandled async error** on the zone, which Flutter surfaces via `FlutterError.onError` (or in the worst case crashes the isolate in tests).

Recommend adding the same `onError → logPrint` pattern for symmetry and zone safety:

```dart
_nfbErrorSub = _nfbClassifier!.errorStream.listen(
  (e) => logPrint('NeiryBciProvider: nfb error: $e'),
  onError: (Object e) =>
      logPrint('NeiryBciProvider: nfb errorStream error: $e'),
);
_emotionsErrorSub = _emotionsClassifier!.errorStream.listen(
  (e) => logPrint('NeiryBciProvider: emotions error: $e'),
  onError: (Object e) =>
      logPrint('NeiryBciProvider: emotions errorStream error: $e'),
);
```

Not a blocker — production won't typically emit errors on the error channel itself — but the omission is the only asymmetric `.listen()` call in the file and would be trivial to fix.

## Runtime sanity checks

- **Connect → start fails:** All three classifier fields remain null (instantiation never reached). Catch block runs no-op classifier disposals, then disposes the device. `_device` and classifier fields are nulled. Subsequent `connect()` enters the `_device != null` guard cleanly. ✅
- **Connect → classifier ctor fails (e.g. Cardio):** `_nfbClassifier` already non-null, `_cardioClassifier` null, `_emotionsClassifier` null. Catch block disposes the live NFB classifier, no-ops the other two, disposes the device. ✅
- **Disconnect → reconnect:** `_cancelDeviceSubscriptions()` cancels all five new subscriptions and disposes classifiers. Controllers stay open (broadcast). Next `connect()` re-instantiates and re-subscribes. Subscribers on the public streams continue to receive events without reconnecting. ✅
- **dispose() with no prior connection:** All null-safe operators; controllers are closed at the end of `_doDispose()`. ✅
- **Native `_createError` after subscription:** `stateStream` / `errorStream` getters call `_checkReady()` synchronously at the moment `.listen()` is set up; this passes because `_createError` is still null at that point (the native create call is awaited asynchronously inside `_nativeReady`). If native creation later fails, the subscriptions stay live but receive nothing. Acceptable — matches the neiry_kit lifecycle contract.
- **Cardio `heartRate` while metrics unavailable:** `BciCardioData.heartRate` is a non-nullable `double`; per neiry_kit docs, `CardioData.heartRate` is `0.0` until calibration completes. The mapping forwards `0.0` unmodified. Downstream gating via `metricsAvailable && !hasArtifacts` in `BciDataService` is the intended boundary, per `notes/24-bci-data-screen.md`. ✅

## Summary

The revision cleanly resolves all five findings from review-1. Teardown ordering is now consistent across all paths, `_device` cleanup is defensive, error-stream channels are subscribed for diagnostics, formatting is idiomatic Dart, and the non-null invariant is documented.

One new finding (F6) — the two error-stream subscriptions are the only `.listen()` calls in the file without an `onError` handler. Minor zone-safety / consistency issue; not a blocker.
