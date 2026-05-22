# Code Review: Propagate classifier streams through `BciDeviceManager` + `BciNotifier`

**Plan:** `.ai-factory/plans/55-propagate-classifier-streams-through-bcidevicemanager-bcinotifier.md`
**Files changed (code):**
- `lib/Bci/Models/BciNotifierEvent.dart`
- `lib/Bci/BciDeviceManager.dart`
- `lib/Bci/BciNotifier.dart`
- `lib/BciModule/BciPairingService.dart`

## Scope check

The four code files match the plan 1:1. No collateral edits. Each task in the plan corresponds exactly to one file's diff.

## Verification

### `lib/Bci/Models/BciNotifierEvent.dart`
- Three new `final class` variants extend the existing `sealed class BciNotifierEvent` correctly: `BciNfbUpdated(BciNfbData data)`, `BciCardioUpdated(BciCardioData data)`, `BciEmotionsUpdated(BciEmotionsData data)`.
- Single-line `///` doc comments match the style of `BciSignalQualityUpdated` and `BciBatteryUpdated`.
- New imports (`BciCardioData`, `BciEmotionsData`, `BciNfbData`) are all present and used.
- Placement is between `BciBatteryUpdated` and `BciError` as specified.

### `lib/Bci/BciDeviceManager.dart`
- Three new getters (`nfbStream`, `cardioStream`, `emotionsStream`) sit in the "Public getters" block, immediately after the existing `calibrationStream` pass-through. They delegate directly to `_provider` — no controllers, no subscriptions, no state. Same passive pattern as `signalQualityStream` / `batteryStream` / `calibrationStream`.
- Imports for the three data models are added (alphabetically interleaved with neighbors).
- No effect on `dispose()` (nothing to cancel locally).
- No effect on `_subscribeProviderStreams()`, `startScan`, `connectDevice`, etc. — pre-existing logic is untouched.

### `lib/Bci/BciNotifier.dart`
- Three new nullable subscription fields (`_nfbSub`, `_cardioSub`, `_emotionsSub`) typed `StreamSubscription<dynamic>?`, matching the existing five fields.
- Three new `manager.<stream>.listen(...)` blocks in the constructor, immediately after `_batterySub`. Each maps payload → event variant (`BciNfbUpdated(data)` etc.) and uses the same `onError` shape as `_batterySub` — log `'BciNotifier: <name>Stream error: $e'` and emit `BciError(e.toString())`.
- `dispose()` cancels the three new subscriptions in declaration order, before `_subject.close()` and `_manager.dispose()`. Order is correct: cancel listeners → close subject → dispose manager.
- No imports for `BciNfbData` / `BciCardioData` / `BciEmotionsData` were added (correct — the variants' constructors infer payload types from the manager stream signatures and no name is referenced in this file).

### `lib/BciModule/BciPairingService.dart`
- Three new case labels (`BciNfbUpdated()`, `BciCardioUpdated()`, `BciEmotionsUpdated()`) share a single body `return acc;` at the bottom of the `_reduce` switch. Dart 3's case-grouping syntax (multiple labels, empty intermediate bodies, single trailing body) is correct here.
- The switch is again exhaustive over the sealed `BciNotifierEvent` hierarchy, so the method continues to satisfy the return-from-every-path requirement.
- All other cases are untouched.

## Runtime correctness

- **Stream lifecycle.** `NeiryBciProvider` exposes the three classifier streams via `StreamController<…>.broadcast()` (verified in `lib/Bci/NeiryBciProvider.dart`), so the new `BciDeviceManager` getters return broadcast streams that tolerate multiple listeners. The single subscription from `BciNotifier` is fine.
- **Pre-connect / post-disconnect.** Broadcast controllers in `NeiryBciProvider` are created at field-init time and only `add` after `connect()` succeeds, so `BciNotifier` subscribing in its constructor (before any device is connected) is safe — it just sees no events until a connection happens.
- **Disposal order.** `BciNotifier.dispose()` cancels the three new subs first, then closes the subject, then disposes the manager. No risk of `add`-after-close on `_subject`. The pre-existing behavior of `BciDeviceManager.dispose()` not invoking `_provider.dispose()` is unchanged and out of scope for this milestone.
- **`BciPairingService` rebuild cost.** `BciNotifier._subject` is a `BehaviorSubject`. The reducer for the three new variants returns `acc` (same instance), so the downstream `.scan().map()` chain emits a `BciPairingStateUpdated` whose payload is reference-identical to the previous one. The Riverpod `Notifier` setter then sees `this.state == newState` (identity match — Dart's default `==` on the un-overridden `BciPairingState` is identity), so no listener is notified and no rebuild happens. Classifier events that may arrive at high rate cost only an allocation of the `BciPairingStateUpdated` wrapper plus an identity comparison per event — negligible.
- **BehaviorSubject seed replay.** A new `BciPairingService.observeChanges()` subscriber replays the single most-recent event. After this change, with classifier streams active during a connected session, the replayed event will often be a `BciNfbUpdated` / `BciCardioUpdated` / `BciEmotionsUpdated`, which the reducer treats as a no-op. The existing inline note in `BciPairingService` already warns that callers must not rely on the BehaviorSubject's seed for full history; `BciPairingViewModel.initState()` calls `startScan()` on mount to drive fresh interesting emissions. No regression beyond what was already documented.
- **Type inference at call sites.** `manager.nfbStream` returns `Stream<BciNfbData>`, so `listen((data) => _subject.add(BciNfbUpdated(data)))` types `data` as `BciNfbData` without needing the import in `BciNotifier.dart`. Same for cardio and emotions. Confirmed against the actual source.

## Issues

None.

## Nits (non-blocking)

- The three new `StreamSubscription<dynamic>?` fields could be tightened to `StreamSubscription<BciNfbData>?` / `StreamSubscription<BciCardioData>?` / `StreamSubscription<BciEmotionsData>?`. The current `dynamic` choice matches the file's prevailing style (the existing five are all `dynamic`), so this is purely a consistency-vs-precision call. Not worth changing in this milestone.
- `BciPairingState` still lacks an `==` / `hashCode` override. This is preexisting and not introduced by this change; the no-op cases in `_reduce` are intentionally written to return the same `acc` reference so they don't trigger spurious Riverpod rebuilds. If/when classifier events start being mapped into state mutations (next milestones), the lack of value equality on `BciPairingState` will start to matter — but that's downstream of this milestone.

REVIEW_PASS
