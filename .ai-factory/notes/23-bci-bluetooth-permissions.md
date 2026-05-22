# BCI Bluetooth runtime permissions

## Problem

`NeiryBciProvider.scan()` calls `_locator.requestDevices()` directly without requesting Bluetooth permissions first. Neither `AndroidManifest.xml` nor `Info.plist` declare the required permission entries. The system dialog never appears and the scan returns no devices.

When the user permanently denies permissions (or on iOS — any denial, since re-prompt is impossible), the app must show an in-app alert explaining why Bluetooth is needed and offering to open system Settings. `NeiryBciProvider` must not call `openAppSettings()` itself — it is domain code with no UI access.

## Platform behaviour

| Scenario | Behaviour |
|---|---|
| Android — first request | System dialog shown via `permission_handler`. If denied normally (not permanent), next `startScan()` will show dialog again — no alert needed. |
| Android — "Don't ask again" / permanent denial | System dialog will never show again → throw `BluetoothPermissionDeniedException` → in-app alert + Settings button. |
| iOS — first time | `Permission.bluetooth.status` is `undetermined` → skip permission gate → CoreBluetooth prompts automatically when `requestDevices()` runs. |
| iOS — any prior denial | `Permission.bluetooth.status` is `denied` → system will never re-prompt → throw `BluetoothPermissionDeniedException` → in-app alert + Settings button. |

## Files to change

### 1. Add `permission_handler` package

```
flutter pub add permission_handler
```

Use `^11.4.0` (matches neiry_kit example) or later compatible version.

### 2. `android/app/src/main/AndroidManifest.xml`

Add inside `<manifest>`, before `<application>`:

```xml
<!-- Bluetooth — Android 12+ (API 31+) -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<!-- Location required for BLE scan on Android < 12 -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

`neverForLocation` tells the system this app does not derive location from BT scan results — avoids triggering the location rationale on Android 12+. `minSdk = 26` so pre-12 support is needed.

### 3. `ios/Runner/Info.plist`

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Mind uses Bluetooth to connect to your Neiry headband.</string>
```

### 4. `lib/Bci/Models/BluetoothPermissionDeniedException.dart`  *(new file)*

```dart
class BluetoothPermissionDeniedException implements Exception {
  const BluetoothPermissionDeniedException();
}
```

Kept in `lib/Bci/Models/` so both `NeiryBciProvider` and `BciDeviceManager` can import it without a circular dependency.

### 5. `lib/Bci/Models/BciConnectionState.dart`

Add `bluetoothPermissionDenied` to the enum:

```dart
enum BciConnectionState {
  disconnected,
  scanning,
  connecting,
  impedance,
  calibrating,
  ready,
  bluetoothPermissionDenied,
}
```

### 6. `lib/Bci/NeiryBciProvider.dart`

Add imports:

```dart
import 'dart:io' show Platform;
import 'package:permission_handler/permission_handler.dart';
import 'Models/BluetoothPermissionDeniedException.dart';
```

Replace `scan()` with an `async*` generator:

```dart
@override
Stream<List<BciDeviceInfo>> scan() async* {
  if (Platform.isIOS) {
    // CoreBluetooth prompts on first use automatically.
    // If the user previously denied, status is `denied` — re-prompt impossible.
    final status = await Permission.bluetooth.status;
    if (status.isDenied) throw const BluetoothPermissionDeniedException();
  } else {
    // Android: request at runtime. Normal denial → empty stream (system will
    // re-prompt next time). Permanent denial → throw so UI can show alert.
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    if (statuses.values.any((s) => s.isPermanentlyDenied)) {
      throw const BluetoothPermissionDeniedException();
    }
    if (!statuses.values.every((s) => s.isGranted)) return; // normal denial — silent
  }
  yield* _locator
      .requestDevices(type: NeiryDeviceType.headband, searchTime: 5)
      .map((list) =>
          list.map((d) => BciDeviceInfo(serial: d.serial, name: d.name)).toList());
}
```

### 7. `lib/Bci/BciDeviceManager.dart`

Add import:

```dart
import 'Models/BluetoothPermissionDeniedException.dart';
```

In `startScan()`, update the `onError` handler to distinguish permission denial from generic scan errors:

```dart
onError: (Object e) {
  if (e is BluetoothPermissionDeniedException) {
    logPrint('BciDeviceManager: bluetooth permission denied');
    _setState(BciConnectionState.bluetoothPermissionDenied);
  } else {
    logPrint('BciDeviceManager: scan error: $e');
    _setState(BciConnectionState.disconnected);
  }
},
```

### 8. `packages/bci_module/lib/src/BciPairing/Models/BciPairingState.dart`

Add `isBluetoothPermissionDenied: bool` field (non-nullable, defaults `false`):

```dart
class BciPairingState {
  // ... existing fields ...
  final bool isBluetoothPermissionDenied;

  const BciPairingState({
    // ... existing params ...
    this.isBluetoothPermissionDenied = false,
  });

  static BciPairingState initial() => const BciPairingState(
    stage: BciPairingStage.discovery,
    devices: [],
    isScanning: false,
    isConnecting: false,
    channels: [],
    isBluetoothPermissionDenied: false,
  );

  BciPairingState copyWith({
    // ... existing params ...
    bool? isBluetoothPermissionDenied,
  }) {
    return BciPairingState(
      // ... existing ...
      isBluetoothPermissionDenied:
          isBluetoothPermissionDenied ?? this.isBluetoothPermissionDenied,
    );
  }
}
```

### 9. `lib/BciModule/BciPairingService.dart`

In `_reduceStateChanged`, add a case for `bluetoothPermissionDenied` and clear the flag on `scanning`:

```dart
case BciConnectionState.bluetoothPermissionDenied:
  return acc.copyWith(
    stage: BciPairingStage.discovery,
    isScanning: false,
    isConnecting: false,
    isBluetoothPermissionDenied: true,
    errorMessage: null,
  );

case BciConnectionState.scanning:
  return acc.copyWith(
    stage: BciPairingStage.discovery,
    isScanning: true,
    isConnecting: false,
    isBluetoothPermissionDenied: false,  // add this line
    errorMessage: null,
  );
```

### 10. `packages/bci_module/lib/src/BciPairing/Views/BciDiscoverySection.dart`

Add the alert to the existing `ref.listen` block:

```dart
ref.listen<BciPairingState>(bciPairingViewModelProvider, (prev, next) {
  // existing: clear _pendingSerial on connect complete
  if (...) setState(() => _pendingSerial = null);

  // new: show alert when permission is denied
  if (prev?.isBluetoothPermissionDenied != true &&
      next.isBluetoothPermissionDenied) {
    _showBluetoothPermissionAlert(context, l10n);
  }
});
```

Add helper (static, no `context` stored):

```dart
void _showBluetoothPermissionAlert(BuildContext context, AppLocalizations l10n) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.bciBluetoothPermissionTitle),
      content: Text(l10n.bciBluetoothPermissionMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            openAppSettings();
          },
          child: Text(l10n.bciOpenSettings),
        ),
      ],
    ),
  );
}
```

Add `import 'package:permission_handler/permission_handler.dart'` to `BciDiscoverySection.dart` (for `openAppSettings()`).

### 11. `packages/mind_l10n/` — add l10n keys

Add to all ARB files:

| Key | EN | RU |
|---|---|---|
| `bciBluetoothPermissionTitle` | `Bluetooth access required` | `Нужен доступ к Bluetooth` |
| `bciBluetoothPermissionMessage` | `Mind needs Bluetooth to connect to your Neiry headband. Please allow access in Settings.` | `Mind использует Bluetooth для подключения к гарнитуре Neiry. Разрешите доступ в Настройках.` |
| `bciOpenSettings` | `Open Settings` | `Открыть настройки` |

(`cancel` key already exists in the app.)
