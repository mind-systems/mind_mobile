# BciDeviceManager — Test Plan

**Date:** 2026-06-24
**Source:** roadmap-test-coverage agent
**Phase:** 53 (sealed BciConnectionState, invalid-calibration routing, auto-reconnect policy)

## Source Overview

**BciDeviceManager** owns three critical responsibilities:

1. **State reducer** — translates provider events (connection drops, calibration completions, failures) into app-domain `BciConnectionState` transitions with proper dedup logic.
2. **Auto-reconnect policy** — on unexpected `BciLinkStatus.down` while a device-bound phase is active, suppresses reconnect if explicitly disconnected, otherwise triggers `_attemptReconnect()`.
3. **Invalid-calibration routing** — when `BciCalibrationCompleted` arrives with `data.isValid == false`, routes to `BciImpedance` (not `BciReady`) so the user can retry via `startQuickCalibration()`.

Core file: `/Users/max/projects/mind/mind_mobile/lib/Bci/BciDeviceManager.dart` (315 lines)
Sealed state hierarchy: `/Users/max/projects/mind/mind_mobile/lib/Bci/Models/BciConnectionState.dart` (65 lines)
Provider interface: `/Users/max/projects/mind/mind_mobile/lib/Bci/IBciDeviceProvider.dart` (80 lines)

**Existing coverage:**
- `test/Bci/neiry_bci_provider_locator_device_races_test.dart` uses BciDeviceManager as a harness to drive NeiryBciProvider and verify locator lifecycle.
- Lines 552–645 (Task 4): H1 BciDeviceManager integration test — verifies that `_attemptReconnect()` uses a fresh locator after drop and old locator never receives `requestDevices()`.
- **No direct unit tests of BciDeviceManager's state reducer, dedup logic, or invalid-calibration routing.**

## Instantiation

BciDeviceManager constructor accepts:
- `IBciDeviceProvider provider` — broadcasts events (connection, calibration, signal quality, battery)
- `IHeartRateSource cardioSource` — cardio stream source
- `IEegBandsSource eegBandsSource` — EEG bands stream source
- `IEmotionsSource emotionsSource` — emotions stream source
- `BciDeviceRepository repository` — known-devices registry & registration
- `NfbCalibrationRepository nfbCalibrationRepository` — calibration history cache & sync

The manager immediately calls `_subscribeProviderStreams()` in the constructor, so subscriptions are live at creation time.

### Internal state variables

- `_state: BciConnectionState` — current state (mutable, persisted)
- `_connectedSerial: String?` — device serial from last successful connection (null until connect, cleared on disconnect)
- `_suppressAutoReconnect: bool` — flag set by `disconnect()` to prevent reconnect on subsequent drops
- `_discoveredDevices: List<BciDeviceInfo>` — last emission from provider.scan()
- `_disposed: bool` — guards against operations after disposal

### Public getters

- `state` — current `BciConnectionState`
- `connectedSerial` — the serial of the device we tried to connect to (null if idle or scanning)
- `stateStream` — broadcast stream of state transitions
- `discoveredDevicesStream` — broadcast stream of scan results

## Existing Coverage

The manager is used as a harness in one integration test:

```
test/Bci/neiry_bci_provider_locator_device_races_test.dart :: 
  Phase 3 — H1 reconnect integration (BciDeviceManager)
  
  - Drives connectDevice('TEST-001') → BciImpedance
  - Emits BciLinkStatus.down
  - Asserts _attemptReconnect() fires
  - Asserts fresh locator receives requestDevices(), old locator does not
```

**What is NOT tested:**
- State reducer dedup logic (same state, same serial = no emit)
- Transition guards: `if (_state is BciConnecting)` before setting next phase
- Invalid-calibration routing: `BciCalibrationCompleted(isValid: false)` → `BciImpedance`, not `BciReady`
- Calibration failure routing: `BciCalibrationFailed()` → `BciImpedance`
- `_connectedSerial` capture and reuse during reconnect
- `_suppressAutoReconnect` suppresses reconnect on explicit `disconnect()`
- `startScan()` direct-write bypass of dedup (always re-emits `BciScanning`)
- Race: `disconnect()` concurrent with connect() in-flight
- Race: `_attemptReconnect()` scan emits device → `connectDevice()` is gated on `_state is BciScanning`
- Calibration event handling: `BciCalibrationStageFinished` is a no-op (not forwarded to state)
- Provider exception handling: `connect()` throws → transitions to `BciIdle`
- Repository error swallowing: `registerDevice()` and `nfbCalibrationRepository.record()` catch errors
- Disposed manager: `_setState()` returns early if `_disposed`

## Fakes Required

### FakeBciDeviceProvider (implements IBciDeviceProvider)

```dart
class FakeBciDeviceProvider implements IBciDeviceProvider {
  // Broadcast streams controlled by test
  final _connectionStateController = StreamController<BciLinkStatus>.broadcast();
  final _calibrationController = StreamController<BciCalibrationEvent>.broadcast();
  final _signalQualityController = StreamController<List<BciChannelQuality>>.broadcast();
  final _batteryController = StreamController<int>.broadcast();
  
  // Call counters for assertion
  int connectCallCount = 0;
  int disconnectCallCount = 0;
  int startCalibrationCallCount = 0;
  int startQuickCalibrationCallCount = 0;
  
  // Configurable throws
  Object? connectThrows;
  Object? startCalibrationThrows;
  Object? startQuickCalibrationThrows;
  Object? disconnectThrows;
  
  @override
  Stream<List<BciDeviceInfo>> scan() {
    // Return a controlled stream for each test
    final controller = StreamController<List<BciDeviceInfo>>();
    _scanControllers.add(controller);
    return controller.stream;
  }
  
  @override
  Future<void> connect(String serial) async {
    connectCallCount++;
    if (connectThrows != null) throw connectThrows!;
  }
  
  @override
  Future<void> disconnect() async {
    disconnectCallCount++;
    if (disconnectThrows != null) throw disconnectThrows!;
  }
  
  @override
  Future<void> startCalibration() async {
    startCalibrationCallCount++;
    if (startCalibrationThrows != null) throw startCalibrationThrows!;
  }
  
  @override
  Future<void> startQuickCalibration() async {
    startQuickCalibrationCallCount++;
    if (startQuickCalibrationThrows != null) throw startQuickCalibrationThrows!;
  }
  
  @override
  Future<void> importCalibration(NfbCalibrationData data) async {}
  
  @override
  Stream<BciLinkStatus> get connectionStateStream => _connectionStateController.stream;
  Stream<List<BciChannelQuality>> get signalQualityStream => _signalQualityController.stream;
  Stream<int> get batteryStream => _batteryController.stream;
  Stream<BciCalibrationEvent> get calibrationStream => _calibrationController.stream;
  
  void emitConnectionStatus(BciLinkStatus status) => _connectionStateController.add(status);
  void emitCalibrationEvent(BciCalibrationEvent event) => _calibrationController.add(event);
  
  void dispose() {
    _connectionStateController.close();
    _calibrationController.close();
    _signalQualityController.close();
    _batteryController.close();
    for (final c in _scanControllers) {
      if (!c.isClosed) c.close();
    }
  }
}
```

### FakeBciDeviceRepository (implements implicit interface)

```dart
class FakeBciDeviceRepository implements BciDeviceRepository {
  List<String> _knownSerials = [];
  int fetchKnownSerialsCallCount = 0;
  int registerDeviceCallCount = 0;
  Object? fetchKnownSerialsThrows;
  Object? registerDeviceThrows;
  
  @override
  List<String> cachedSerials() => _knownSerials;
  
  @override
  Future<List<String>> fetchKnownSerials() async {
    fetchKnownSerialsCallCount++;
    if (fetchKnownSerialsThrows != null) throw fetchKnownSerialsThrows!;
    return _knownSerials;
  }
  
  @override
  Future<void> registerDevice(String serial) async {
    registerDeviceCallCount++;
    if (!_knownSerials.contains(serial)) _knownSerials.add(serial);
    if (registerDeviceThrows != null) throw registerDeviceThrows!;
  }
}
```

### FakeNfbCalibrationRepository (implements implicit interface)

```dart
class FakeNfbCalibrationRepository implements NfbCalibrationRepository {
  Map<String, List<NfbCalibrationData>> _history = {};
  int recordCallCount = 0;
  int refreshFromServerCallCount = 0;
  Object? recordThrows;
  
  @override
  List<NfbCalibrationData> history(String serial) =>
      _history[serial] ?? [];
  
  @override
  NfbCalibrationData? latestValid(String serial) =>
      history(serial).firstWhereOrNull((d) => d.isValid);
  
  @override
  Future<void> record(String serial, NfbCalibrationData data, {bool awaitApiSync = false}) async {
    recordCallCount++;
    if (recordThrows != null) throw recordThrows!;
    final existing = history(serial);
    _history[serial] = [data, ...existing];
  }
  
  @override
  Future<void> refreshFromServer(String serial) async {
    refreshFromServerCallCount++;
  }
}
```

### Fake biometric sources (IHeartRateSource, IEegBandsSource, IEmotionsSource)

```dart
class FakeHeartRateSource implements IHeartRateSource {
  @override
  Stream<CardioData> get cardioStream => 
    StreamController<CardioData>.broadcast().stream;
}

// Similar for IEegBandsSource and IEmotionsSource
```

## Test Cases

### Group 1: Sealed-State Reducer Correctness

#### 1.1 Should transition BciIdle → BciScanning on startScan()
- **What:** Calls `startScan()` when in BciIdle, asserts state emits BciScanning.
- **Branch:** `startScan()` line 155–215
- **Setup:** Create manager in BciIdle, subscribe to stateStream, call startScan()
- **Assert:** 
  - stateStream emits BciScanning
  - state getter returns BciScanning

#### 1.2 Should bypass dedup and re-emit BciScanning on consecutive startScan() calls
- **What:** Called twice with manager already in BciScanning — second call must re-emit.
- **Branch:** `startScan()` line 160–162 (direct write bypass)
- **Setup:** startScan() → wait for emit → startScan() again
- **Assert:** 
  - First emit is BciScanning
  - Dedup check at line 132–136 would normally suppress (same type, not Active)
  - Direct-write bypass at line 160 re-emits anyway
  - Second emit received on stateStream

#### 1.3 Should transition BciScanning → BciConnecting on device found + connectDevice()
- **What:** Scan discovers a cached device, manager auto-connects.
- **Branch:** `startScan()` line 189–196, then `connectDevice()` line 218
- **Setup:** 
  - Repository.cachedSerials() returns ['TEST-001']
  - startScan() active
  - Provider scan stream emits device with matching serial
- **Assert:** 
  - Auto-connect fires (line 195)
  - state transitions BciConnecting('TEST-001')

#### 1.4 Should transition BciConnecting → BciImpedance on successful connect
- **What:** `connectDevice()` succeeds, state moves to impedance phase.
- **Branch:** `connectDevice()` line 217–235
- **Setup:** 
  - Manual call to connectDevice('TEST-001')
  - Provider.connect() succeeds
  - currentState is BciConnecting
- **Assert:** 
  - stateStream emits BciImpedance('TEST-001')
  - connectedSerial == 'TEST-001'
  - registerDevice() was called

#### 1.5 Should transition BciConnecting → BciIdle on connect failure
- **What:** `connectDevice()` throws, state falls back to idle.
- **Branch:** `connectDevice()` line 231–234
- **Setup:** 
  - connectDevice('TEST-001') called
  - Provider.connect() throws SocketException
- **Assert:** 
  - stateStream emits BciIdle
  - connectedSerial remains null

#### 1.6 Should transition BciImpedance → BciCalibrating(4) on startCalibration()
- **What:** Begin full 4-stage calibration.
- **Branch:** `startCalibration()` line 237–249
- **Setup:** 
  - Manager in BciImpedance('TEST-001')
  - Call startCalibration()
- **Assert:** 
  - stateStream emits BciCalibrating('TEST-001', totalStages: 4)
  - line 240: `totalStages: 4`

#### 1.7 Should transition BciImpedance → BciCalibrating(1) on startQuickCalibration()
- **What:** Begin single-stage quick retry.
- **Branch:** `startQuickCalibration()` line 251–263
- **Setup:** 
  - Manager in BciImpedance('TEST-001')
  - Call startQuickCalibration()
- **Assert:** 
  - stateStream emits BciCalibrating('TEST-001', totalStages: 1)
  - line 254: `totalStages: 1`

#### 1.8 Should suppress startCalibration() if not in BciImpedance
- **What:** Caller is in wrong state, method returns early.
- **Branch:** `startCalibration()` line 238
- **Setup:** 
  - Manager in BciScanning
  - Call startCalibration()
- **Assert:** 
  - No state change
  - Provider.startCalibration() never called

#### 1.9 Should transition BciCalibrating → BciReady on valid calibration result
- **What:** `BciCalibrationCompleted` with isValid=true.
- **Branch:** `_subscribeProviderStreams()` line 76–103, case 80–90
- **Setup:** 
  - Manager in BciCalibrating('TEST-001', totalStages: 4)
  - Provider emits BciCalibrationCompleted(data with isValid: true)
- **Assert:** 
  - stateStream emits BciReady('TEST-001')
  - nfbCalibrationRepository.record() was called with the data

#### 1.10 Should transition BciCalibrating → BciImpedance on invalid calibration result
- **What:** `BciCalibrationCompleted` with isValid=false — **invalid-calibration routing**.
- **Branch:** `_subscribeProviderStreams()` line 76–103, case 91–95
- **Setup:** 
  - Manager in BciCalibrating('TEST-001', totalStages: 4)
  - Provider emits BciCalibrationCompleted(data with isValid: false, failReason: "tooManyArtifacts")
- **Assert:** 
  - stateStream emits BciImpedance('TEST-001'), NOT BciReady
  - nfbCalibrationRepository.record() NOT called (line 85 checks isValid first)
  - Line 94: `_setState(BciImpedance(...))`

#### 1.11 Should transition BciCalibrating → BciImpedance on calibration failure
- **What:** `BciCalibrationFailed` event.
- **Branch:** `_subscribeProviderStreams()` line 97–101
- **Setup:** 
  - Manager in BciCalibrating('TEST-001', totalStages: 4)
  - Provider emits BciCalibrationFailed("device_error")
- **Assert:** 
  - stateStream emits BciImpedance('TEST-001')
  - Line 100: `_setState(BciImpedance(...))`

#### 1.12 Should suppress duplicate state emissions (dedup by type + serial)
- **What:** Same state type, same serial (for Active subclasses) = no emit.
- **Branch:** `_setState()` line 130–140
- **Setup:** 
  - Manager in BciConnecting('TEST-001')
  - Call _setState(BciConnecting('TEST-001')) again
- **Assert:** 
  - stateStream does NOT emit (lines 134–136)
  - state getter still returns BciConnecting('TEST-001')

#### 1.13 Should allow state transition between different Active subtypes with same serial
- **What:** BciConnecting('TEST-001') → BciImpedance('TEST-001') is a real transition (different type).
- **Branch:** `_setState()` line 132–137
- **Setup:** 
  - Manager in BciConnecting('TEST-001')
  - Call _setState(BciImpedance('TEST-001'))
- **Assert:** 
  - stateStream emits BciImpedance('TEST-001')
  - Line 132: type check passes (different types)

#### 1.14 Should allow transition between same Active type but different serial
- **What:** BciConnecting('TEST-001') → BciConnecting('TEST-002') is a real transition (different serial).
- **Branch:** `_setState()` line 134–136
- **Setup:** 
  - Manager in BciConnecting('TEST-001')
  - Call _setState(BciConnecting('TEST-002'))
- **Assert:** 
  - stateStream emits BciConnecting('TEST-002')
  - serial comparison fires emit

---

### Group 2: connectedSerial & isConnecting Derivation

#### 2.1 Should capture connectedSerial on successful connectDevice()
- **What:** After connect succeeds, connectedSerial is set.
- **Branch:** `connectDevice()` line 221
- **Setup:** 
  - connectDevice('SERIAL-A')
  - Provider.connect() succeeds
- **Assert:** 
  - connectedSerial == 'SERIAL-A'

#### 2.2 Should preserve connectedSerial across state transitions
- **What:** connectedSerial persists from BciConnecting → BciImpedance → BciCalibrating → BciReady.
- **Branch:** Multiple methods reading line 109 getter
- **Setup:** 
  - connectDevice('SERIAL-A')
  - startCalibration()
  - Emit calibration completion
- **Assert:** 
  - connectedSerial == 'SERIAL-A' at each phase

#### 2.3 Should clear connectedSerial on disconnect()
- **What:** Explicit disconnect nullifies the serial.
- **Branch:** `disconnect()` line 265–272, line 270
- **Setup:** 
  - connectDevice('SERIAL-A') → BciImpedance
  - Call disconnect()
- **Assert:** 
  - connectedSerial == null
  - _suppressAutoReconnect == true

#### 2.4 Should use connectedSerial for reconnect lookup
- **What:** After drop, reconnect scan looks for the same serial.
- **Branch:** `_attemptReconnect()` line 284–286
- **Setup:** 
  - connectDevice('TEST-001') → BciImpedance
  - Emit BciLinkStatus.down → triggers reconnect
  - Scan emits device list with 'TEST-001'
- **Assert:** 
  - firstWhereOrNull matches on _connectedSerial (line 285)
  - connectDevice(match.serial) called

---

### Group 3: Auto-Reconnect Policy

#### 3.1 Should trigger auto-reconnect on unexpected drop while BciActive
- **What:** `BciLinkStatus.down` while state is BciActive → calls _attemptReconnect().
- **Branch:** `_subscribeProviderStreams()` line 64–75
- **Setup:** 
  - connectDevice('TEST-001') → BciImpedance
  - Provider emits BciLinkStatus.down
- **Assert:** 
  - state transitions to BciScanning
  - _attemptReconnect() microtask fires

#### 3.2 Should NOT trigger auto-reconnect after explicit disconnect()
- **What:** `_suppressAutoReconnect = true` prevents reconnect.
- **Branch:** `_subscribeProviderStreams()` line 71, `disconnect()` line 266
- **Setup:** 
  - connectDevice('TEST-001') → BciImpedance
  - Call disconnect() (sets _suppressAutoReconnect = true)
  - Provider emits BciLinkStatus.down (simulated race)
- **Assert:** 
  - Line 71: `if (!_suppressAutoReconnect ...)` skips unawaited(_attemptReconnect())
  - state remains BciIdle

#### 3.3 Should NOT trigger auto-reconnect if _connectedSerial is null
- **What:** Can't reconnect without a remembered serial.
- **Branch:** `_subscribeProviderStreams()` line 71
- **Setup:** 
  - Manager in BciScanning (never connected)
  - Provider emits BciLinkStatus.down
- **Assert:** 
  - `if (_connectedSerial != null)` guard fails
  - _attemptReconnect() not called

#### 3.4 Should NOT trigger auto-reconnect on down if not in BciActive state
- **What:** Idle/Scanning/PermissionDenied ignore link-layer drops.
- **Branch:** `_subscribeProviderStreams()` line 68
- **Setup:** 
  - Manager in BciScanning
  - Provider emits BciLinkStatus.down
- **Assert:** 
  - Line 68: `if (status == BciLinkStatus.down && _state is BciActive)` fails
  - Nothing happens

#### 3.5 Should ignore BciLinkStatus.up event
- **What:** Up events are only emitted by provider; manager doesn't react.
- **Branch:** `_subscribeProviderStreams()` line 68 (only checks .down)
- **Setup:** 
  - Manager in BciImpedance('TEST-001')
  - Provider emits BciLinkStatus.up
- **Assert:** 
  - No state change

#### 3.6 Should scan for the remembered serial during reconnect
- **What:** _attemptReconnect() looks for _connectedSerial in discovered devices.
- **Branch:** `_attemptReconnect()` line 284–286
- **Setup:** 
  - connectDevice('TEST-001') → BciImpedance
  - Emit down → reconnect fires → BciScanning
  - Provider scan emits ['TEST-001', 'TEST-002', ...]
- **Assert:** 
  - firstWhereOrNull found 'TEST-001'
  - connectDevice('TEST-001') called again

#### 3.7 Should transition to BciScanning on reconnect start
- **What:** Auto-reconnect begins with a scan.
- **Branch:** `_attemptReconnect()` line 275
- **Setup:** 
  - connectDevice('TEST-001') → BciImpedance
  - Emit down
- **Assert:** 
  - state emits BciScanning
  - _state is BciScanning

#### 3.8 Should transition to BciIdle if reconnect scan completes without finding device
- **What:** Scan terminates (onDone) but device not found.
- **Branch:** `_attemptReconnect()` line 307–310
- **Setup:** 
  - connectDevice('TEST-001') → BciImpedance
  - Emit down → reconnect fires
  - Provider scan emits devices that DON'T include 'TEST-001'
  - Provider scan completes (onDone fires)
- **Assert:** 
  - state transitions to BciIdle
  - Line 309: `if (_state is BciScanning && _connectedSerial != null)`

#### 3.9 Should handle scan error during reconnect (non-permission exception)
- **What:** Provider scan throws (e.g., BLE error).
- **Branch:** `_attemptReconnect()` line 293–305, case non-permission
- **Setup:** 
  - connectDevice('TEST-001') → BciImpedance
  - Emit down → reconnect fires
  - Provider scan throws TimeoutException
- **Assert:** 
  - state transitions to BciIdle
  - Line 304: `_setState(BciIdle())`

#### 3.10 Should handle permission denied during reconnect
- **What:** Provider scan throws BluetoothPermissionDeniedException.
- **Branch:** `_attemptReconnect()` line 299–301
- **Setup:** 
  - connectDevice('TEST-001') → BciImpedance
  - Emit down → reconnect fires
  - Provider scan throws BluetoothPermissionDeniedException
- **Assert:** 
  - state transitions to BciPermissionDenied
  - Line 301: `_setState(BciPermissionDenied())`

#### 3.11 Should suppress auto-reconnect on startScan()
- **What:** Calling startScan() explicitly clears the auto-reconnect flag.
- **Branch:** `startScan()` line 156
- **Setup:** 
  - connectDevice('TEST-001') → BciImpedance
  - User initiates new scan via startScan()
- **Assert:** 
  - Line 156: `_suppressAutoReconnect = false`
  - (This allows the next drop to trigger reconnect again)
  - [Note: This is NOT suppression — it re-enables. Confusing naming?]

---

### Group 4: Invalid-Calibration Routing

#### 4.1 Should NOT record calibration when isValid=false
- **What:** Invalid results skip nfbCalibrationRepository.record().
- **Branch:** `_subscribeProviderStreams()` line 82–90, guards
- **Setup:** 
  - Manager in BciCalibrating
  - Provider emits BciCalibrationCompleted with isValid: false
- **Assert:** 
  - nfbCalibrationRepository.record() call count == 0
  - Line 85: `if (data.isValid)` guard prevents recording

#### 4.2 Should record valid calibration result
- **What:** Valid results are persisted.
- **Branch:** `_subscribeProviderStreams()` line 82–90
- **Setup:** 
  - Manager in BciCalibrating('TEST-001')
  - Provider emits BciCalibrationCompleted with isValid: true, failReason: "none"
- **Assert:** 
  - nfbCalibrationRepository.record('TEST-001', data) called once
  - Line 86: unawaited(...record())

#### 4.3 Should swallow calibration record error
- **What:** If recording throws, error is logged but doesn't bubble up.
- **Branch:** `_subscribeProviderStreams()` line 86–88
- **Setup:** 
  - Manager in BciCalibrating('TEST-001')
  - nfbCalibrationRepository.record() throws TimeoutException
  - Provider emits BciCalibrationCompleted(isValid: true)
- **Assert:** 
  - catchError at line 87 catches it
  - Log line: 'BciDeviceManager: nfbCalibration record failed: ...'
  - State still transitions to BciReady

#### 4.4 Should use captured connectedSerial for calibration record
- **What:** Serial is captured at the top of the listener (line 83 comment).
- **Branch:** `_subscribeProviderStreams()` line 85
- **Setup:** 
  - connectDevice('SERIAL-A') → BciImpedance
  - startCalibration() → BciCalibrating
  - Provider emits BciCalibrationCompleted(isValid: true)
- **Assert:** 
  - nfbCalibrationRepository.record('SERIAL-A', ...) called
  - Line 85–86: _connectedSerial captured in the listener, not re-read

#### 4.5 Should ignore calibration stage progress (no state change)
- **What:** `BciCalibrationStageFinished` is forwarded to UI but doesn't change app state.
- **Branch:** `_subscribeProviderStreams()` line 77–79
- **Setup:** 
  - Manager in BciCalibrating('TEST-001', totalStages: 4)
  - Provider emits BciCalibrationStageFinished(1)
- **Assert:** 
  - state remains BciCalibrating (no emit)
  - Line 79: `break` — not handled by manager

#### 4.6 Should ignore calibration events when not in BciCalibrating
- **What:** Events outside the calibrating phase are dropped.
- **Branch:** `_subscribeProviderStreams()` line 81, 99
- **Setup:** 
  - Manager in BciImpedance('TEST-001')
  - Provider emits BciCalibrationCompleted(isValid: true)
- **Assert:** 
  - Line 81: `if (_state is BciCalibrating)` guard fails
  - No state change

#### 4.7 Should swallow provider exception on startCalibration failure
- **What:** Provider throws → manager catches and transitions back to impedance.
- **Branch:** `startCalibration()` line 237–249, line 245–248
- **Setup:** 
  - Manager in BciImpedance('TEST-001')
  - Provider.startCalibration() throws StateError
  - Call startCalibration()
- **Assert:** 
  - state transitions back to BciImpedance
  - Line 247: `_setState(BciImpedance(serial))`

#### 4.8 Should swallow provider exception on startQuickCalibration failure
- **What:** Quick calibration throw → fallback to impedance.
- **Branch:** `startQuickCalibration()` line 251–263
- **Setup:** 
  - Manager in BciImpedance('TEST-001')
  - Provider.startQuickCalibration() throws NetworkError
  - Call startQuickCalibration()
- **Assert:** 
  - state transitions back to BciImpedance
  - Line 261: `_setState(BciImpedance(serial))`

---

### Group 5: Race Conditions & Edge Cases

#### 5.1 Should guard against disconnect() racing with connect() in-flight
- **What:** User disconnects while connect awaits.
- **Branch:** `connectDevice()` line 228–230
- **Setup:** 
  - Call connectDevice('TEST-001') but don't await
  - Simultaneously call disconnect()
  - Provider.connect() eventually succeeds
- **Assert:** 
  - Line 228: `if (_state is BciConnecting)` gate ensures we don't override user's disconnect
  - state remains BciIdle

#### 5.2 Should cancel scan subscription on auto-connect
- **What:** Scan terminates when a cached device is found and connected.
- **Branch:** `startScan()` line 193–194
- **Setup:** 
  - startScan() active, subscribed to provider.scan()
  - Device found in cache → auto-connect fires
- **Assert:** 
  - Line 193: `await _scanSub?.cancel()` called
  - _scanSub = null

#### 5.3 Should ignore calibration completion if _connectedSerial is null
- **What:** Edge case: calibration completes but we lost track of which device (defensive).
- **Branch:** `_subscribeProviderStreams()` line 85
- **Setup:** 
  - BciCalibrating but _connectedSerial somehow became null (pathological)
  - Provider emits BciCalibrationCompleted(isValid: true)
- **Assert:** 
  - Line 85: `if (_connectedSerial != null)` guard skips recording
  - state still transitions to BciReady

#### 5.4 Should suppress operations after dispose()
- **What:** Any _setState call after dispose is a no-op.
- **Branch:** `_setState()` line 131
- **Setup:** 
  - Call dispose()
  - Manually trigger a state transition (e.g., provider emits event)
- **Assert:** 
  - Line 131: `if (_disposed) return`
  - No stream emission

#### 5.5 Should swallow registerDevice error
- **What:** Device registration fails but doesn't abort the connection flow.
- **Branch:** `connectDevice()` line 222–224
- **Setup:** 
  - connectDevice('TEST-001')
  - Provider.connect() succeeds
  - repository.registerDevice() throws
- **Assert:** 
  - catchError at line 223 swallows it
  - state still transitions to BciImpedance

#### 5.6 Should handle permission denied during startScan
- **What:** User hasn't granted Bluetooth permission.
- **Branch:** `startScan()` line 201–203
- **Setup:** 
  - Call startScan()
  - Provider scan throws BluetoothPermissionDeniedException
- **Assert:** 
  - state transitions to BciPermissionDenied
  - Line 203: `_setState(BciPermissionDenied())`

#### 5.7 Should handle generic error during startScan
- **What:** Scan throws non-permission exception.
- **Branch:** `startScan()` line 205–206
- **Setup:** 
  - Call startScan()
  - Provider scan throws BleAdapterNotAvailable
- **Assert:** 
  - state transitions to BciIdle
  - Line 206: `_setState(BciIdle())`

#### 5.8 Should complete scan normally when no error
- **What:** Scan stream completes without error.
- **Branch:** `startScan()` line 209–213
- **Setup:** 
  - Call startScan()
  - Provider scan emits a few devices then completes cleanly
- **Assert:** 
  - state transitions to BciIdle
  - Line 211: `if (_state is BciScanning) _setState(BciIdle())`

#### 5.9 Should allow connectDevice even after previous failed attempt
- **What:** Connection failure doesn't permanently bar reconnection.
- **Branch:** `connectDevice()` handles throw
- **Setup:** 
  - connectDevice('TEST-001') → Provider throws
  - connectDevice('TEST-001') again
- **Assert:** 
  - Second attempt is allowed
  - Provider.connect() called twice

---

### Group 6: Stream Broadcast Behavior

#### 6.1 Should emit stateStream broadcast to multiple subscribers
- **What:** Multiple listeners all receive emissions.
- **Branch:** `stateStream` getter line 110, broadcast controller
- **Setup:** 
  - Multiple subscriptions to manager.stateStream
  - Trigger state transition
- **Assert:** 
  - All subscribers receive the emission

#### 6.2 Should emit discoveredDevicesStream on scan results
- **What:** Scan discoveries propagate to UI.
- **Branch:** `startScan()` line 180–185
- **Setup:** 
  - startScan()
  - Provider scan emits [device1, device2]
- **Assert:** 
  - discoveredDevicesStream emits the list
  - _discoveredDevices updated

#### 6.3 Should not emit closed streams after dispose
- **What:** After dispose(), stream controllers are closed.
- **Branch:** `dispose()` line 149–150
- **Setup:** 
  - Subscribe to stateStream
  - Call dispose()
  - Try to receive further emissions
- **Assert:** 
  - Subscription receives done event
  - Controllers are closed

---

## Gotchas

1. **Dedup devilry** (lines 132–137):
   - Same type (non-Active) = no emit
   - Same Active type + same serial = no emit
   - Different type OR different serial = always emit
   - Direct-write bypass in `startScan()` re-emits BciScanning even when already scanning

2. **_connectedSerial lifetime**:
   - Set on successful connect (line 221)
   - Cleared ONLY on explicit disconnect (line 270)
   - Persists across drops + reconnects
   - Null during Idle/Scanning/PermissionDenied

3. **_suppressAutoReconnect semantics**:
   - Set to true by disconnect() (line 266)
   - Set to false by startScan() (line 156)
   - Checked at line 71 before reconnect
   - Note: Line 156 is misleading naming — setting to false RE-ENABLES reconnect

4. **Calibration completeness**:
   - `isValid` controls routing: true → BciReady, false → BciImpedance
   - Invalid results skip `nfbCalibrationRepository.record()`
   - Recording is unawaited and errors are swallowed
   - Stage progress (BciCalibrationStageFinished) doesn't change app state

5. **_connectedSerial capture in listener**:
   - Line 83–84: comment notes serial is captured synchronously
   - This is safe due to Dart single-threading within a listener
   - Prevents UAF if _connectedSerial mutates before the unawaited record() completes

6. **Reconnect scan ordering**:
   - _attemptReconnect() called after _setState(BciIdle()) at line 70
   - Dedup check at line 68 ensures the drop listener fires _setState(BciIdle()) first
   - Only then does the microtask invoke _attemptReconnect()
   - This ordering matters for avoiding races

7. **Provider interface contracts**:
   - scan() returns a fresh stream each call (not reused)
   - Lifecycle comment: after dispose(), all streams are closed, subsequent calls undefined
   - calibrationStream is persistent (unlike scan)

8. **Error swallowing strategy**:
   - registerDevice errors swallowed (line 223)
   - nfbCalibrationRepository.record errors swallowed (line 87)
   - startCalibration/startQuickCalibration errors transition back to BciImpedance
   - No error state in BciConnectionState — errors are logged silently
