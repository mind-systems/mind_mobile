# BCI Connection Domain — `BciConnectionState` Serial Gap

**Date:** 2026-06-05
**Source:** conversation context

## Key Findings

- `BciConnectionState` is a bare enum: `connecting` carries no device serial. Every downstream consumer that needs to know *which* device is connecting must work around this gap.
- `BciNotifier` auto-connects known devices without going through `BciPairingService.connectDevice(serial)`, so any UI-level serial tracking based on user tap is blind to auto-connect.
- The workaround (`_connectingSerial` mutable field in `BciPairingService`) breaks reducer purity and is fragile — auto-connect requires a heuristic fallback (`devices.length == 1`).
- The correct fix is one level deeper: `BciConnectionState.connecting` should carry the device serial as associated data. `BciConnectionState` lives in `lib/Bci/Models/BciConnectionState.dart` (app code, not SDK), so it can be changed.

## Details

### The gap

`BciConnectionState` is an enum:

```
disconnected | scanning | bluetoothPermissionDenied | connecting | impedance | calibrating | ready
```

`connecting` is a bare value — no serial attached. `BciNotifier` emits `BciStateChanged(BciConnectionState.connecting)` when a connection attempt starts, but the event carries no identity. The reducer in `BciPairingService` receives it and has no way to know which device.

### How it surfaced

When implementing the "blue bluetooth icon for connected device" UX, the widget needed to know which cell is the connected device. The first attempt tracked this with `_pendingSerial` in widget state, set on user tap. This worked for tap-initiated connects but broke completely for auto-connect:

```
// from logs:
isConnecting false → true | _pendingSerial=null   ← connecting started, but no tap happened
✓ connected: setting _connectedSerial=null         ← trigger fired, serial was null
```

`BciNotifier` had already initiated the connection for a known device before the user touched anything. The `onTap` log never appeared.

### The workaround and its smells

To fix the immediate UX bug, `connectedSerial` was added to `BciPairingState` and `_connectingSerial` was added as a mutable field to `BciPairingService`:

```dart
class BciPairingService {
  String? _connectingSerial;   // ← mutable side-channel

  void connectDevice(String serial) {
    _connectingSerial = serial; // ← set by command method
    unawaited(bciNotifier.connectDevice(serial));
  }

  BciPairingState _reduceStateChanged(BciPairingState acc, BciConnectionState state) {
    case BciConnectionState.connecting:
      // fallback for auto-connect (BciNotifier bypasses connectDevice())
      _connectingSerial ??= acc.devices.length == 1 ? acc.devices.first.serial : null;
      return acc.copyWith(connectedSerial: _connectingSerial, ...);
  }
}
```

Two smells:

1. **Impure reducer.** `_reduceStateChanged` reads `_connectingSerial`, which is set by a command method, not by the incoming event. A reducer should be `(acc, event) → state` with no outside reads. Now it has temporal coupling to command invocation order.

2. **Fragile auto-connect fallback.** `devices.length == 1` is a heuristic. If multiple devices are scanned and `BciNotifier` auto-connects, `_connectingSerial` stays null and `connectedSerial` is never set.

### Why auto-connect and user-tap diverge

`BciPairingViewModel.onDeviceTap(serial)` → `service.connectDevice(serial)` → sets `_connectingSerial`.

Auto-connect: `BciNotifier` calls its own native connect path internally. `BciPairingService.connectDevice` is never invoked. The service only learns about the connection from the `BciStateChanged(connecting)` event, which carries no serial.

### The right fix

`BciConnectionState.connecting` should carry the device serial:

```dart
// Option A — sealed class / union
sealed class BciConnectionState { ... }
class BciConnecting extends BciConnectionState {
  final String serial;
}

// Option B — separate event from BciNotifier
case BciDeviceConnecting(:final serial):  // in BciNotifierEvent
```

With either option the reducer becomes pure: when it sees `connecting(serial: "820566")` it sets `connectedSerial: "820566"` directly from the event. `_connectingSerial` disappears. Auto-connect and user-tap become identical paths through the same reducer branch.

### Files involved

| File | Role |
|------|------|
| `lib/Bci/Models/BciConnectionState.dart` | The enum that needs the serial — app code, changeable |
| `lib/Bci/BciNotifier.dart` | Emits `BciStateChanged`; also triggers auto-connect for known devices |
| `lib/BciModule/BciPairingService.dart` | Contains `_connectingSerial` side-channel and impure reducer branch |
| `packages/bci_module/lib/src/BciPairing/Models/BciPairingState.dart` | `connectedSerial` added as workaround field |
| `packages/bci_module/lib/src/BciPairing/Views/BciDiscoverySection.dart` | Was the symptom — had business logic in widget state |

### `isConnecting` flag

With `connectedSerial` now in state, `isConnecting` is partially redundant: the "connecting" phase can be expressed as `connectedSerial != null && stage == discovery`. It still has value as an explicit flag for UX (e.g. disabling tap during connecting) but is no longer the primary signal for identity.

## Open Questions

- Does `BciConnectionState` changing to a sealed class require changes in `neiry_kit` consumers, or is it used only inside `lib/Bci/`?
- Does `BciNotifier` have a hook point where auto-connect serial could be emitted as a `BciDeviceConnecting` event, or would that require native SDK changes?
- Should `isConnecting` be removed once `connectedSerial` covers the connecting phase, or kept for explicit UX gating?
