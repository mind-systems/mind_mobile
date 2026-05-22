# Code Review: Add Bluetooth runtime permissions for BCI scanning

**Plan:** `.ai-factory/plans/50-add-bluetooth-runtime-permissions-for-bci-scanning.md`
**Spec:** `.ai-factory/notes/23-bci-bluetooth-permissions.md`
**Scope of review:** all staged + modified files in the working tree for this milestone (excluding plan/plan-review docs).

The implementation closely follows the plan and the prior plan-review revisions are honoured. Wiring is correct end-to-end: `NeiryBciProvider.scan()` → `BciDeviceManager.startScan()/_attemptReconnect()` → `BciNotifier` → `BciPairingService._reduceStateChanged` → `BciPairingState.isBluetoothPermissionDenied` → `BciDiscoverySection`'s `ref.listen` and `WidgetsBindingObserver` lifecycle hook → `onRescan()`. The new `BluetoothPermissionDeniedException` is placed correctly, the enum addition is minimal, both manifest entries are present, and the localizations are regenerated.

Findings below ordered by severity. None are blockers, but two are worth tightening before ship.

---

## Major

### M1. `_attemptReconnect()` `onError` comment is misleading and the dedup safety is more fragile than it claims

`lib/Bci/BciDeviceManager.dart:204-206` adds a comment that says:

> Same dedup analysis as startScan: _attemptReconnect re-asserts scanning before subscribing, so bluetoothPermissionDenied is always a real transition, never deduped.

But the two paths are **not** the same. `startScan()` (lines 100–108) deliberately **bypasses** `_setState`:

```dart
_state = BciConnectionState.scanning;       // direct assignment, no dedup
_stateController.add(BciConnectionState.scanning);
```

`_attemptReconnect()` (line 185) uses `_setState(BciConnectionState.scanning)` — which **does** dedup. The dedup happens to be safe here only because the **only caller** of `_attemptReconnect()` is the disconnect listener at lines 42–52, which runs `_setState(disconnected)` on line 48 **before** invoking `_attemptReconnect()`. So `_state == disconnected` when `_attemptReconnect()` starts, and the `_setState(scanning)` at line 185 always fires.

If a future change ever calls `_attemptReconnect()` from another path that leaves `_state` already at `scanning` (or `bluetoothPermissionDenied` reached via a future state path), the dedup will silence both the `scanning` event **and** the subsequent denial event will fire on a stale `_state`, which is precisely the failure mode the comment claims is impossible.

**Suggested fix:** either (a) replace the comment with the actual analysis ("safe because the only caller leaves `_state == disconnected` before calling us; if you add another caller, audit this"), or (b) match the `startScan()` pattern — bypass `_setState` at line 185 with a direct assignment + `_stateController.add(scanning)`. Option (b) makes the safety property local to this method instead of a cross-method invariant.

### M2. Android normal-denial path leaks the scan UI into a permanent spinner

`lib/Bci/NeiryBciProvider.dart:87-90`:

```dart
final allGranted = permissions.every((p) => statuses[p]?.isGranted == true);
if (!allGranted) {
  // Normal denial — return silently; Android will re-prompt next time.
  return;
}
```

The plan explicitly designs this path: an `async*` `return` closes the stream cleanly (no error). But `BciDeviceManager.startScan()` (lines 113–144) registers only `onData` and `onError` on the subscription — **no `onDone`**. When the stream closes silently, the listener simply receives a `done` event and the manager is left in `BciConnectionState.scanning` indefinitely. The UI's `LinearProgressIndicator` in `BciDiscoverySection.dart:91` spins forever, the user sees no dialog (this is a normal denial, by design), and the only escape is to navigate away.

`_attemptReconnect()` has an `onDone` handler (lines 215–219) that recovers to `disconnected`; `startScan()` does not. This is partly a pre-existing UX issue (the same happens after a successful `searchTime: 5` scan that found nothing), but the new normal-denial path makes it more visible and more reachable.

**Suggested fix:** add an `onDone` to `BciDeviceManager.startScan()` that transitions back to `disconnected` when `_state == scanning` (mirroring `_attemptReconnect`'s onDone but without the `_connectedSerial != null` guard, since `startScan()` is the initial-discovery path). Even a `_setState(disconnected)` is enough to clear the spinner.

---

## Minor

### m1. App's `ACCESS_FINE_LOCATION` declaration is broader than necessary

`android/app/src/main/AndroidManifest.xml:5`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

The `neiry_kit` plugin manifest (`neiry_kit/android/src/main/AndroidManifest.xml:12`) already declares the same permission with `android:maxSdkVersion="30"`. In the manifest merger, the app's declaration takes precedence over the library's, so the merged manifest applies `ACCESS_FINE_LOCATION` on **all** SDK versions — including Android 12+ where `BLUETOOTH_SCAN`'s `neverForLocation` flag is supposed to make it unnecessary.

Functionally this is fine: runtime requests are correctly gated by `if (sdkInt < 31)` in `NeiryBciProvider`. The bloat is in Play Store metadata: the store will list the app as requesting location on all devices, which can prompt a "why does this app need location?" privacy review.

**Suggested fix:** mirror the plugin's bound:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"
    android:maxSdkVersion="30" />
```

### m2. iOS `Permission.bluetooth.status` cold-start mapping is the documented risk; verify in QA

Plan-review-2 already flagged this; calling it out so it doesn't get lost in implementation:

`lib/Bci/NeiryBciProvider.dart:59-66` treats only `.isPermanentlyDenied` and `.isRestricted` as denial. This depends on `permission_handler ^11.4.0` mapping `CBManagerAuthorizationNotDetermined` → `PermissionStatus.denied` (not `permanentlyDenied`) on iOS. The implementation is correct **if** that mapping holds. Cold-start QA on a fresh simulator (delete the app between runs) is the only way to confirm — the mapping has shifted across plugin versions and iOS releases.

If on cold start the status returns `.permanentlyDenied`, the very first scan will throw and show the alert before CoreBluetooth ever prompts. Falls under the QA verification step the plan calls out at Task 6.

### m3. Dialog re-shows on every fresh entry into the section while permission is denied

`packages/bci_module/lib/src/BciPairing/Views/BciDiscoverySection.dart:77-81`:

```dart
if (prev?.isBluetoothPermissionDenied != true &&
    next.isBluetoothPermissionDenied == true) {
  if (!mounted) return;
  _showBluetoothPermissionAlert(context, l10n);
}
```

When the screen is unmounted and remounted (route push/pop), the first invocation of `ref.listen` sees `prev == null`. `null?.isBluetoothPermissionDenied` is `null`, `null != true` is `true`, so any `next.isBluetoothPermissionDenied == true` triggers the dialog. Whether this is desirable depends on intent: re-showing the dialog every time the user re-enters the section is more aggressive than the spec implies ("show when the flag flips true"). Minor UX choice — flag for product review, no code change required unless undesired.

### m4. The unexpected-disconnect listener does not exclude `bluetoothPermissionDenied`

`lib/Bci/BciDeviceManager.dart:42-52`:

```dart
if (state == BciConnectionState.disconnected &&
    _state != BciConnectionState.disconnected &&
    _state != BciConnectionState.scanning &&
    _state != BciConnectionState.connecting) {
  ...
  if (!_suppressAutoReconnect && _connectedSerial != null) {
    unawaited(_attemptReconnect());
  }
}
```

If a `disconnected` event arrives from the provider while `_state == bluetoothPermissionDenied`, this branch fires. In practice it's benign because `_connectedSerial` is null in that state (no connection was ever established before denial), so `_attemptReconnect()` is not called. But the analysis depends on that invariant being true, which is implicit and easy to break. Consider explicitly excluding `bluetoothPermissionDenied` from the filter so the property is local and obvious. Pure defensive hardening.

### m5. `Permission.bluetoothScan` / `bluetoothConnect` are requested on Android <12 even though they auto-grant

`lib/Bci/NeiryBciProvider.dart:71-77`:

```dart
final permissions = [
  Permission.bluetoothScan,
  Permission.bluetoothConnect,
  if (sdkInt < 31) Permission.locationWhenInUse,
];
```

On Android <12, `Permission.bluetoothScan` / `Permission.bluetoothConnect` map to the legacy `BLUETOOTH` permission (already granted as a normal permission), so `.request()` returns `.granted` instantly. Harmless but redundant. Symmetric to the Android-12+ branch — could mirror it (`if (sdkInt >= 31) Permission.bluetoothScan, ..., if (sdkInt < 31) Permission.locationWhenInUse`). Not worth changing unless you're touching the file anyway.

### m6. Generated localization arb file has a stray blank line

`packages/mind_l10n/lib/l10n/app_en.arb:128` and `app_ru.arb:122` add a blank line between the previous BCI keys and the new ones. ARB is JSON-style; blank lines in JSON are tolerated by parsers but inconsistent with the rest of the file. Cosmetic.

---

## Verification of plan-review-2 fix list

- ✅ C1 (review-2): `onRescan()` added at `BciPairingViewModel.dart:53`, called from `BciDiscoverySection._BciDiscoverySectionState.didChangeAppLifecycleState`.
- ✅ M1 (review-2): `mounted` guard at `BciDiscoverySection.dart:36` (lifecycle hook) and `:79` (before `_showBluetoothPermissionAlert`).
- ✅ M2 (review-2): iOS gate triggers only on `isPermanentlyDenied || isRestricted`; cold-start `denied` falls through. QA caveat preserved (see m2 above).
- ✅ Android conditional location: `if (sdkInt < 31)` correctly included; permanently-denied check loops over the **requested** permissions only, so SDK 31+ is never blocked by a location denial.
- ✅ `_attemptReconnect()` patched with the same exception branching (subject to the wording fix in M1).
- ✅ `disconnected` reducer branch clears `isBluetoothPermissionDenied` (`BciPairingService.dart:96`).
- ✅ `flutter gen-l10n` ran — `app_localizations*.dart` regenerated and staged.
- ✅ Package `pubspec.yaml` has `permission_handler: ^11.4.0`; root `pubspec.yaml` also has it. `pubspec.lock` updated for the root; package's `pubspec.lock` is `.gitignore`d (`packages/bci_module/.gitignore:26`), which is the convention for library packages and not a defect.
- ✅ `NSBluetoothPeripheralUsageDescription` correctly omitted (central-only app).
- ✅ `BciPairingState.copyWith` uses plain `bool? ?? this.isBluetoothPermissionDenied`, no `_undefined` sentinel for the new field — matches the plan's instruction at Task 8.

---

## Context gates

- **ARCHITECTURE.md** — domain/module boundary respected. `NeiryBciProvider` stays in the domain layer; `openAppSettings()` is invoked only from `BciDiscoverySection` in the UI layer. DTOs (`BciPairingState`) are extended with a non-nullable bool, no domain model leakage. ✅
- **RULES.md rule 1** (stateless module Service) — `BciPairingService` still pure: reducer-only change, no streams, no `dispose`. ✅
- **RULES.md rule 2** (no module-specific state in `App.dart`) — `App.dart` untouched. ✅
- **RULES.md rule 3** (constructor DI) — not affected.
- **AndroidManifest merger interaction** with `neiry_kit/android/src/main/AndroidManifest.xml` is correct; the legacy `BLUETOOTH` / `BLUETOOTH_ADMIN` permissions required for Android 6–11 BLE are already declared by the plugin and merged in. The app's manifest does not need to re-declare them.

---

## Positive notes

- `BluetoothPermissionDeniedException` placement under `lib/Bci/Models/` cleanly avoids a circular dependency between `NeiryBciProvider` and `BciDeviceManager`.
- Bypass-dedup logic in `startScan()` (direct `_state = scanning` + manual `add`) is the right call to ensure the new subscriber after `onRescan()` always sees a fresh `scanning` event.
- Symmetric clearing of `isBluetoothPermissionDenied` in both `scanning` and `disconnected` reducer branches kills the "flag sticks" failure mode.
- `permission_handler` is added at both the root and the `bci_module` package, so the import in `BciDiscoverySection` analyses cleanly.
- iOS Info.plist value is concise and user-facing ("Mind uses Bluetooth to connect to your Neiry headband.") — no jargon, no placeholder.
- The `WidgetsBindingObserver` registration/removal in `initState` / `dispose` is correctly paired.
- The Russian translation uses natural phrasing ("гарнитуре Neiry", "Разрешите доступ в Настройках") — no machine-translation artefacts.
