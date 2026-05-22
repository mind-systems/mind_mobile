# Code Review: Wire NfbClassifier, CardioClassifier, EmotionsClassifier in NeiryBciProvider

**Plan file:** `.ai-factory/plans/54-wire-nfbclassifier-cardioclassifier-emotionsclassifier-in-neirybciprovider.md`

**Changed files:**
- `lib/Bci/IBciDeviceProvider.dart` (modified — added three abstract getters + imports)
- `lib/Bci/NeiryBciProvider.dart` (modified — classifier fields/controllers/subs, instantiation in `connect()`, subscription wiring, mapping handlers, teardown updates)
- `.ai-factory/plans/54-…-neirybciprovider.md` (new — plan artifact)
- `.ai-factory/plan-reviews/54-…-neirybciprovider-plan-review-1.md` (new — plan review artifact)

## Scope verification

`git status` shows the four files above and nothing else. `NeiryBciProvider` is the sole implementer of `IBciDeviceProvider` in `lib/` and `test/` (confirmed via grep), so the three new abstract getters do not silently break any other adapter. All seven plan tasks are marked `[x]`. No collateral edits.

## Per-file review

### `lib/Bci/IBciDeviceProvider.dart`

- Three new abstract getters (`nfbStream`, `cardioStream`, `emotionsStream`) added in the section between `calibrationStream` and `startCalibration()`. Naming and dartdoc density match the rest of the interface.
- Imports for `BciCardioData`, `BciEmotionsData`, `BciNfbData` are added in alphabetical order alongside the existing `Models/` imports. No `neiry_kit` types appear in the interface — the domain boundary is preserved per ARCHITECTURE.md.
- No defects.

### `lib/Bci/NeiryBciProvider.dart`

#### Field declarations and getters (lines 28–49, 68–75)
- Three nullable `XxxClassifier?` fields placed next to `_device` — correct lifetime ownership.
- Three broadcast `StreamController` fields added next to existing controllers; three typed `StreamSubscription` fields added next to existing subs. Type parameters (`NfbUserState`, `CardioData`, `EmotionsStates`) match the neiry_kit stream element types.
- Getters return `_xxxController.stream` and carry `@override`. Idiomatic and consistent with the existing pattern.

#### `connect()` instantiation block (lines 132–149)
- Classifiers are instantiated **after** `await _device!.start()` and **inside** the existing `try`. The `neiry_kit` factories throw `StateError` only when `!device.isConnected`; after a successful `start()` the device is connected, so this is the correct call site.
- If any of the three factory calls throws (e.g. an unexpected state error), the catch block runs and disposes whichever classifiers were already created (the `?.dispose()` calls safely no-op on the unassigned fields).

#### Mapping handlers (lines 234–266)
- `_onNfbState`, `_onCardioState`, `_onEmotionsState` are direct, side-effect-free field-to-field copies. `timestamp` is intentionally dropped, matching the domain DTO contract (no transport leakage).
- Cardio passes `heartRate`, `metricsAvailable`, `hasArtifacts` through unmodified. Downstream gating (`metricsAvailable && !hasArtifacts`) lives in `BciDataService` per `.ai-factory/notes/24-bci-data-screen.md` — this is the intended split.

#### Subscription wiring (lines 169–183)
- Subscriptions are created inside `_subscribeDeviceStreams()` after the existing `_batterySub` subscription. `onError` handlers log to `logPrint` in the same format as the surrounding subscriptions.
- Non-null assertions `_nfbClassifier!.stateStream` (and the other two) are safe because `_subscribeDeviceStreams()` only runs after the `try` block in `connect()` completes successfully, and the same `try` block has already assigned all three classifier fields. The `NfbClassifier`/`CardioClassifier`/`EmotionsClassifier` docs explicitly say accessing `stateStream` before native creation completes is safe — events flow once the native side is ready.

#### Teardown updates (lines 293–319, 359–361)
- `_cancelDeviceSubscriptions()` cancels the three subs first (`await … .cancel(); _xxxSub = null;`), then disposes each classifier (wrapped in its own try/catch that logs via `logPrint`), then nulls the field. Order is correct: Dart subscription → native handle dispose → null the field.
- `_doDispose()` closes the three new controllers at the end, matching the existing pattern (broadcast controllers stay open across reconnects, closed only on terminal dispose). `disconnect()` correctly does **not** close them.

## Findings

### F1 (minor) — Asymmetric teardown ordering in the `connect()` catch block

```dart
} catch (e) {
  await _device?.disconnect();
  await _device?.dispose();
  try { await _nfbClassifier?.dispose(); } catch (_) {}
  try { await _cardioClassifier?.dispose(); } catch (_) {}
  try { await _emotionsClassifier?.dispose(); } catch (_) {}
  ...
}
```

The catch block disposes the device **before** the classifiers. Every other teardown path (`_cancelDeviceSubscriptions()` in `disconnect()` and `_doDispose()`) disposes the classifiers **before** the device. While each classifier's `dispose()` only references its own `_serial` (not the live device handle), the inconsistency is jarring and risks confusion for anyone debugging future native-handle leaks. Recommend moving the three classifier disposals above `_device?.disconnect()` so all teardown paths share the same order:

```dart
} catch (e) {
  try { await _nfbClassifier?.dispose(); } catch (_) {}
  try { await _cardioClassifier?.dispose(); } catch (_) {}
  try { await _emotionsClassifier?.dispose(); } catch (_) {}
  _nfbClassifier = null;
  _cardioClassifier = null;
  _emotionsClassifier = null;
  await _device?.disconnect();
  await _device?.dispose();
  _device = null;
  rethrow;
}
```

(The plan-review under `.ai-factory/plan-reviews/54-…-plan-review-1.md` already flagged this as a non-blocking suggestion; implementation followed the plan as written.)

### F2 (minor) — `_device?.disconnect()` / `_device?.dispose()` in the catch block can short-circuit classifier cleanup

In the same catch block, `await _device?.disconnect()` and `await _device?.dispose()` are not wrapped in try/catch. If either throws, the three `_xxxClassifier?.dispose()` calls and field nullings below them are skipped, leaving native classifier handles (and the field references) in a half-torn-down state. The original code had this risk with `_device` alone; the classifier additions widen the blast radius.

This is consistent with the pre-existing pattern, but worth a follow-up: either wrap each of the two `_device` calls in their own try/catch (mirroring `disconnect()`'s style), or use a `try { ... } finally { ... }` so the classifier cleanup always runs.

### F3 (minor) — `errorStream` from `NfbClassifier` and `EmotionsClassifier` is not subscribed

`NfbClassifier` and `EmotionsClassifier` expose a dedicated `errorStream` (forwarded from the native `SetOnErrorEvent` callback). The wiring only subscribes to `stateStream` with an `onError` handler — but errors delivered via the separate `errorStream` event channel will not surface in `stateStream`'s `onError`, they will be silently dropped. `CardioClassifier` has no `errorStream` (per its dartdoc, errors arrive as `PlatformException` directly on its broadcast streams, which the existing `onError` already covers).

For the BCI Data screen as scoped in `notes/24-bci-data-screen.md`, no user-facing error UI is needed — but losing native classifier error diagnostics will make debugging native-side failures (bad calibration data, channel mismatches, etc.) harder. A follow-up task to subscribe both `errorStream`s with `logPrint`-only listeners (and cancel them in `_cancelDeviceSubscriptions()`) would close this gap.

### F4 (style, non-blocking) — Inline single-line `try { … } catch (…) {}` formatting

The catch block in `connect()` and the disposal lines in `_cancelDeviceSubscriptions()` use a compact single-line form:

```dart
try { await _nfbClassifier?.dispose(); } catch (_) {}
try { await _nfbClassifier?.dispose(); } catch (e) {
  logPrint('NeiryBciProvider: nfb dispose error: $e');
}
```

The rest of the file (and the surrounding codebase) uses multi-line try/catch. `dart format` will likely rewrite these into multi-line blocks on the next format pass, producing churn. Recommend pre-emptively expanding them now (or running `dart format lib/Bci/NeiryBciProvider.dart` as part of this commit) to keep the diff stable.

### F5 (defensive doc, non-blocking) — `_subscribeDeviceStreams()` non-null assertion invariant

`_subscribeDeviceStreams()` uses `_nfbClassifier!.stateStream` (and similarly for the other two). The invariant — that this method is only ever called once all three classifier fields are assigned (because instantiation happens inside the same `try` that gates `_subscribeDeviceStreams()`) — is implicit. A one-line comment above the new subscriptions, e.g.

```dart
// Classifiers are guaranteed non-null here: connect()'s try block
// instantiates them before reaching this method.
```

would prevent a future "soften the `!` to `?.`" regression that would silently drop subscriptions if instantiation were ever moved.

## Runtime sanity checks

- **Re-connect after a failed connect.** The catch block nulls all three classifier fields, so a subsequent `connect()` call enters the `_device != null` guard cleanly and re-instantiates classifiers. ✅
- **Re-connect after `disconnect()`.** Controllers are not closed in `disconnect()`, so prior subscribers on `nfbStream`/`cardioStream`/`emotionsStream` keep their subscription across reconnects and receive events from the freshly-instantiated classifiers. Matches the existing pattern for `connectionStateStream` etc. ✅
- **`dispose()` after a connection cycle.** `_cancelDeviceSubscriptions()` is called from `_doDispose()`, so classifiers are disposed before the device; controllers are then closed at the end of `_doDispose()`. ✅
- **`dispose()` with no prior connection.** All `_xxxSub?.cancel()` and `_xxxClassifier?.dispose()` calls are null-safe; controllers are still open and `close()` is well-defined on an idle broadcast controller. ✅
- **Cardio `heartRate` while metrics unavailable.** `BciCardioData.heartRate` is a non-nullable `double`; per the neiry_kit docs, `CardioData.heartRate` is `0.0` while `metricsAvailable == false`. The mapping forwards `0.0` unmodified. Downstream `BciDataService` is expected to gate via `metricsAvailable && !hasArtifacts` (per `notes/24-bci-data-screen.md`); the milestone scope does not include `BciDataService`, so this is the intended boundary handoff. ✅

## Summary

All seven plan tasks are implemented faithfully. The interface extension is clean, the provider wiring mirrors the existing subscription/controller patterns, and the field-to-field mapping correctly drops transport-only fields. No correctness blockers.

Findings F1–F5 are minor — ordering inconsistency in the catch block, missing `errorStream` subscriptions, and a couple of style/doc items. None should block landing this milestone, but F1 and F3 are worth addressing before the BCI Data screen pipeline lands on top.
