# Test Plan: BciDeviceManager reducer and reconnect tests

## Context
`lib/Bci/BciDeviceManager.dart` owns the sealed `BciConnectionState` reducer, the auto-reconnect policy, and invalid-calibration routing, but no test exercises these paths directly — it is only used as a harness in `neiry_bci_provider_locator_device_races_test.dart`. This plan adds direct unit tests with a `FakeIBciDeviceProvider` and fake repositories so every reducer branch and reconnect path is pinned. All dependencies are constructor-injected, so no Test Infra refactor is required.

## Settings
- Testing: yes
- Logging: minimal
- Docs: no

## Test Command
`/usr/local/bin/flutter test test/Bci/bci_device_manager_test.dart`

## Target Spec File
`test/Bci/bci_device_manager_test.dart`

## Fakes & Harness (implement once at top of the spec file)

The implementer must build these doubles before the `group` blocks (`flutter_test` has no `describe` — only `group`/`test`). Reference implementations live in `.ai-factory/notes/177-test-plan-bci-device-manager-reducer.md` (§ "Fakes Required"), but extend them per the corrections below. Because every fake uses `implements`, it must satisfy the **full** implicit interface, not only the methods that carry counters/throws.

- **`FakeIBciDeviceProvider implements IBciDeviceProvider`** — broadcast `StreamController`s for `connectionStateStream`, `calibrationStream`, `signalQualityStream`, `batteryStream`. Expose `emitConnectionStatus(BciLinkStatus)` and `emitCalibrationEvent(BciCalibrationEvent)`. Call counters (`connectCallCount`, `disconnectCallCount`, `startCalibrationCallCount`, `startQuickCalibrationCallCount`) and configurable throws (`connectThrows`, `startCalibrationThrows`, `startQuickCalibrationThrows`). Must also implement the rest of the interface that has no counter: `importCalibration(NfbCalibrationData)` and `dispose()` (inert bodies).
  - **`scan()` returns a fresh controlled stream per call** (interface contract `IBciDeviceProvider.dart:27`). Keep the note's list-based design (`_scanControllers.add(controller)`) and expose the **latest** controller (e.g. `_scanControllers.last`) — `_attemptReconnect()` calls `scan()` a *second* time (line 277), so reconnect-discovery emissions must be pushed to the latest controller, not the first.
  - **Add a completable `connectGate`.** The note's `connect()` resolves synchronously, making the in-flight `BciConnecting` phase unobservable. Add a `Completer<void>? connectGate`; inside `connect()`, bump `connectCallCount`, then `await connectGate?.future` (when set), then honor `connectThrows`. This is the in-repo pattern from `GatedFakeDevicePort` in `neiry_bci_provider_locator_device_races_test.dart`. Default `connectGate = null` so connect resolves immediately for tests that don't need the seam. Required by Task 5 (observe `BciConnecting`) and Task 6 (serial-null guard while `BciConnecting` mid-flight).
- **`FakeBciDeviceRepository implements BciDeviceRepository`** — `BciDeviceRepository` is a concrete class; implement its implicit interface. Back `cachedSerials()` with an in-memory list, count `registerDevice()` / `fetchKnownSerials()` calls, support a configurable throw on each. **Must also implement `deleteDevice(String id)`** — the note's reference fake omits it, but the implicit interface declares it (`BciDeviceRepository.dart:43`), so without it the file will not compile. The manager never calls it; a one-line `@override Future<void> deleteDevice(String id) async {}` suffices.
- **`FakeNfbCalibrationRepository implements NfbCalibrationRepository`** — implement the **full** implicit interface: `record()` and `refreshFromServer()` (with counters / `recordThrows`) plus `history(serial)` and `latestValid(serial)`. Keep the `{@visibleForTesting bool awaitApiSync = false}` named param to match `NfbCalibrationRepository.dart:55`. If `latestValid` uses `firstWhereOrNull`, add `import 'package:collection/collection.dart';` to the spec file.
- **`FakeHeartRateSource` / `FakeEegBandsSource` / `FakeEmotionsSource`** — return inert broadcast streams; the manager never drives them in these tests.
- **`NfbCalibrationData` builder helper** — a factory that returns a valid/invalid `NfbCalibrationData` given `isValid` (all numeric fields can be `0`, `calibratedAt` from a fixed `DateTime`, `failReason: 'none'` when valid / `'tooManyArtifacts'` when invalid). All 11 fields are required (`NfbCalibrationData.dart:31`).
- **`BciDeviceInfo`** — build with a `serial` matching the device under test for scan emissions.
- Tests are async-heavy: `unawaited(...)` microtasks (reconnect, record) need `await pumpEventQueue()` / `await Future<void>.delayed(Duration.zero)` before asserting. **Reconnect needs a double pump:** `_attemptReconnect()` is itself fired via `unawaited()` from inside the connection-state listener (line 72), so after `emitConnectionStatus(BciLinkStatus.down)` the test must pump once for the listener and again for the reconnect microtask + its `scan()` subscription before the reconnect scan controller handle exists. The `record` catchError path (Task 4 "still emit BciReady when record throws") also throws on an unawaited future and needs a pump before asserting state. Always `await manager.dispose()` in `tearDown` to close controllers.

## Tasks

### Phase 1: Reducer core — `_setState` dedup

- [x] **Task 1: `_setState` dedup and transition guards**
  Files: `test/Bci/bci_device_manager_test.dart`
  Drives state via the public API (no direct `_setState` access) and asserts on `stateStream` / `state`. Source: `_setState` at lines 130–140.
  Test cases:
  - `should not emit when transitioning to the same non-active state` — reach the `BciIdle → BciIdle` branch via the public API by calling `disconnect()` while already idle (it calls `_setState(BciIdle())`, which dedup-suppresses); do not call `_setState` directly (lines 132–134)
  - `should not emit when transitioning to the same active type with the same serial` (`BciConnecting('A')` → `BciConnecting('A')`; line 135–136)
  - `should emit when transitioning between different active types with the same serial` (`BciConnecting('A')` → `BciImpedance('A')`; line 132 runtimeType differs)
  - `should emit when transitioning to the same active type with a different serial` (`BciConnecting('A')` → `BciConnecting('B')`; line 136 serial differs)
  - `should not emit any state after dispose` (line 131 `if (_disposed) return`)

### Phase 2: Forward connection path (`BciScanning → BciConnecting → BciImpedance`)

- [x] **Task 2: scan and connect lifecycle**
  Files: `test/Bci/bci_device_manager_test.dart`
  Source: `startScan` lines 155–215, `connectDevice` lines 217–235.
  Test cases:
  - `should emit BciScanning when startScan is called from idle` (lines 160–163)
  - `should re-emit BciScanning on consecutive startScan calls` (dedup-bypass direct write, lines 160–162)
  - `should emit discovered devices on discoveredDevicesStream when scan yields results` (lines 182–185)
  - `should auto-connect when scan discovers a cached serial while scanning` (lines 189–196 → `connectDevice` called, scan sub cancelled)
  - `should emit BciConnecting then BciImpedance when connectDevice succeeds` (lines 218, 228–229)
  - `should call registerDevice with the serial on successful connect` (line 222)
  - `should emit BciIdle when provider.connect throws` (lines 231–234, `connectedSerial` stays null)

### Phase 3: Calibration transitions and invalid-result routing

- [x] **Task 3: startCalibration / startQuickCalibration entry**
  Files: `test/Bci/bci_device_manager_test.dart`
  Source: `startCalibration` lines 237–249, `startQuickCalibration` lines 251–263.
  Test cases:
  - `should emit BciCalibrating with totalStages 4 on startCalibration from impedance` (line 240)
  - `should emit BciCalibrating with totalStages 1 on startQuickCalibration from impedance` (line 254 — quick-calibration retry increment)
  - `should do nothing and not call provider when startCalibration is called outside impedance` (line 238 guard)
  - `should do nothing and not call provider when startQuickCalibration is called outside impedance` (line 252 guard)
  - `should route back to BciImpedance when provider.startCalibration throws` (lines 245–247)
  - `should route back to BciImpedance when provider.startQuickCalibration throws` (lines 259–261)

- [x] **Task 4: calibration-event routing (valid / invalid / failed / progress)**
  Files: `test/Bci/bci_device_manager_test.dart`
  Source: `calibrationStream` listener lines 76–103.
  Test cases:
  - `should emit BciReady when BciCalibrationCompleted arrives with isValid true` (line 90)
  - `should call nfbCalibrationRepository.record with the captured serial on valid completion` (lines 85–88)
  - `should emit BciImpedance not BciReady when BciCalibrationCompleted arrives with isValid false` (line 94 — invalid-calibration routing)
  - `should not call record when completion is invalid` (line 82 guard)
  - `should emit BciImpedance when BciCalibrationFailed arrives` (lines 97–100)
  - `should not change state on BciCalibrationStageFinished` (lines 78–79 no-op)
  - `should ignore calibration completion when not in BciCalibrating` (line 81 guard)
  - `should still emit BciReady when record throws` (catchError swallow, lines 86–88 then 90; pump the event queue after the unawaited throw before asserting)

### Phase 4: Derived fields — `connectedSerial` and connecting state

- [x] **Task 5: connectedSerial derivation and isConnecting state**
  Files: `test/Bci/bci_device_manager_test.dart`
  Source: `connectedSerial` getter line 109; `connectDevice` line 221; `disconnect` lines 265–272. ("isConnecting" is expressed by `state is BciConnecting`, which has no dedicated getter — assert on the state type.)
  Test cases:
  - `should expose connectedSerial as null while idle or scanning` (never connected)
  - `should report state as BciConnecting between setState and provider.connect completing` — set `provider.connectGate` to an un-completed `Completer`, start `connectDevice('A')` without awaiting, assert `state is BciConnecting`, then complete the gate (line 218 before line 221)
  - `should set connectedSerial to the target serial after a successful connect` (line 221)
  - `should preserve connectedSerial across impedance, calibrating, and ready phases` (line 221 set once, not cleared)
  - `should clear connectedSerial and set suppress flag on disconnect` (lines 266, 270)

### Phase 5: Auto-reconnect policy on link drop

- [x] **Task 6: reconnect trigger and guards on BciLinkStatus.down**
  Files: `test/Bci/bci_device_manager_test.dart`
  Source: connection listener lines 64–75; `_attemptReconnect` lines 274–313.
  Test cases:
  - `should emit BciIdle then call scan again when down arrives while in an active phase` (lines 70, 72, 275 — auto-reconnect fires scan())
  - `should reconnect by calling connectDevice when the scan rediscovers the remembered serial` (lines 284–290; push discoveries to the latest `scan()` controller)
  - `should not attempt reconnect after an explicit disconnect` (line 71 `_suppressAutoReconnect` guard; emit down post-disconnect)
  - `should not attempt reconnect when connectedSerial is null while BciActive` — the line-71 serial guard is only reachable in an active phase with `_connectedSerial == null`, i.e. `BciConnecting` mid-flight (set at line 218 *before* `_connectedSerial = serial` at line 221). Setup: set `provider.connectGate` to an un-completed `Completer`, start `connectDevice('A')` without awaiting (state is now `BciConnecting`, `connectedSerial` still null), emit `BciLinkStatus.down`, pump, and assert no reconnect scan fires (`scanCallCount` unchanged). (NOT "down while scanning" — that is rejected earlier at line 68 and is covered by the next case.)
  - `should ignore down when not in an active phase` (line 68 `_state is BciActive` guard; e.g. while scanning)
  - `should ignore BciLinkStatus.up entirely` (line 68 only matches `.down`)
  - `should re-enable reconnect (clear suppress flag) when startScan is called` (line 156)

- [x] **Task 7: reconnect scan termination and error handling**
  Files: `test/Bci/bci_device_manager_test.dart`
  Source: `_attemptReconnect` callbacks lines 277–312.
  Test cases:
  - `should emit BciIdle when the reconnect scan completes without finding the device` (lines 307–309)
  - `should emit BciIdle when the reconnect scan errors with a non-permission exception` (lines 302–304)
  - `should emit BciPermissionDenied when the reconnect scan throws BluetoothPermissionDeniedException` (lines 299–301)

### Phase 6: startScan error handling

- [x] **Task 8: startScan scan-stream error and completion paths**
  Files: `test/Bci/bci_device_manager_test.dart`
  Source: `startScan` `onError` / `onDone` lines 198–214.
  Test cases:
  - `should emit BciPermissionDenied when the scan throws BluetoothPermissionDeniedException` (lines 201–203)
  - `should emit BciIdle when the scan throws a non-permission exception` (lines 205–206)
  - `should emit BciIdle when the scan stream completes while still scanning` (lines 209–212)
