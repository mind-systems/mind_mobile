# BCI connection domain — split link-layer from domain phase + sealed identity

**Date:** 2026-06-19
**Source:** conversation context (supersedes the 2026-06-05 draft of this note)

**Naming (fixed):** provider link-layer = `enum BciLinkStatus { down, up }`; app domain = `sealed class BciConnectionState` with a `BciActive(serial)` ancestor for all device-bound phases.

## Key Findings

- One flat `BciConnectionState` enum does **two unrelated jobs**: (a) the provider's link-layer stream (`IBciDeviceProvider.connectionStateStream`, where only down/up matter) and (b) the app's domain phase, which the manager owns (`connecting/impedance/calibrating/ready`). Conflating them forces the confusing `NeiryConnectionState.connected → BciConnectionState.connecting` mapping in `NeiryBciProvider` (which the manager then ignores — it only reacts to `disconnected`).
- The enum cannot carry the connecting device's `serial`, so `BciPairingService` keeps a mutable `_connectingSerial` side-channel plus a `devices.length == 1` heuristic. The heuristic is set only on user tap; auto-connect (manager-internal, both scan-time and reconnect) never sets it → **breaks for multi-device auto-connect** (UI cannot tell which device connected). Real bug, not just a smell.
- Correct model: `serial` is not special to `connecting` — it belongs to **every device-bound phase** (connecting/impedance/calibrating/ready). Model identity in a device-bound branch so illegal states ("connecting without serial", "disconnected with serial") are unrepresentable.
- Decided scope: **one atomic task, #1** — split the link-layer type out AND introduce the sealed domain state in a single pass. Doing it in halves migrates the same consumers twice and needs a temporary alias (name collision on `BciConnectionState`). #3 (flat enum + nullable serial field) is rejected: it re-admits "connecting without serial" — reintroduces the bug.

## Details

### New types

- `lib/Bci/Models/BciLinkStatus.dart` (new): `enum BciLinkStatus { down, up }` — the provider's BLE link-layer state, nothing else.
- `lib/Bci/Models/BciConnectionState.dart` (rewrite enum → sealed):
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

### Files & changes

- `lib/Bci/IBciDeviceProvider.dart` — `connectionStateStream` → `Stream<BciLinkStatus>`.
- `lib/Bci/NeiryBciProvider.dart` — `_connectionStateController` → `StreamController<BciLinkStatus>`; `_onNeiryConnectionState`: `connected → up`, `disconnected`/`unsupportedConnection → down`; the explicit-disconnect emits (`:592`) → `down`. Drop the `connected → connecting` mismap.
- `lib/Bci/BciDeviceManager.dart` — listener in `_subscribeProviderStreams` reacts to `BciLinkStatus.down` (unexpected disconnect → `_attemptReconnect`) instead of `BciConnectionState.disconnected`. `_setState` now takes a `BciConnectionState` instance; build `BciConnecting(serial)`/`BciImpedance(serial)`/`BciCalibrating(serial)`/`BciReady(serial)` in `connectDevice(serial)` (serial in scope for both tap and auto-connect — both already route through this method, `:173`/`:253`). Replace `_state == X` / direct `_state = scanning` dedup-bypass writes with the new instances and `is`-checks. `connectedSerial` getter returns `_connectedSerial`.
- `lib/Bci/BciNotifier.dart` — unchanged in shape; `currentState`/`BciStateChanged` now flow sealed instances (field type stays `BciConnectionState`).
- `lib/BciModule/BciPairingService.dart` — **delete** `_connectingSerial` and the `devices.length == 1` heuristic. `_reduceStateChanged` switches exhaustively on the sealed type. Derive purely: `connectedSerial = state is BciActive ? state.serial : null`; `isConnecting = state is BciConnecting`. Reducer becomes `(acc, event) → state` with no external reads.
- `lib/BciModule/BciDataService.dart` — rewrite its 7-arm enum `switch` (`:69-84`) over the sealed variants.

### Guards

- `_connectedSerial` in `BciDeviceManager` **stays** — it is the "last target serial" memory for `_attemptReconnect`, distinct from the emitted state; do NOT delete.
- `connectedSerial` field on `BciPairingState` stays (now fed purely from `BciActive.serial`); `isConnecting` stays as an explicit UX flag (`state is BciConnecting`) for tap-gating.
- neiry_kit untouched — `NeiryConnectionState` maps to `BciLinkStatus` only inside `NeiryBciProvider`.
- All `switch` over `BciConnectionState` exhaustive (no `default`) so the compiler flags every site.
- Preserve existing behavior: `_setState` dedup, the `startScan` direct-write bypass, the connect-mid-disconnect guard (`if (_state == connecting)` → `if (_state is BciConnecting)`), and reconnect flow.

### Verify

- Multi-device auto-connect: scan ≥2 devices incl. a known one → it auto-connects → UI highlights the correct row (`connectedSerial` = that serial), with no `devices.length == 1` dependence.
- Tap connect: same correct serial via the same reducer branch.
- Unexpected disconnect → auto-reconnect still works (manager `_connectedSerial` memory).
- `BciPairingService` has no `_connectingSerial`; reducer reads only the event.

## Open Questions

- None blocking. Earlier questions resolved: enum used only in `lib/Bci/`+`lib/BciModule/`+package event model (neiry_kit untouched); serial available at `connectDevice` for both paths; `isConnecting` kept.
