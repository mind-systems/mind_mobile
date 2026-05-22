# Plan: Add Bluetooth runtime permissions for BCI scanning

## Context
Wire Android/iOS Bluetooth runtime permissions into the BCI scan flow so the system dialog actually appears, and surface a settings-redirect alert when the user has permanently denied (Android) or previously denied (iOS) access. Full spec in `.ai-factory/notes/23-bci-bluetooth-permissions.md`.

Updated after plan-review-2: explicit `onRescan()` entry point on `BciPairingViewModel` (review-1 used a non-existent method); `mounted` guards on lifecycle and dialog callbacks; clarified manifest insertion anchor; preserved `requestDevices` named args; documented `_setState` dedup safety; clarified `pubspec.lock` is regenerated; noted iOS `NSBluetoothPeripheralUsageDescription` not needed; QA verification step for iOS cold-start status.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Dependencies and platform manifests

- [x] **Task 1: Add `permission_handler` package at both pubspec levels**
  Files edited: `pubspec.yaml`, `packages/bci_module/pubspec.yaml`
  Files regenerated (commit, do not hand-edit): `pubspec.lock`, `packages/bci_module/pubspec.lock`
  - Run `flutter pub add permission_handler` at the repo root (`mind_mobile/`). Use `^11.4.0` (matches `neiry_kit` example).
  - **Also** add `permission_handler: ^11.4.0` to `packages/bci_module/pubspec.yaml` under `dependencies:` (currently only `flutter`, `flutter_riverpod`, `mind_audio`, `mind_l10n`, `mind_ui` are listed). Then run `flutter pub get` inside `packages/bci_module/`. Without this, the import in Task 10 will fail at analysis time and break the build.
  - Do not edit the root `pubspec.yaml` manually — use `flutter pub add`. For the package, the dependency line in `packages/bci_module/pubspec.yaml` is the only manual edit needed.
  - Architectural note: importing `permission_handler` into `bci_module` couples that otherwise-pure presentation package to a platform plugin. Accepted because `openAppSettings()` is genuinely a UI-side concern. Future packages should prefer a host-injected callback over a direct plugin import.

- [x] **Task 2: Declare Android Bluetooth permissions** (depends on Task 1)
  Files: `android/app/src/main/AndroidManifest.xml`
  Add the following entries as the first children inside `<manifest>`, immediately after the opening tag (XML element order under `<manifest>` is not significant for permissions, but placing them at the top keeps the file readable and avoids reordering `<application>`/`<queries>`):
  ```xml
  <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
      android:usesPermissionFlags="neverForLocation" />
  <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
  ```
  `neverForLocation` avoids the location rationale on Android 12+. `ACCESS_FINE_LOCATION` is required because `minSdk = 26` so pre-Android-12 BLE scan is supported.

- [x] **Task 3: Declare iOS Bluetooth usage description** (depends on Task 1)
  Files: `ios/Runner/Info.plist`
  Add:
  ```xml
  <key>NSBluetoothAlwaysUsageDescription</key>
  <string>Mind uses Bluetooth to connect to your Neiry headband.</string>
  ```
  Note: do **not** add `NSBluetoothPeripheralUsageDescription`. This app only acts as a BLE central (scans for and connects to the Neiry headband); it never advertises as a peripheral. `NSBluetoothAlwaysUsageDescription` alone is sufficient and matches `permission_handler`'s recommendation for foreground BLE central scanners.

### Phase 2: Domain — exception, enum, provider, manager

- [x] **Task 4: Create `BluetoothPermissionDeniedException`** (depends on Task 1)
  Files: `lib/Bci/Models/BluetoothPermissionDeniedException.dart` (new)
  Define a const-constructible exception type:
  ```dart
  class BluetoothPermissionDeniedException implements Exception {
    const BluetoothPermissionDeniedException();
  }
  ```
  Keep it in `lib/Bci/Models/` so both `NeiryBciProvider` and `BciDeviceManager` import it without circular dependency.

- [x] **Task 5: Extend `BciConnectionState` enum** (depends on Task 4)
  Files: `lib/Bci/Models/BciConnectionState.dart`
  Add `bluetoothPermissionDenied` value to the enum (append after `ready`). Keep ordering of existing values unchanged.

- [x] **Task 6: Update `NeiryBciProvider.scan()` to gate on permissions** (depends on Tasks 4–5)
  Files: `lib/Bci/NeiryBciProvider.dart`
  - Add imports: `dart:io` (for `Platform`), `package:device_info_plus/device_info_plus.dart`, `package:permission_handler/permission_handler.dart`, `Models/BluetoothPermissionDeniedException.dart`.
  - Convert `scan()` to an `async*` generator.
  - **iOS branch:** read `Permission.bluetooth.status`. Treat **only** `isPermanentlyDenied` or `isRestricted` as a hard denial → `logPrint('NeiryBciProvider: bluetooth permission permanently denied (iOS)')` then throw `BluetoothPermissionDeniedException`. Everything else (including `denied`, which on iOS first launch maps from `CBManagerAuthorization.notDetermined`) falls through so CoreBluetooth presents its native prompt when `requestDevices()` runs. `permission_handler` does not expose an `undetermined` value on iOS.
    - **QA verification step:** after implementing, run on a fresh iOS simulator (delete the app between runs) and confirm `Permission.bluetooth.status` returns `.denied` (not `.permanentlyDenied`) before CoreBluetooth has prompted. If `.permanentlyDenied` is returned, fall through on it too and rely solely on CoreBluetooth's native prompt; in that case, flip the alert trigger to a `denied`-after-grant detection. The `permission_handler` ↔ `CBManagerAuthorization` mapping has shifted across plugin/iOS versions and is the single most likely iOS regression point.
  - **Android branch:**
    1. Read `androidInfo.version.sdkInt` via `DeviceInfoPlugin().androidInfo`.
    2. Build the permission list: always include `Permission.bluetoothScan` and `Permission.bluetoothConnect`. Add `Permission.locationWhenInUse` **only** when `sdkInt < 31` — on Android 12+ the `neverForLocation` flag makes the location prompt unnecessary, and requesting it anyway adds a redundant UX step.
    3. `await` the joint `.request()`.
    4. If any of the **requested** statuses is `isPermanentlyDenied`: `logPrint('NeiryBciProvider: bluetooth permission permanently denied (Android)')` then throw `BluetoothPermissionDeniedException`. (Only check the permissions actually requested — do not block on a `locationWhenInUse` denial on SDK 31+ since it was never asked for.)
    5. If not all granted (normal denial): `return` (yields empty stream silently; Android will re-prompt next time).
  - After the gate, preserve the existing call literally and yield:
    ```dart
    yield* _locator
        .requestDevices(type: NeiryDeviceType.headband, searchTime: 5)
        .map((list) => list
            .map((d) => BciDeviceInfo(serial: d.serial, name: d.name))
            .toList());
    ```
    Do not change `type:` or `searchTime:` when rewriting the body as `async*`.
  - Provider must not call `openAppSettings()` — domain code has no UI access.

- [x] **Task 7: Handle permission exception in both scan paths of `BciDeviceManager`** (depends on Tasks 5–6)
  Files: `lib/Bci/BciDeviceManager.dart`
  - Add import for `Models/BluetoothPermissionDeniedException.dart`.
  - In `startScan()` `onError`: branch on the error type. If it is a `BluetoothPermissionDeniedException`, log and call `_setState(BciConnectionState.bluetoothPermissionDenied)`. Otherwise keep the current `_setState(BciConnectionState.disconnected)` fallback. Preserve existing log messages.
  - **Also** patch `_attemptReconnect()` `onError` (lines 175–204) with the identical branching. Without this, a user who revokes permission between sessions and reopens the app with a previously-paired device hits the reconnect path and gets `disconnected` instead of `bluetoothPermissionDenied`, suppressing the alert.
  - **Note on `_setState` dedup:** `_setState` short-circuits when `next == _state`. This was checked and is safe for the new path because `startScan()` explicitly re-asserts `BciConnectionState.scanning` (manager lines ~100–107) before each scan attempt, so a subsequent `bluetoothPermissionDenied` is always a real state transition, never deduped. Document this inline in a comment near the new `onError` branch so future readers do not re-do the analysis.
  - **Note on `BciNotifier` error pathway:** the new exception is converted to a clean `_setState(bluetoothPermissionDenied)` inside `BciDeviceManager`; it never reaches `BciNotifier.stateStream.onError` (which would emit `BciError(...)`). Therefore no stray `errorMessage` is set on `BciPairingState`. Task 9 reinforces this by explicitly setting `errorMessage: null` in the reducer branch.

### Phase 3: Module — pairing state, service reducer, ViewModel entry point, UI alert

- [x] **Task 8: Add `isBluetoothPermissionDenied` to `BciPairingState`** (depends on Task 7)
  Files: `packages/bci_module/lib/src/BciPairing/Models/BciPairingState.dart`
  - Add non-nullable `final bool isBluetoothPermissionDenied;` field defaulting to `false`.
  - Thread it through the const constructor, `BciPairingState.initial()` factory, and `copyWith()`.
  - Use a plain `bool?` parameter with `?? this.isBluetoothPermissionDenied` in `copyWith` (matching the shape already used for the other non-nullable bool fields). Do **not** use the `_undefined` sentinel pattern that some nullable fields in this class use — it is unnecessary for a non-nullable bool defaulting to `false`.

- [x] **Task 9: Handle new connection state in `BciPairingService._reduceStateChanged`** (depends on Task 8)
  Files: `lib/BciModule/BciPairingService.dart`
  - Add a case for `BciConnectionState.bluetoothPermissionDenied`: return `copyWith(stage: BciPairingStage.discovery, isScanning: false, isConnecting: false, isBluetoothPermissionDenied: true, errorMessage: null)`.
  - In the existing `BciConnectionState.scanning` case, set `isBluetoothPermissionDenied: false` so the flag clears when the user retries a scan.
  - In the existing `BciConnectionState.disconnected` case, also set `isBluetoothPermissionDenied: false` for symmetry — prevents the flag from sticking if the state machine transitions `bluetoothPermissionDenied → disconnected` via a user-driven `disconnect()`.

- [x] **Task 10: Add `onRescan()` entry point to `BciPairingViewModel`** (depends on Task 8) — **new sub-task to resolve plan-review-2 C1**
  Files: `packages/bci_module/lib/src/BciPairing/BciPairingViewModel.dart`
  - The current public surface is `initState()`, `onDeviceTap()`, `onStartCalibration()`, `onDisconnect()`, `onClose()`. There is no rescan entry point — `service.startScan()` is only invoked once from `initState()`, which is guarded by `if (_eventsSubscription != null) return;` so re-calling it is a no-op.
  - Add a one-liner public method:
    ```dart
    void onRescan() => service.startScan();
    ```
    Place it near `onDeviceTap()`. Task 11 will reference this from the lifecycle hook. Same method will be reusable by any future Scan/Retry button in `BciDiscoverySection`.

- [x] **Task 11: Show settings-redirect alert and auto-rescan on resume in `BciDiscoverySection`** (depends on Tasks 1, 8–10, 12)
  Files: `packages/bci_module/lib/src/BciPairing/Views/BciDiscoverySection.dart`
  - Add import `package:permission_handler/permission_handler.dart` (for `openAppSettings()`). This requires the package-level dependency added in Task 1.
  - In the existing `ref.listen<BciPairingState>(bciPairingViewModelProvider, ...)` block, detect the transition `prev?.isBluetoothPermissionDenied != true && next.isBluetoothPermissionDenied == true`. Before invoking the helper, add `if (!mounted) return;` so we do not call `showDialog` against a disposed context if the listener edge happens to fire during route teardown.
  - Implement private helper `_showBluetoothPermissionAlert(BuildContext context, AppLocalizations l10n)` using `showDialog<void>` with `AlertDialog`: title `l10n.bciBluetoothPermissionTitle`, content `l10n.bciBluetoothPermissionMessage`, two `TextButton` actions — Cancel (uses existing `l10n.cancel`, dismisses) and Open Settings (uses `l10n.bciOpenSettings`, dismisses then calls `openAppSettings()`).
  - Do not store `context` — pass it to the helper at call time.
  - **Lifecycle hook for grant-then-return:**
    - Make the section's `State` class (a `ConsumerState`) also implement `WidgetsBindingObserver`.
    - In `initState()` register with `WidgetsBinding.instance.addObserver(this)`; in `dispose()` remove it with `WidgetsBinding.instance.removeObserver(this)`.
    - Override `didChangeAppLifecycleState(AppLifecycleState state)`. Top of body: `if (!mounted) return;`. Then, when `state == AppLifecycleState.resumed` AND `ref.read(bciPairingViewModelProvider).isBluetoothPermissionDenied == true`, call `ref.read(bciPairingViewModelProvider.notifier).onRescan()`. Reading the current state via `ref.read` avoids coupling to a build context.

### Phase 4: Localization

- [x] **Task 12: Add l10n keys for the alert and regenerate**
  Files: `packages/mind_l10n/lib/l10n/app_en.arb`, `packages/mind_l10n/lib/l10n/app_ru.arb`, `packages/mind_l10n/lib/l10n/app_localizations.dart`, `packages/mind_l10n/lib/l10n/app_localizations_en.dart`, `packages/mind_l10n/lib/l10n/app_localizations_ru.dart`
  Add three new keys in both ARB files:
  - `bciBluetoothPermissionTitle` — EN: `Bluetooth access required` / RU: `Нужен доступ к Bluetooth`
  - `bciBluetoothPermissionMessage` — EN: `Mind needs Bluetooth to connect to your Neiry headband. Please allow access in Settings.` / RU: `Mind использует Bluetooth для подключения к гарнитуре Neiry. Разрешите доступ в Настройках.`
  - `bciOpenSettings` — EN: `Open Settings` / RU: `Открыть настройки`
  Reuse the existing `cancel` key — do not add a duplicate.
  **Always** run `flutter gen-l10n` inside `packages/mind_l10n/` after editing ARBs. The generated `app_localizations*.dart` files are checked into the repo, so the implementer must regenerate and commit them — otherwise CI/other branches will fail to compile.

## Commit Plan
- **Commit 1** (after Tasks 1–3): "Add permission_handler dependency and platform Bluetooth permission entries"
- **Commit 2** (after Tasks 4–7): "Gate BCI scan on Bluetooth permissions and surface denial via connection state"
- **Commit 3** (after Tasks 8–12): "Show in-app Bluetooth permission alert with Open Settings action"

<!-- orchestrator-sessions
implementer: 191c367d-bd4f-4f3e-bfee-89eef38db3af
planner: 84c8017f-2753-454b-8fec-d4abc4385eb9
-->
