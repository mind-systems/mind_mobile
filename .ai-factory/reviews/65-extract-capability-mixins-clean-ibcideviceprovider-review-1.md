# Review: Extract capability mixins + clean `IBciDeviceProvider`

## Scope

Reviewed `git diff HEAD` against the plan. Code changes:
- `lib/Biometrics/IHeartRateSource.dart` (new)
- `lib/Biometrics/IRrIntervalSource.dart` (new)
- `lib/Biometrics/IEegBandsSource.dart` (new)
- `lib/Biometrics/IEmotionsSource.dart` (new)
- `lib/Biometrics/IMotionSource.dart` (new)
- `lib/Bci/IBciDeviceProvider.dart` (capability getters removed)
- `lib/Bci/NeiryBciProvider.dart` (RR + MEMS wiring, six interfaces)
- `lib/Bci/BciDeviceManager.dart` (three capability sources via ctor)
- `lib/Core/App.dart` (single provider passed to four roles)

Verified the consumer surface (`BciNotifier` uses `manager.cardio/nfb/emotionsStream`) is unchanged. Confirmed the only constructor call site of `BciDeviceManager` is `App.dart:152` and it now matches the new signature. Confirmed SDK types: `neiry.MemsSample.accelerometer`/`gyroscope` are `({double x, double y, double z})` (matches `MotionData`) and `s.timestamp` / `rr.timestamp` are `DateTime` (matches our models). `CardioClassifier.rrStream` exists and returns `Stream<RRInterval>`.

## Findings

### 1. `MEMSClassifier` is constructed inside `_subscribeDeviceStreams()` — diverges from the other classifiers and widens the leak window on failure

`lib/Bci/NeiryBciProvider.dart:231`

```dart
_memsClassifier = neiry.MEMSClassifier(_device!);
_memsSub = _memsClassifier!.memsStream.listen(...);
```

The three pre-existing classifiers (`_nfbClassifier`, `_cardioClassifier`, `_emotionsClassifier`) are all instantiated **inside `connect()`'s try/catch** (lines 157–159), so if any constructor throws, the catch block at line 160 disposes the partially-created classifiers and the device, then rethrows. `_subscribeDeviceStreams()` is called at line 180 **outside** that try/catch.

`MEMSClassifier(device)` is a factory that throws `StateError` synchronously when `device.isConnected` is false (`neiry_kit/lib/src/api/classifiers/mems_classifier.dart:47`). It is reachable: between `connect()` ending its try block and the subsequent `_subscribeDeviceStreams()` call there is no `await`, but the native side could fail asynchronously between `_device!.start()` and the MEMS factory call (the listen calls earlier in `_subscribeDeviceStreams()` access `_device!.connectionStateStream` synchronously, but if any of those throw — e.g., the native channel rejected — the same window opens).

If `MEMSClassifier(...)` (or any earlier `.listen(...)` inside `_subscribeDeviceStreams()`) throws:
- All previously-created subs (`_connectionSub` through `_emotionsErrorSub`) are orphaned — never cancelled, never nulled.
- `_nfbClassifier`, `_cardioClassifier`, `_emotionsClassifier` are never disposed (the catch in `connect()` already closed without firing).
- `_device` stays non-null but with leaked native handles.

The pre-refactor code had the same shape (no try/catch around `_subscribeDeviceStreams()`), so the leak window itself isn't new. But this milestone adds a **new synchronous failure point** (the MEMS factory) and a **new resource that requires explicit dispose** (the MEMS classifier itself) inside the unguarded region — and the spec note inside the plan emphasises that MEMS is the one classifier that leaks native resources without an explicit dispose call. Consider one of:

- Construct `_memsClassifier = neiry.MEMSClassifier(_device!);` inside `connect()`'s try block alongside the other three (line ~159), and only subscribe in `_subscribeDeviceStreams()`. The existing catch already nulls/disposes that block — extending it costs ~4 lines and keeps all four classifier lifecycles symmetrical.
- Or wrap `_subscribeDeviceStreams()` body in a try/catch that calls `_cancelDeviceSubscriptions()` + device dispose on failure.

Severity: medium. The happy path is fine and the SDK guarantees `device.isConnected == true` after `await _device!.start()` succeeds, so this is unlikely to fire in practice — but if it ever does, the device session leaks until app restart, which is exactly the failure mode the explicit MEMS dispose was meant to prevent.

### 2. `connect()`'s catch block doesn't reference `_memsClassifier` (consequence of finding 1)

`lib/Bci/NeiryBciProvider.dart:160-179`

Same root cause as finding 1: the catch block in `connect()` disposes nfb/cardio/emotions classifiers because they're created in the same try, but doesn't touch `_memsClassifier`. If finding 1 is addressed by moving the MEMS construction into `connect()`'s try, this catch block should grow a matching `try { await _memsClassifier?.dispose(); } catch (_) {} _memsClassifier = null;` block. Flagging separately because the fix lives in a different region of the file.

REVIEW_PASS would be appropriate **if** you accept that the existing pre-refactor code already had an unguarded `_subscribeDeviceStreams()` and consider extending the same risk one step further to be acceptable. The two findings above are the only delta from the plan worth raising; the rest of the implementation matches the spec exactly (interface declarations, RR handler with `isArtifact` pass-through and SDK `timestamp`, MEMS batch unroll with per-sample SDK `timestamp`, controller close in `_doDispose()`, all-subs cancel in `_cancelDeviceSubscriptions()`, App.dart passing one instance to four roles, `BciDeviceManager` getters delegating to the new sources, RR and Motion intentionally omitted from the manager).
