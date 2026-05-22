# Plan Review: Wire NfbClassifier, CardioClassifier, EmotionsClassifier in NeiryBciProvider

**Plan:** `.ai-factory/plans/54-wire-nfbclassifier-cardioclassifier-emotionsclassifier-in-neirybciprovider.md`

**Risk Level:** 🟢 Low

## Context Gates

- **ARCHITECTURE.md:** OK — `NeiryBciProvider` is the documented sole consumer of `neiry_kit`, and the plan keeps that boundary intact (no `neiry_kit` types leak into `IBciDeviceProvider` or `Models/`).
- **RULES.md:** OK — no module Services touched, no `App.dart` state added, no external wiring of stream handlers (subscriptions are owned by the provider).
- **ROADMAP.md:** OK — the plan is aligned with the planned BCI Data screen pipeline described in `notes/24-bci-data-screen.md`.

## Verification Against Codebase

### API surface (neiry_kit)
- `NfbClassifier(device)` factory, `stateStream` → `Stream<NfbUserState>`, `dispose()` — confirmed in `neiry_kit/lib/src/api/classifiers/nfb_classifier.dart`.
- `CardioClassifier(device)` factory, `stateStream` → `Stream<CardioData>`, `dispose()` — confirmed in `neiry_kit/lib/src/api/classifiers/cardio_classifier.dart`.
- `EmotionsClassifier(device)` factory, `stateStream` → `Stream<EmotionsStates>`, `dispose()` — confirmed in `neiry_kit/lib/src/api/classifiers/emotions_classifier.dart`.
- All three are exported from `neiry_kit/lib/neiry_kit.dart` (already imported in `NeiryBciProvider`).
- Classifier factories throw `StateError` only when `!device.isConnected`. The plan instantiates them after `await _device!.start()`, which runs after `connect()` returns — so `isConnected` should be `true`. ✅

### Field-by-field mapping
- `NfbUserState` → `BciNfbData`: `delta`, `theta`, `alpha`, `smr`, `beta` — all match (`double?` ⇄ `double?`). `timestamp` correctly dropped.
- `CardioData` → `BciCardioData`: `heartRate` (`double` → `double`), `metricsAvailable` (`bool`), `hasArtifacts` (`bool`) — all match. `stressIndex`, `kaplanIndex`, `skinContact`, `motionArtifacts`, `timestamp` correctly dropped per domain DTO contract.
- `EmotionsStates` → `BciEmotionsData`: `attention`, `relaxation`, `cognitiveLoad`, `cognitiveControl`, `selfControl` — all match.
- ✅ Direct field-to-field mapping as the plan claims.

### Implementations of `IBciDeviceProvider`
- Searched: `NeiryBciProvider` is the sole implementor. Adding three abstract getters will not silently break a second adapter. ✅

### Existing patterns reused
- Plan mirrors the `_resistanceSub`/`_batterySub` ownership style (declared next to existing subs, subscribed in `_subscribeDeviceStreams()`, cancelled in `_cancelDeviceSubscriptions()`).
- Broadcast controller pattern (kept open across reconnects, closed only in `_doDispose()`) is consistent with existing `_connectionStateController`, `_signalQualityController`, `_batteryController`, `_calibrationController`.
- Defensive `try { … } catch (_) {}` around classifier disposal matches the existing pattern around `_device?.disconnect()`.

## Critical Issues

None.

## Suggestions (non-blocking)

### 1. Inconsistent classifier vs device teardown ordering in the `connect()` catch block

Task 3 directs the catch block to be:

```dart
catch (e) {
  await _device?.disconnect();
  await _device?.dispose();
  try { await _nfbClassifier?.dispose(); } catch (_) {}
  try { await _cardioClassifier?.dispose(); } catch (_) {}
  try { await _emotionsClassifier?.dispose(); } catch (_) {}
  _nfbClassifier = null;
  _cardioClassifier = null;
  _emotionsClassifier = null;
  _device = null;
  rethrow;
}
```

The disconnect / `_doDispose()` paths (via `_cancelDeviceSubscriptions()` in Task 6) dispose classifiers **before** the device. The catch block disposes them **after** the device. While each classifier's `dispose()` only references its own `_serial` (not the live device handle), the asymmetry is jarring and could confuse future maintainers debugging native handle leaks. Consider moving the classifier disposals above `_device?.disconnect()` to keep the ordering consistent across all teardown paths.

### 2. Classifier `errorStream` is not subscribed

`NfbClassifier` and `EmotionsClassifier` expose an `errorStream` (forwarded from the native `SetOnErrorEvent` callback). The plan only subscribes to `stateStream` with an `onError` handler — but errors delivered via the dedicated `errorStream` channel will not appear in `stateStream`'s `onError`, they will be silently dropped. `CardioClassifier` has no `errorStream` (errors surface as `PlatformException` on its broadcast streams instead, which the existing `onError` already covers).

Not a blocker — the BCI Data screen does not currently surface classifier errors, and downstream logging only needs `logPrint`. But the plan should either:
- explicitly note this gap (with a follow-up task to wire the two `errorStream`s into `logPrint`), or
- add three more `StreamSubscription<String>` fields and `errorStream` listeners that just `logPrint` the message.

A one-line acknowledgment of this trade-off in the plan would be enough.

### 3. Plan does not mention whether `_subscribeDeviceStreams()` is called with classifiers guaranteed non-null

The plan uses `_nfbClassifier!.stateStream` (non-null assertion) inside `_subscribeDeviceStreams()`. This is correct because:
1. In `connect()`, classifier instantiation happens inside the `try` block before `_subscribeDeviceStreams()` is called.
2. If any instantiation throws, the catch rethrows and `_subscribeDeviceStreams()` never runs.

But the plan should briefly state this invariant to avoid a future maintainer "softening" the assertions to `?.` (which would silently drop subscriptions if instantiation were ever moved). Add one sentence under Task 4:

> The non-null `!` is safe here because `_subscribeDeviceStreams()` only runs after the `try` block completes successfully, and the same `try` block instantiates the classifiers as its last step.

## Positive Notes

- Mapping handlers are stateless and direct — no premature filtering, matching the `notes/24-bci-data-screen.md` rule that validity gating lives downstream in `BciDataService`.
- The plan correctly reuses `_cancelDeviceSubscriptions()` for both `disconnect()` and `_doDispose()`, avoiding duplicated cleanup logic.
- Controllers are closed only in `_doDispose()`, preserving the "broadcast controllers stay open across reconnects" invariant of the existing code.
- The plan explicitly drops `timestamp` and notes why, preventing accidental leakage of transport-only fields into domain DTOs.
- Two-commit split is well-bounded (interface first, then implementation) — keeps the interface commit reviewable on its own.

PLAN_REVIEW_PASS
