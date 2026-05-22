# Plan Review: Add Bluetooth runtime permissions for BCI scanning

**Plan:** `.ai-factory/plans/50-add-bluetooth-runtime-permissions-for-bci-scanning.md`
**Spec note:** `.ai-factory/notes/23-bci-bluetooth-permissions.md`
**Risk Level:** 🟡 Medium

The plan is structurally sound, follows the project's domain/module boundary, and the file paths are accurate. There are two material issues (one build-breaker, one platform-correctness) and a handful of smaller concerns worth resolving before implementation.

---

## Critical Issues

### C1. `permission_handler` is not added to `packages/bci_module/pubspec.yaml`

Task 1 instructs only `flutter pub add permission_handler` at the **root** `mind_mobile/pubspec.yaml`. But Task 10 imports `package:permission_handler/permission_handler.dart` inside
`packages/bci_module/lib/src/BciPairing/Views/BciDiscoverySection.dart`.

`packages/bci_module/pubspec.yaml` currently lists only `flutter`, `flutter_riverpod`, `mind_audio`, `mind_l10n`, `mind_ui` — no `permission_handler`. The package import will fail at analysis time and the build will break.

**Fix:** Either

- add `permission_handler: ^11.4.0` (matching the root version) to `packages/bci_module/pubspec.yaml`, OR
- move the `openAppSettings()` call out of the package and into a coordinator/host-side callback (so the package stays platform-agnostic).

Recommend the first option (simpler, plan-aligned). Update Task 1 accordingly and add a sentence to Task 10 noting the package dependency must already be declared.

### C2. iOS permission gate may throw on first launch (before user has been asked)

Task 6 says:

> iOS branch: read `Permission.bluetooth.status`; if `isDenied`, throw `BluetoothPermissionDeniedException`. If `undetermined`, fall through — CoreBluetooth will prompt automatically inside `requestDevices()`.

`PermissionStatus` in `permission_handler` does not have an `undetermined` value. On iOS, when the app has never used Bluetooth, `Permission.bluetooth.status` typically returns `PermissionStatus.denied` (it maps `CBManagerAuthorization.notDetermined` → `denied`). With the proposed logic, the **very first scan attempt** would throw `BluetoothPermissionDeniedException` and show the "Open Settings" alert before CoreBluetooth ever has a chance to display its native prompt.

**Fix options:**

1. On iOS, only treat `isPermanentlyDenied` (and possibly `isRestricted`) as a hard denial; let everything else fall through to `requestDevices()`, which causes CoreBluetooth to prompt.
2. On iOS, skip the permission_handler check entirely and rely on CoreBluetooth's built-in prompt; detect permanent denial later via a callback or post-scan status check.
3. Explicitly call `await Permission.bluetooth.request()` on iOS first; map only `isPermanentlyDenied` to the exception.

Recommend option 1 — it preserves the same architecture as Android (gate before scan) while avoiding the false-positive on cold start. The spec note (file 23) repeats the same flawed assumption and should be updated alongside the plan.

---

## Major Issues

### M1. Android — `locationWhenInUse` is requested unconditionally

Task 6 requests `Permission.bluetoothScan`, `Permission.bluetoothConnect`, and `Permission.locationWhenInUse` together on every Android device. With `BLUETOOTH_SCAN` declared `neverForLocation`, **Android 12+ (API 31+) does not require location permission for BLE scanning**. Requesting `locationWhenInUse` on Android 12+ causes an extra and unnecessary location prompt — exactly the rationale `neverForLocation` was added to avoid.

**Fix:** Conditionally include `locationWhenInUse` only when `Build.VERSION.SDK_INT < 31`. Use `device_info_plus` (already a project dependency, see root `pubspec.yaml`) to read `androidInfo.version.sdkInt`. Apply the same condition to the `isPermanentlyDenied` check so a future Android-12-only user is never blocked by a location denial that doesn't actually matter.

### M2. `_attemptReconnect()` is not patched

Task 7 patches the `onError` handler in `BciDeviceManager.startScan()` only. `BciDeviceManager._attemptReconnect()` (lines 175–204) has its own `_provider.scan().listen(... onError: ...)` block that also calls `_setState(BciConnectionState.disconnected)` on any error. If permission is revoked between app sessions and the user reopens the app with a previously-paired device, the reconnect path will emit `disconnected` instead of `bluetoothPermissionDenied`, suppressing the alert.

**Fix:** Apply the same `if (e is BluetoothPermissionDeniedException)` branch to the `_attemptReconnect()` `onError` handler. The behavior should match exactly.

---

## Minor Issues / Recommendations

### m1. No path back from `bluetoothPermissionDenied` state after grant

After the user is shown the alert, taps "Open Settings", grants permission, and returns to the app, nothing in the plan re-triggers `startScan()`. `BciPairingViewModel.initState()` is guarded by `if (_eventsSubscription != null) return;` and the screen is unlikely to be unmounted while in Settings (Riverpod keeps the provider alive while the route is on the stack). The user could be stuck with no devices listed and no spinner — the only recovery is to navigate away and back.

**Suggested fix:** Add a lifecycle hook (e.g. `WidgetsBinding.instance.addObserver` for `AppLifecycleState.resumed`) in `BciDiscoverySection` that calls `service.startScan()` if `isBluetoothPermissionDenied` is true. Out of scope for the original spec, but worth adding to the plan or explicitly deferring with a TODO.

### m2. `disconnected` reducer does not clear `isBluetoothPermissionDenied`

Task 9 clears the flag only on `scanning`. If the manager transitions `bluetoothPermissionDenied → disconnected` (e.g. via a user-driven `disconnect()` or some other state-machine path), the flag remains `true`. This is unlikely to cause visible bugs given current flows, but should be either documented as intentional or also cleared in the `disconnected` branch for symmetry.

### m3. NeiryBciProvider has no logging for the permission-denied path

Plan settings say "logging: minimal", and `BciDeviceManager` will log on the denied branch. But adding a single `logPrint('NeiryBciProvider: bluetooth permission denied')` just before each `throw const BluetoothPermissionDeniedException()` would make the platform side easier to debug from device logs (where the exception type is sometimes obscured).

### m4. `flutter gen-l10n` step in Task 11

The plan says regeneration "happens automatically on the next `flutter run`" but also says "run `flutter gen-l10n` if needed". Generated `app_localizations*.dart` files **are** checked into the repo (`packages/mind_l10n/lib/l10n/`). Make this unconditional — the implementer must regenerate and commit, otherwise other branches/CI may fail to compile.

### m5. Architectural coupling note

Adding `permission_handler` to the otherwise-pure presentation package `bci_module` couples that package to a platform plugin. This is acceptable for `openAppSettings()` (genuinely a UI-side concern), but worth recording — future packages should consider exposing a host-injected callback instead of importing the plugin directly.

---

## Context Gates

- **ARCHITECTURE.md:** plan respects domain/module boundary. Provider stays domain-only, alert lives in UI layer, DTOs unchanged. ✅
- **RULES.md:** rule 1 (stateless module Service) — `BciPairingService` remains stateless after the reducer change. ✅ Rule 3 (DI via constructor) — not affected.
- **ROADMAP.md:** not checked in this review; verify task 50 corresponds to a tracked roadmap item before commit.

---

## Positive Notes

- Correct decision to keep `openAppSettings()` out of `NeiryBciProvider` — preserves the domain-vs-UI split.
- `BluetoothPermissionDeniedException` placed in `lib/Bci/Models/` is the right location for the shared exception type.
- The transition-edge detection (`prev?.isBluetoothPermissionDenied != true && next.isBluetoothPermissionDenied == true`) correctly avoids re-showing the dialog on every rebuild.
- Reuse of existing `cancel` l10n key is the right call.
- `neverForLocation` flag in the manifest is correctly noted as the way to keep Android 12+ off the location rationale path.
- Commit grouping cleanly maps to phases — manifest/deps, domain wiring, UI/l10n.
