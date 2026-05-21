# Code Review: Implement `BciNotifier`

**Plan:** `.ai-factory/plans/38-implement-bcinotifier.md`
**Branch:** `bci-integration`
**Reviewed files:**
- `lib/Bci/Models/BciNotifierEvent.dart` (new)
- `lib/Bci/BciNotifier.dart` (new)
- `lib/Core/App.dart` (modified)

**Risk level:** 🟢 Low

## Summary

The implementation matches the plan task-for-task: a pure-Dart sealed event hierarchy, a passive notifier that subscribes to all five manager streams and translates each into the corresponding event, and App.dart wiring that constructs the dependency chain after `SharedPreferences` is available and fires `fetchKnownSerials()` off the critical path. No correctness blockers found. The notes below are minor.

---

## Findings

### 1. `BciDeviceManager.dispose()` does not dispose the underlying provider (latent leak)

Severity: low (no observable defect in current usage).

`BciNotifier.dispose()` (`lib/Bci/BciNotifier.dart:88-96`) cancels its own subscriptions, closes the subject, and awaits `manager.dispose()`. However, `BciDeviceManager.dispose()` (`lib/Bci/BciDeviceManager.dart:88-95`) only tears down the manager's own resources — it never disposes `_provider`. Consequently, if `BciNotifier.dispose()` were ever called, the `NeiryBciProvider` would keep its four broadcast `StreamController`s open and hold its native `Device` handle/calibration subscription.

In the current codebase this is harmless because:
- `App` keeps the notifier for the process lifetime (mirrors `TokenNotifier` — neither has its `dispose()` invoked anywhere).
- No tests construct/dispose the notifier.

But the ownership chain established here (`BciNotifier` owns `BciDeviceManager` which owns `IBciDeviceProvider`) is asymmetric — the notifier propagates `dispose` one level, then the chain breaks. Either:

- Augment `BciDeviceManager.dispose()` to call `await _provider.dispose()` (preferred — keeps ownership transitive); or
- Document explicitly in `BciNotifier.dispose()` that the provider must be disposed separately.

Not blocking for this milestone; flag for the next BCI plan.

### 2. `StreamSubscription<dynamic>?` discards type parameters

Severity: style / minor.

The five subscription fields in `BciNotifier` are declared as `StreamSubscription<dynamic>?` (`lib/Bci/BciNotifier.dart:22-26`). The plan specified "`late final` or nullable `StreamSubscription`s" without specifying the type parameter, so this technically complies — but `BciDeviceManager` uses strongly-typed subscriptions (`StreamSubscription<BciConnectionState>?`, `StreamSubscription<List<BciDeviceInfo>>?`, etc., see `lib/Bci/BciDeviceManager.dart:28-30`). For local consistency and to surface mismatched stream types during future refactors, prefer:

```dart
StreamSubscription<BciConnectionState>? _stateSub;
StreamSubscription<List<BciDeviceInfo>>? _devicesSub;
StreamSubscription<List<BciChannelQuality>>? _signalSub;
StreamSubscription<BciCalibrationEvent>? _calibrationSub;
StreamSubscription<int>? _batterySub;
```

No runtime impact.

### 3. `BehaviorSubject` replay semantics may mislead consumers

Severity: documentation nit.

`BciNotifier.stream` is the stream of a non-seeded `BehaviorSubject<BciNotifierEvent>` (`lib/Bci/BciNotifier.dart:20, 72`). Because the subject carries heterogeneous event variants, a late subscriber receives **only the single most recent event regardless of variant** — e.g. they may receive a stale `BciBatteryUpdated(73)` from an earlier session while the current connection state is `disconnected`. The plan acknowledged this in passing, and the synchronous getters (`currentState`, `discoveredDevices`, `knownSerials`) are the intended bootstrap path.

The class-level doc comment notes "does not hold aggregate state; the manager owns the canonical device state", but it would help a downstream module author if `stream` got an explicit one-liner along the lines of *"late subscribers receive the most recent event of any variant; do not rely on it for initial state — call `currentState`/`discoveredDevices`/`knownSerials` instead."* Optional.

### 4. `fetchKnownSerials()` fires unconditionally on guest startup

Severity: behavioural note (not a bug).

`App.initialize()` runs `unawaited(bciRepository.fetchKnownSerials().catchError((Object e) { return <String>[]; }));` (`lib/Core/App.dart:151`) before the user is necessarily authenticated. For a guest startup this gRPC call will hit `GrpcAuthInterceptor` and fail with UNAUTHENTICATED; the `catchError` swallows the result and the cache stays as-is. Two consequences worth knowing:

- Pre-login auto-connect cannot work — which is correct (guests shouldn't have known devices), so no fix needed here.
- After the user logs in later in the session, the cache is **not** re-warmed automatically; the next refresh only happens on the next call site of `fetchKnownSerials()` (currently none exist). When the pairing screen lands, expect a "no cached serials → no auto-connect on first scan after sign-in" UX seam. Either the BciPairingService or a `userNotifier.stream` listener should trigger a re-fetch on `AuthenticatedState`.

Not in scope for this milestone — leave a forward note for the `BciPairingService` task.

### 5. Wiring placement is interleaved with `AppSettingsRepository` setup

Severity: style nit.

The BCI block (`lib/Core/App.dart:149-154`) is inserted between `final prefs = await SharedPreferences.getInstance();` and the `AppSettingsRepository`/`appSettingsNotifier` construction that also consumes `prefs`. The plan said "after `prefs` is loaded", which this satisfies, but visually the two `prefs` consumers are now split by an unrelated subsystem. Moving the BCI block down to immediately after the `appSettingsNotifier` line would keep the `prefs`-consumer block contiguous and group BCI wiring with the other late-stage notifiers (`tokenNotifier`, `breathInstructionStream`). Cosmetic only.

---

## What's correct

- Sealed `BciNotifierEvent` hierarchy mirrors `BciCalibrationEvent` (file-level doc, `final class` variants, `const` constructors); no `neiry_kit` imports; correct domain types referenced.
- All five manager streams are subscribed, each translation is 1:1, and `onError` paths uniformly `logPrint` + emit `BciError(e.toString())`.
- Public surface (getters + delegating commands) matches the plan exactly.
- `BehaviorSubject<BciNotifierEvent>()` is unseeded — correct given heterogeneous variants.
- `dispose()` cancels all subscriptions before closing the subject and forwarding to `manager.dispose()`.
- `App` field added, constructor parameter added, instantiation order respects the `prefs` precondition for `BciDeviceRepository`.
- `BciDevicesGrpcApi(grpcClient.bciDevicesService)` correctly substituted for the milestone's `grpcClient.channel` typo (the constructor takes a `BciDevicesServiceClient`, see `lib/Core/Grpc/GrpcClient.dart:32`).
- `BciDeviceManager.cachedSerials()` already exposed (`lib/Bci/BciDeviceManager.dart:76`) — `knownSerials` getter wires through cleanly.
- `App.dart` style rules respected: single-line initializers in `initialize()`, no trailing commas on those lines; constructor invocation retains its trailing-comma block style.

---

## Verdict

All findings are minor (style, documentation, or pre-existing concerns). The implementation is functionally correct and consistent with the plan.

REVIEW_PASS
