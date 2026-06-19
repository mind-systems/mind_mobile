# Plan: BCI connection — split link-layer from domain phase + sealed identity

## Context
Splits the overloaded flat `BciConnectionState` enum into two types — a link-layer `BciLinkStatus { down, up }` for the provider stream and a sealed `BciConnectionState` hierarchy whose device-bound branches carry the `serial` — so multi-device auto-connect works without the `_connectingSerial` side-channel + `devices.length == 1` heuristic. Spec: `.ai-factory/notes/103-bci-connection-serial-gap.md`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: New types

- [x] **Task 1: Add `BciLinkStatus` link-layer enum**
  Files: `lib/Bci/Models/BciLinkStatus.dart` (new)
  Create `enum BciLinkStatus { down, up }` modelling only the provider's BLE link-layer state (nothing else). Add a short doc comment distinguishing it from the app-domain `BciConnectionState`.

- [x] **Task 2: Rewrite `BciConnectionState` enum → sealed hierarchy**
  Files: `lib/Bci/Models/BciConnectionState.dart`
  Replace the flat enum with a sealed class hierarchy exactly as in the spec:
  ```dart
  sealed class BciConnectionState { const BciConnectionState(); }
  class BciIdle             extends BciConnectionState { const BciIdle(); }            // was disconnected
  class BciScanning         extends BciConnectionState { const BciScanning(); }
  class BciPermissionDenied extends BciConnectionState { const BciPermissionDenied(); } // was bluetoothPermissionDenied
  sealed class BciActive extends BciConnectionState {
    final String serial;
    const BciActive(this.serial);
  }
  class BciConnecting  extends BciActive { const BciConnecting(super.serial); }
  class BciImpedance   extends BciActive { const BciImpedance(super.serial); }
  class BciCalibrating extends BciActive { const BciCalibrating(super.serial); }
  class BciReady       extends BciActive { const BciReady(super.serial); }
  ```
  Keep the existing distinction-from-`NeiryConnectionState` doc comment. Name mapping for downstream: `disconnected → BciIdle`, `scanning → BciScanning`, `bluetoothPermissionDenied → BciPermissionDenied`, and `connecting/impedance/calibrating/ready → BciConnecting/BciImpedance/BciCalibrating/BciReady` (serial-bearing).

### Phase 2: Provider layer

- [x] **Task 3: Retype the provider connection stream to `BciLinkStatus`** (depends on Task 1)
  Files: `lib/Bci/IBciDeviceProvider.dart`
  Change `Stream<BciConnectionState> get connectionStateStream` → `Stream<BciLinkStatus> get connectionStateStream`. Swap the `BciConnectionState` import for `BciLinkStatus`. Update the doc comment to say it emits link-layer up/down only.

- [x] **Task 4: Map Neiry link-layer events to `BciLinkStatus`** (depends on Task 1, Task 3)
  Files: `lib/Bci/NeiryBciProvider.dart`
  Change `_connectionStateController` to `StreamController<BciLinkStatus>.broadcast()` and the `connectionStateStream` getter type accordingly (`:43-44`, `:71-72`). In `_onNeiryConnectionState` (`:246-263`): `connected → BciLinkStatus.up` (drop the old `connected → BciConnectionState.connecting` mismap), `disconnected → BciLinkStatus.down`, `unsupportedConnection → BciLinkStatus.down`. Change the explicit-disconnect emit at `:592` to `BciLinkStatus.down`. Replace the `BciConnectionState` import with `BciLinkStatus`. Keep the `_device == null` idempotency guards and `_teardownAfterUnexpectedDrop()` calls unchanged. neiry_kit itself stays untouched.

### Phase 3: Manager

- [x] **Task 5: Drive `BciDeviceManager` from `BciLinkStatus` + emit sealed instances** (depends on Task 2, Task 4)
  Files: `lib/Bci/BciDeviceManager.dart`
  - Field `_state` init → `BciIdle()`; `_connectionStateSub` type → `StreamSubscription<BciLinkStatus>?`. Keep `String? _connectedSerial` as reconnect memory (do NOT delete).
  - `_subscribeProviderStreams` link listener: react to `BciLinkStatus.down` for the unexpected-disconnect path. Replace the multi-clause `_state != X` guard with `is`-checks — fire reconnect only when `_state is BciActive` (i.e. not Idle/Scanning/PermissionDenied). On down: `_setState(BciIdle())` then `_attemptReconnect()` when `!_suppressAutoReconnect && _connectedSerial != null`.
  - Calibration listener: `if (_state is BciCalibrating)` → on completed `_setState(BciReady((_state as BciCalibrating).serial))`; on failed `_setState(BciImpedance((_state as BciCalibrating).serial))`. Capture serial from the current `BciActive` state.
  - `_setState(BciConnectionState next)` dedup: `next == _state` no longer works for instances — replace with identity-by-runtime-type-and-serial. Simplest correct form: compare `runtimeType` and (for `BciActive`) `serial`. Document the dedup intent. (`startScan` keeps its direct-write bypass — set `_state = BciScanning()` and add to controller directly.)
  - `connectDevice(serial)` (`:195`): `_setState(BciConnecting(serial))`; on success set `_connectedSerial = serial` and, guarded by `if (_state is BciConnecting)`, `_setState(BciImpedance(serial))`; on failure `_setState(BciIdle())`.
  - `startScan` (`:138`, `:181`, `:189`) and `_attemptReconnect` (`:238`, `:264`, `:267`, `:272`): replace `scanning`/`disconnected`/`bluetoothPermissionDenied` with `BciScanning()`/`BciIdle()`/`BciPermissionDenied()`; replace `_state == BciConnectionState.scanning` with `_state is BciScanning`.
  - `startCalibration` (`:215-216`): `if (_state is! BciImpedance) return;` then `_setState(BciCalibrating((_state as BciImpedance).serial))`; on failure restore `BciImpedance(serial)`.
  - `disconnect` (`:234`): `_setState(BciIdle())`.
  - Update all `_stateController.add(...)` literal states and the `_state`/`_stateController`/`stateStream` generic types to `BciConnectionState` (still the type, now sealed). Adjust imports to pull in the new class names.
  - Exhaustive — no `default` anywhere.

### Phase 4: Module services

- [x] **Task 6: Rewrite `BciPairingService` reducer; delete side-channel + heuristic** (depends on Task 2, Task 5)
  Files: `lib/BciModule/BciPairingService.dart`
  - Delete the `_connectingSerial` field and the `devices.length == 1` heuristic entirely.
  - `connectDevice(String serial)`: drop the `_connectingSerial = serial` assignment; just call `bciNotifier.connectDevice(serial)`.
  - `startScan()` gate (`:41-44`): rewrite `current == BciConnectionState.X` checks as `is` checks — `current is BciIdle || current is BciScanning || current is BciPermissionDenied`.
  - `_reduceStateChanged` (`:102-184`): switch exhaustively over the sealed variants (`BciIdle`/`BciScanning`/`BciPermissionDenied`/`BciConnecting`/`BciImpedance`/`BciCalibrating`/`BciReady`), no `default`. Derive identity purely from the event: `connectedSerial = state is BciActive ? state.serial : null` (use the bound `serial` directly in each `BciActive` arm — `BciConnecting`/`BciImpedance`/`BciCalibrating`/`BciReady`), and `isConnecting = state is BciConnecting`. `BciIdle`/`BciScanning`/`BciPermissionDenied` arms set `connectedSerial: null`, `isConnecting: false`. Preserve the existing per-arm `copyWith` fields (stage, isScanning, error/battery/channel clearing, calibration seed). The reducer reads only `acc` and `event` — no external mutable reads.

- [x] **Task 7: Rewrite `BciDataService` connection switch** (depends on Task 2, Task 5)
  Files: `lib/BciModule/BciDataService.dart`
  In `_reduce`'s `BciStateChanged` arm (`:67-86`), replace the 7-arm enum switch with the sealed variants: `BciIdle`/`BciPermissionDenied` → the full reset branch (`isConnected: false`, clear hr/nfb/emotions/battery/channels); `BciScanning`/`BciConnecting` → `copyWith(isConnected: false)`; `BciImpedance`/`BciCalibrating`/`BciReady` → `copyWith(isConnected: true)`. Exhaustive, no `default`.

## Commit Plan
- **Commit 1** (after tasks 1-7): "Split BCI link-layer status from domain connection state with sealed device identity"
  - Single commit: the type rewrite (Task 2) breaks compilation across every consumer, so the provider, manager, and both module services must migrate in the same change to keep the build green. No intermediate commit compiles.
