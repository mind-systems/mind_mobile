# Plan Review 2: Add Bluetooth runtime permissions for BCI scanning

**Plan:** `.ai-factory/plans/50-add-bluetooth-runtime-permissions-for-bci-scanning.md`
**Spec note:** `.ai-factory/notes/23-bci-bluetooth-permissions.md`
**Prior review:** `plan-reviews/50-...-plan-review-1.md`
**Risk Level:** 🟡 Medium

This revision resolves every blocker called out in review 1 — package-level `permission_handler` dependency (Task 1), iOS cold-start gating (Task 6 → only `isPermanentlyDenied`/`isRestricted` throws), Android SDK<31 conditional `locationWhenInUse` (Task 6), `_attemptReconnect()` patching (Task 7), `disconnected` reducer clearing the flag (Task 9), unconditional `flutter gen-l10n` (Task 11), and the auto-rescan-on-resume lifecycle hook (Task 10). File paths, enum location, exception placement, l10n key choices, and reducer fields all match the actual code.

One real implementation blocker remains in Task 10, plus a few smaller correctness/robustness gaps.

---

## Critical Issues

### C1. Task 10 calls `bciPairingViewModelProvider.notifier.startScan()` — that method does not exist

Task 10's lifecycle hook says:

> call `ref.read(bciPairingViewModelProvider.notifier).startScan()` (or the equivalent ViewModel method already used by the "Scan" button)

Verified against `packages/bci_module/lib/src/BciPairing/BciPairingViewModel.dart`:
- The public surface is `initState()`, `onDeviceTap()`, `onStartCalibration()`, `onDisconnect()`, `onClose()`.
- There is **no** `startScan()` method on the ViewModel.
- There is **no** "Scan" button or rescan gesture in `BciDiscoverySection.dart`; scanning is kicked off exactly once from `BciPairingViewModel.initState()` (guarded by `if (_eventsSubscription != null) return;`), so re-calling `initState()` is a no-op.

Calling the non-existent method would fail at compile time, and calling `initState()` again would silently do nothing. The implementer is therefore stuck.

**Fix:** Add a sub-task (or extend Task 10) to introduce a public re-scan entry point on the ViewModel — e.g.

```dart
void onRescan() => service.startScan();
```

— and reference `onRescan()` from both the lifecycle hook and any future Scan button. Alternative: explicitly document calling `ref.read(bciPairingViewModelProvider.notifier).service.startScan()` via the public `service` field (works, but leaks the service through the ViewModel and is uglier).

### C2. `_setState` dedup will swallow the second `bluetoothPermissionDenied` event during reconnect

Task 7 adds `_setState(BciConnectionState.bluetoothPermissionDenied)` inside `_attemptReconnect()`. `_setState` dedupes (`if (_disposed || next == _state) return;`, line 81). Sequence:

1. User has cached serial. App resumes, `_attemptReconnect()` runs → state goes `disconnected → scanning → bluetoothPermissionDenied`. Reducer fires alert.
2. User taps "Cancel" instead of "Open Settings". No state change.
3. App backgrounds + resumes. The Task 10 resume hook fires `service.startScan()` → `manager.startScan()` bypasses dedup and emits `scanning` (line 104, intentional) → provider re-throws → `_setState(bluetoothPermissionDenied)`. **This** path works because `startScan()` first walks state through `scanning`.
4. But on a path that goes `bluetoothPermissionDenied → _attemptReconnect()` directly (e.g. an unexpected disconnect listener fires while state is `bluetoothPermissionDenied` → `_setState(disconnected)` → reconnect), `_attemptReconnect()` issues `_setState(scanning)` (line 176). That one **does** dedupe, but state is `disconnected` so it propagates. Good. Then on the next throw, `_setState(bluetoothPermissionDenied)` propagates. Also good.

After tracing the actual paths, the dedup is **not** a real problem given `startScan()` bypasses dedup explicitly. Downgrading from Critical to a Minor note — please add a sentence to Task 7 calling out that the dedup behaviour was considered and is safe because `startScan()` always reasserts `scanning` first.

(Removing from Critical — see m4 below for the documentation request.)

---

## Major Issues

### M1. Task 10 lifecycle hook needs `mounted` guard before `ref.read` and `showDialog`

Task 10 makes the section a `WidgetsBindingObserver` and calls `ref.read(bciPairingViewModelProvider.notifier).<rescan>()` from `didChangeAppLifecycleState`. `ConsumerState.dispose()` removes the observer, so in normal flow this is safe — but if a resume event is delivered in the same frame the route is popped, the callback can fire on an unmounted state. Same risk for `showDialog`: the listener edge fires during widget rebuild, but if the alert dialog is invoked from a transition that happens to coincide with screen disposal, calling `showDialog(context: ...)` against a disposed context will throw.

**Fix:** Add `if (!mounted) return;` at the top of both `didChangeAppLifecycleState` (the resumed branch) and the helper `_showBluetoothPermissionAlert` call site (or the listen callback before invoking the helper). Cheap insurance.

### M2. iOS `Permission.bluetooth` is deprecated for status queries on newer iOS

`permission_handler` exposes `Permission.bluetooth.status` but the underlying iOS authorization API (`CBManagerAuthorization`) is only meaningfully populated after a `CBCentralManager` instance exists. On a true cold start with no central manager yet created, `Permission.bluetooth.status` can return `.denied` even when the user has never been asked. The plan claims:

> Everything else (including `denied`, which on iOS first launch maps from `CBManagerAuthorization.notDetermined`) falls through so CoreBluetooth presents its native prompt when `requestDevices()` runs.

That is the **intended** behaviour and matches `permission_handler`'s documented mapping — but in practice the mapping has changed across plugin versions and iOS releases. Worth confirming on the actual `^11.4.0` build that `Permission.bluetooth.status` on a never-asked iOS device returns `denied` (not `permanentlyDenied`), otherwise the gate will false-positive again.

**Fix:** Add an implementer verification step to Task 6:

> After implementing, run on a fresh iOS simulator (delete app between runs) and confirm `Permission.bluetooth.status` returns `.denied` (not `.permanentlyDenied`) before CoreBluetooth has prompted. If `.permanentlyDenied` is returned, fall through on it too and rely solely on CoreBluetooth's native prompt; flip the alert trigger to a `denied`-after-grant detection.

This isn't a blocker but it is the single iOS-side claim most likely to bite during QA.

---

## Minor Issues / Recommendations

### m1. Task 6 — `requestDevices()` arguments not preserved literally

The plan says "yield* the existing `_locator.requestDevices(...)` stream mapped to `BciDeviceInfo`." The existing call is:

```dart
_locator.requestDevices(type: NeiryDeviceType.headband, searchTime: 5)
```

Spell out the named args in the task so the implementer doesn't accidentally drop or change them while rewriting the body as `async*`.

### m2. Task 2 — manifest insertion point is currently ambiguous

`android/app/src/main/AndroidManifest.xml` has `<application>` as the first child of `<manifest>`, then `<queries>`, then end-of-manifest. The plan says "before `<application>`". Strictly that requires moving `<application>` down. Practically the permission elements can sit anywhere inside `<manifest>` (XML element order under `<manifest>` is not significant for permissions). Loosen the wording or pick a concrete anchor (e.g. "as the first children inside `<manifest>`, immediately after the opening tag").

### m3. Task 6 — note the `_subject.add(BciError(...))` echo from `BciNotifier`

`BciNotifier` forwards every manager `stateStream` event verbatim, so the new `bluetoothPermissionDenied` state will arrive at the service reducer as a normal `BciStateChanged`. Good. But `BciNotifier` also has an `onError` on `stateStream` (line 32) that emits `BciError(e.toString())`. The plan's gate path doesn't go through `stateStream.onError` (the exception comes through `_scanSub.onError` and is converted to a clean `_setState` call by `BciDeviceManager`), so no error message will be set. Confirm in implementation that no stray `BciError` is emitted alongside `bluetoothPermissionDenied`, otherwise the reducer would leave a stale `errorMessage` on the state.

Recommend explicitly setting `errorMessage: null` in the new reducer branch (Task 9 already does this — ✅) and noting in Task 7 that the conversion happens in `BciDeviceManager`, not via `BciError`.

### m4. Task 7 — document the dedup interaction

Add a sentence to Task 7 explaining the `_setState` dedup considered for `bluetoothPermissionDenied`: it is safe in `startScan()` because the manager bypasses dedup when re-entering `scanning` (lines 100–107), so the next denial will always be a real state transition. Without this note the next reviewer will repeat the analysis.

### m5. Task 8 — `copyWith` sentinel pattern

`BciPairingState.copyWith` uses a `_undefined` sentinel pattern for nullable fields. `isBluetoothPermissionDenied` is a plain non-nullable `bool` defaulting to `false`, so a `bool?` parameter with `?? this.isBluetoothPermissionDenied` is the correct shape — matches the plan. Just confirming the implementer doesn't accidentally adopt the sentinel pattern for it (would be over-engineering).

### m6. iOS permission key naming

`NSBluetoothAlwaysUsageDescription` is the legacy key. For iOS 13+ the recommended key is `NSBluetoothPeripheralUsageDescription` (peripheral mode) plus `NSBluetoothAlwaysUsageDescription` for background scanning. For a foreground BLE central scanner like this app, `NSBluetoothAlwaysUsageDescription` alone is sufficient and is what `permission_handler` recommends — but worth a note that this app does not need `NSBluetoothPeripheralUsageDescription` because it never acts as a peripheral.

### m7. Task 1 — `pubspec.lock` files listed

Listing `pubspec.lock` files as "files to change" is misleading — they're regenerated by `flutter pub get`, not hand-edited. The implementer should commit them but not "edit" them. Minor wording fix.

---

## Context Gates

- **ARCHITECTURE.md** — plan respects the domain/module boundary: the permission check stays in the domain `NeiryBciProvider`; `openAppSettings()` stays in the UI layer. The coupling note in Task 1 is the right call. ✅
- **RULES.md** — Rule 1 (stateless Service) preserved: `BciPairingService` adds only a reducer branch and a field copy, no state, no streams, no `dispose()`. ✅ Rule 3 (constructor DI) — not affected by this change.
- **ROADMAP.md** — not verified in this pass; confirm task #50 is tied to a tracked roadmap milestone before commit.

---

## Positive Notes

- Every C/M finding from review 1 has been folded into the plan and the spec note. Clean turnaround.
- Conditional Android `locationWhenInUse` gated on `sdkInt < 31` is implemented correctly — checks only the requested permissions for permanent denial, avoiding a phantom block on Android 12+.
- `_attemptReconnect()` patching with the identical `is BluetoothPermissionDeniedException` branch closes the silent-denial gap for the auto-reconnect path. Architecturally sound.
- Clearing `isBluetoothPermissionDenied` in **both** `scanning` and `disconnected` reducer branches kills the "flag sticks" failure mode.
- The lifecycle observer for `AppLifecycleState.resumed` is the right scope — only re-scans when the flag is set, so it doesn't spam scans on every backgrounding.
- The Task 1 architectural note correctly identifies the package coupling cost and the future direction (host-injected callback).
- Reusing the existing `cancel` l10n key is correct.
- Unconditional `flutter gen-l10n` requirement on Task 11 prevents the silent CI break.
- Commit grouping cleanly maps to phases.

---

## Recommendation

Resolve C1 (add `onRescan()` or equivalent to `BciPairingViewModel` and reference it from Task 10) and M1 (add `mounted` guards). M2 is QA-time verifiable and doesn't block implementation. Everything else is minor polish. Once C1 and M1 are addressed, this plan is ready for `/aif-implement`.
