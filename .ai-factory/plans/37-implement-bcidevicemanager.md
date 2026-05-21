# Plan: Implement `BciDeviceManager`

## Context
Add the BCI domain-layer manager that owns the `disconnected → scanning → connecting → impedance → calibrating → ready` state machine on top of `IBciDeviceProvider` and `BciDeviceRepository`. The manager is the single consumer of both collaborators and is consumed by `BciNotifier` in a later milestone. Full spec: `.ai-factory/notes/16-bci-device-manager.md`.

Assumptions:
- No Riverpod imports; no direct Flutter UI imports; logging via the shared `logPrint` helper (which itself uses `package:flutter/foundation`'s `debugPrint`), matching the compromise already accepted in `NeiryBciProvider.dart`.
- Direct dependencies: `IBciDeviceProvider`, `BciDeviceRepository`, the domain models in `lib/Bci/Models/`, and `package:collection` (for `firstWhereOrNull`). `collection` is a transitive dep in `pubspec.lock` but is not declared in `pubspec.yaml` — `flutter_lints` enables `depend_on_referenced_packages`, so a direct import would warn. Task 0 below adds it via `flutter pub add` (project CLAUDE.md mandates this).
- The provider's `scan()` returns one stream per call (per `IBciDeviceProvider.scan()` contract) — every `startScan()` / `_attemptReconnect()` invocation gets a fresh subscription that must be cancelled on disposal or before re-subscribing.
- Internal `_setState` is the only place that mutates `_state` and writes to `_stateController`. All transitions go through it.
- `connect()` on the provider is `Future<void>` and may throw; on throw the manager transitions to `disconnected` and logs via `logPrint` (the project's logger — `BciDeviceManager: …`, matching `NeiryBciProvider` style).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 0: Dependency

- [x] **Task 0: Add direct dependency on `package:collection`**
  Files: `pubspec.yaml`, `pubspec.lock`
  - Run `flutter pub add collection` (CLAUDE.md forbids hand-editing `pubspec.yaml`).
  - Verify the new entry appears under `dependencies:` and that `flutter pub get` succeeds.
  - This satisfies `depend_on_referenced_packages` (enabled via `flutter_lints/flutter.yaml`) before any file in `lib/` imports `package:collection/collection.dart` for the first time.

### Phase 1: Skeleton

- [x] **Task 1: Create `BciDeviceManager` class skeleton with fields, constructor subscriptions, public getters, and dispose** (depends on Task 0)
  Files: `lib/Bci/BciDeviceManager.dart`
  Create a new pure-Dart file under `lib/Bci/`.
  - Imports: `dart:async`, `package:collection/collection.dart`, `package:mind/Bci/IBciDeviceProvider.dart`, `package:mind/Bci/BciDeviceRepository.dart`, `package:mind/Bci/Models/BciCalibrationEvent.dart`, `package:mind/Bci/Models/BciChannelQuality.dart`, `package:mind/Bci/Models/BciConnectionState.dart`, `package:mind/Bci/Models/BciDeviceInfo.dart`, `package:mind/Logger.dart`.
  - Declare `class BciDeviceManager`.
  - Private final collaborators: `final IBciDeviceProvider _provider;` and `final BciDeviceRepository _repository;`.
  - Internal mutable state:
    - `BciConnectionState _state = BciConnectionState.disconnected;`
    - `String? _connectedSerial;`
    - `bool _suppressAutoReconnect = false;`
    - `List<BciDeviceInfo> _discoveredDevices = const <BciDeviceInfo>[];`
  - Broadcast controllers (created in field initializers):
    - `final _stateController = StreamController<BciConnectionState>.broadcast();`
    - `final _discoveredDevicesController = StreamController<List<BciDeviceInfo>>.broadcast();`
  - Subscriptions to provider streams (nullable, initialised in constructor body):
    - `StreamSubscription<BciConnectionState>? _connectionStateSub;`
    - `StreamSubscription<BciCalibrationEvent>? _calibrationSub;`
    - `StreamSubscription<List<BciDeviceInfo>>? _scanSub;` (re-bound by each `startScan()` / `_attemptReconnect()` — Task 2 & Task 5 populate this).
  - Constructor: `BciDeviceManager({required IBciDeviceProvider provider, required BciDeviceRepository repository}) : _provider = provider, _repository = repository { _subscribeProviderStreams(); }`.
  - Private `void _subscribeProviderStreams()` placeholder for now — **the subscriptions must be assigned to the fields immediately so `dispose()` can cancel them even before Tasks 4/5 land**:
    ```dart
    _connectionStateSub = _provider.connectionStateStream.listen((_) {}); // body replaced in Task 5
    _calibrationSub = _provider.calibrationStream.listen((_) {});         // body replaced in Task 4
    ```
    Field assignment is mandatory; do not write bare `_provider.connectionStateStream.listen((_) {});` — that leaks the subscription.
  - Public API getters:
    - `BciConnectionState get state => _state;`
    - `String? get connectedSerial => _connectedSerial;`
    - `Stream<BciConnectionState> get stateStream => _stateController.stream;`
    - `Stream<List<BciDeviceInfo>> get discoveredDevicesStream => _discoveredDevicesController.stream;`
    - `Stream<List<BciChannelQuality>> get signalQualityStream => _provider.signalQualityStream;`
    - `Stream<int> get batteryStream => _provider.batteryStream;`
    - `Stream<BciCalibrationEvent> get calibrationStream => _provider.calibrationStream;`
    - `List<BciDeviceInfo> get discoveredDevices => _discoveredDevices;`
    - `List<String> cachedSerials() => _repository.cachedSerials();`
  - Private helper `void _setState(BciConnectionState next)`:
    - If `next == _state`, return (no-op, no duplicate emission).
    - Set `_state = next;`.
    - `_stateController.add(next);`.
  - `Future<void> dispose()`:
    - Cancel `_connectionStateSub`, `_calibrationSub`, `_scanSub` (each guarded with `?.cancel()`).
    - Close `_stateController`, `_discoveredDevicesController`.
    - Do **not** call `_provider.dispose()` — the manager does not own the provider's lifecycle; whoever constructed the provider disposes it (the `App.initialize` wiring milestone handles this).
  - Public stubs (full bodies land in later tasks — declare empty `async` bodies that throw `UnimplementedError` so call sites compile but tests/usage fail loudly until filled in):
    - `Future<void> startScan() async { throw UnimplementedError(); }`
    - `Future<void> connectDevice(String serial) async { throw UnimplementedError(); }`
    - `Future<void> startCalibration() async { throw UnimplementedError(); }`
    - `Future<void> disconnect() async { throw UnimplementedError(); }`

### Phase 2: Connection lifecycle

- [x] **Task 2: Implement `startScan()` with cached-serial auto-connect** (depends on Task 1)
  Files: `lib/Bci/BciDeviceManager.dart`
  Replace the `startScan()` stub.
  - Body:
    1. `_suppressAutoReconnect = false;` — always cleared (screen was opened fresh, per spec § Auto-reconnect logic).
    2. `_setState(BciConnectionState.scanning);`.
    3. `final cachedSerials = _repository.cachedSerials();` — **synchronous**, no `await`, no network call. If cache is empty, no auto-connect ever happens for this scan.
    4. Cancel any prior scan: `await _scanSub?.cancel();`.
    5. `_scanSub = _provider.scan().listen((discovered) async { … }, onError: (Object e) { logPrint('BciDeviceManager: scan error: $e'); _setState(BciConnectionState.disconnected); });` and inside the data handler:
       - `_discoveredDevices = discovered;`
       - `_discoveredDevicesController.add(discovered);`
       - If `cachedSerials.isEmpty`, `return;` (let user pick manually).
       - Find `final autoConnect = discovered.firstWhereOrNull((d) => cachedSerials.contains(d.serial));`. Cache order is already "most recently used first" (see `BciDeviceRepository.fetchKnownSerials` — server order preserved), so the first hit is the freshest known device.
       - Guard against races: only auto-connect if the manager is still in `scanning` — `if (autoConnect != null && _state == BciConnectionState.scanning) { await connectDevice(autoConnect.serial); }`. This prevents a late scan emission from overwriting a manual user tap that already moved us into `connecting`.
  - `onError` rationale: a scan-stream error (e.g. revoked Bluetooth permission) would otherwise propagate as an uncaught zone error and leave the manager stuck in `scanning`. Transitioning to `disconnected` matches the failure policy used elsewhere.
  - Note for reviewer: the data listener is async because it awaits `connectDevice`. This is intentional — provider scan emissions arrive serially per Dart stream semantics, and `connectDevice` updates `_state` so subsequent emissions short-circuit on the `_state == scanning` guard.

- [x] **Task 3: Implement `connectDevice(serial)` with idempotent `registerDevice`** (depends on Task 1)
  Files: `lib/Bci/BciDeviceManager.dart`
  Replace the `connectDevice` stub.
  - Body:
    1. `_setState(BciConnectionState.connecting);`.
    2. `try { await _provider.connect(serial); … } catch (e) { … }`.
    3. On success inside the `try`:
       - `_connectedSerial = serial;`
       - `_setState(BciConnectionState.impedance);` — the manager owns this transition; the provider's `connectionStateStream` only reports lower-level link state and must not drive it (see spec § connectDevice).
       - Fire-and-forget server registration: `unawaited(_repository.registerDevice(serial));`. `registerDevice` is server-side idempotent (`BciDevicesGrpcApi.register`), so it's safe to call on every successful connect, including re-connects of the same device.
    4. On `catch (e)`:
       - `logPrint('BciDeviceManager: connect failed: $e');`
       - `_setState(BciConnectionState.disconnected);`
       - Do **not** clear `_connectedSerial` here — it was never set (we only assign after a successful connect), so it remains whatever it was before this attempt (typically `null`).
       - Do **not** rethrow — `connectDevice` is awaited by `startScan` and by future UI code; an exception there would break the listener / propagate to the UI as an uncaught error.
  - `unawaited` requires `dart:async` — already imported in Task 1; verify it's still present.
  - Precondition note (informational, no code change): the public method has no state guard. Callers that are not the manager itself (e.g. UI in a later milestone) could invoke it from `impedance` / `ready`; `NeiryBciProvider.connect` will then reject with `StateError`, the catch above handles it cleanly. Flagged here so the `BciNotifier` / UI milestone is not surprised.

- [x] **Task 4: Implement `startCalibration()` and wire calibration event handling** (depends on Task 1)
  Files: `lib/Bci/BciDeviceManager.dart`
  Two changes in one task because the public method and the event handler form a single feature.
  - Replace the `startCalibration` stub with a try/catch wrapper (mirrors `connectDevice` failure handling and prevents the manager from being stuck in `calibrating` if the device is offline):
    ```dart
    _setState(BciConnectionState.calibrating);
    try {
      await _provider.startCalibration();
      // success path: calibration events flow through _provider.calibrationStream
      // and are handled by the listener below.
    } catch (e) {
      logPrint('BciDeviceManager: startCalibration failed: $e');
      _setState(BciConnectionState.impedance);
    }
    ```
  - Replace the empty calibration-stream subscription installed by `_subscribeProviderStreams` in Task 1: cancel the placeholder first (`await _calibrationSub?.cancel();`) then reassign with the real handler:
    ```dart
    _calibrationSub = _provider.calibrationStream.listen((event) {
      switch (event) {
        case BciCalibrationStageFinished():
          break; // stage progress is forwarded to the UI via the public calibrationStream getter — no state change
        case BciCalibrationCompleted():
          _setState(BciConnectionState.ready);
        case BciCalibrationFailed(:final reason):
          logPrint('BciDeviceManager: calibration failed: $reason');
          _setState(BciConnectionState.impedance); // let the user retry from impedance check
      }
    });
    ```
    The cancel-then-reassign is to avoid two concurrent subscriptions on the broadcast stream — the placeholder from Task 1 must be torn down. Place the re-subscription inside `_subscribeProviderStreams` (replacing the placeholder line directly), not inside `startCalibration` — the listener is installed once at construction time and lives for the manager's lifetime.
  - Stage-finished is intentionally a no-op for state — the spec reserves `ready` for the final `Completed` event. UI consumers receive stage progression via `calibrationStream` (the public getter forwards from the provider). Logging the failure reason preserves diagnosability under the "minimal logging" budget.

### Phase 3: Disconnect handling

- [x] **Task 5: Implement manual `disconnect()`, unexpected-disconnect handler, and auto-reconnect** (depends on Tasks 2-4)
  Files: `lib/Bci/BciDeviceManager.dart`
  Three coupled changes — they share `_suppressAutoReconnect` semantics and must land together.
  - Replace the `disconnect` stub:
    - `_suppressAutoReconnect = true;` — set **before** the provider disconnect so the unexpected-disconnect listener sees the suppress flag when the provider emits `disconnected`.
    - `await _provider.disconnect();`
    - `_connectedSerial = null;`
    - `_setState(BciConnectionState.disconnected);`
  - Replace the empty connection-state subscription installed by `_subscribeProviderStreams` in Task 1 with the unexpected-disconnect handler (same cancel-then-reassign pattern as Task 4: `await _connectionStateSub?.cancel();` first, then):
    ```dart
    _connectionStateSub = _provider.connectionStateStream.listen((state) {
      if (state == BciConnectionState.disconnected &&
          _state != BciConnectionState.disconnected &&
          _state != BciConnectionState.scanning) {
        logPrint('BciDeviceManager: unexpected disconnect');
        _setState(BciConnectionState.disconnected);
        if (!_suppressAutoReconnect && _connectedSerial != null) {
          unawaited(_attemptReconnect());
        }
      }
    });
    ```
    Rationale for the `_state` guards: skip if we're already disconnected (idempotent) or still scanning (the provider may briefly report disconnected during scan; that's not an "unexpected" loss because we never reached impedance/ready). Also skip when `_suppressAutoReconnect == true` — manual `disconnect()` already set that flag.
    As with Task 4, place this re-subscription inside `_subscribeProviderStreams` (replacing the placeholder line directly).
  - Add private `Future<void> _attemptReconnect()`:
    - `_setState(BciConnectionState.scanning);`
    - `await _scanSub?.cancel();` — drop any leftover scan subscription before opening a new one.
    - ```dart
      _scanSub = _provider.scan().listen((discovered) async {
        _discoveredDevices = discovered;
        _discoveredDevicesController.add(discovered);
        final match = discovered.firstWhereOrNull((d) => d.serial == _connectedSerial);
        if (match != null && _state == BciConnectionState.scanning) {
          await connectDevice(match.serial);
        }
      }, onError: (Object e) {
        logPrint('BciDeviceManager: reconnect scan error: $e');
        _setState(BciConnectionState.disconnected);
      });
      ```
    - Note: `_attemptReconnect` re-scans for the **specific** previously-connected serial — narrower than `startScan`'s cache-wide auto-connect. This matches the spec § "Unexpected disconnect handler". `onError` parity with `startScan` ensures a mid-reconnect Bluetooth failure does not leave the manager stuck in `scanning`.
  - Final verification (no code change, just a self-check during implementation):
    - All `Future<void>` stubs from Task 1 are now implemented — no `UnimplementedError` remains.
    - `dispose()` cancels `_scanSub` (assigned in Task 2 / Task 5) — already covered by Task 1's dispose (it cancels `_scanSub` even though it's null at skeleton time).
    - Class compiles standalone (no `App.dart` wiring yet — that's the next milestone).
