// B1 · Characterization: locator/device races H1 + L2
//
// Characterizes NeiryBciProvider's locator/device lifecycle via the A1/A2
// LocatorPort/DevicePort seams. Green on the current gate version.
// No production-code assertions; all assertions reference observable
// dispose/create counts and wait-ordering so the suite survives
// _teardownComplete's removal in the C1 actor refactor.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mind/Bci/BciDeviceManager.dart';
import 'package:mind/Bci/BciDeviceRepository.dart';
import 'package:mind/Bci/BciDevicesGrpcApi.dart';
import 'package:mind/Bci/NeiryBciProvider.dart';
import 'package:mind/Bci/NfbCalibrationGrpcApi.dart';
import 'package:mind/Bci/NfbCalibrationRepository.dart';
import 'package:mind/Bci/Models/BciChannelQuality.dart';
import 'package:mind/Bci/Models/BciConnectionState.dart';
import 'package:mind/Bci/Models/BciDeviceInfo.dart';
import 'package:mind/Bci/Models/BciEmotionsData.dart';
import 'package:mind/Bci/Models/BciLinkStatus.dart';
import 'package:mind/Bci/Models/BciNfbData.dart';
import 'package:mind/Bci/Models/NfbCalibrationData.dart';
import 'package:mind/Bci/Ports/ClassifierFactory.dart';
import 'package:mind/Bci/Ports/ClassifierSet.dart';
import 'package:mind/Bci/Ports/DevicePort.dart';
import 'package:mind/Bci/Ports/LocatorPort.dart';
import 'package:mind/Biometrics/Models/CardioData.dart';
import 'package:mind/Biometrics/Models/MotionData.dart';
import 'package:mind/Biometrics/Models/RrInterval.dart';

// ── GatedFakeDevicePort ──────────────────────────────────────────────────────

/// A fully controllable DevicePort for race characterization.
///
/// - Completers gate *timing* of each async call (default pre-completed).
/// - `throwOnDisconnect`/`throwOnDispose` make the call throw *after* the gate
///   resolves (needed by Task 6's swallow check).
/// - `emitConnection` fires on the broadcast connectionStateStream so the
///   provider's drop handler fires.
/// - Each instance is independent: createDevice() in RecordingLocatorPort
///   returns a fresh one so Task 4's reconnect does not share controllers.
class GatedFakeDevicePort implements DevicePort {
  final _connectionController = StreamController<BciLinkStatus>.broadcast();
  final _resistanceController =
      StreamController<List<BciChannelQuality>>.broadcast();
  final _batteryController = StreamController<int>.broadcast();

  int connectCallCount = 0;
  int startCallCount = 0;
  int stopStreamCallCount = 0;
  int disconnectCallCount = 0;
  int disposeCallCount = 0;
  bool _isStarted = false;

  bool throwOnDisconnect = false;
  bool throwOnDispose = false;

  Completer<void> stopStreamCompleter = Completer()..complete();
  Completer<void> disconnectCompleter = Completer()..complete();
  Completer<void> disposeCompleter = Completer()..complete();

  @override
  bool get isStarted => _isStarted;

  @override
  Stream<BciLinkStatus> get connectionStateStream =>
      _connectionController.stream;

  @override
  Stream<List<BciChannelQuality>> get resistanceStream =>
      _resistanceController.stream;

  @override
  Stream<int> get batteryStream => _batteryController.stream;

  @override
  Future<void> connect() async {
    connectCallCount++;
  }

  @override
  Future<void> start() async {
    startCallCount++;
    _isStarted = true;
  }

  @override
  Future<void> stopStream() async {
    stopStreamCallCount++;
    _isStarted = false;
    await stopStreamCompleter.future;
  }

  @override
  Future<void> disconnect() async {
    disconnectCallCount++;
    await disconnectCompleter.future;
    if (throwOnDisconnect) throw StateError('GatedFakeDevicePort: disconnect error');
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    await disposeCompleter.future;
    if (throwOnDispose) throw StateError('GatedFakeDevicePort: dispose error');
    _connectionController.close();
    _resistanceController.close();
    _batteryController.close();
  }

  void emitConnection(BciLinkStatus status) =>
      _connectionController.add(status);

  /// Force-close stream controllers (for test teardown when dispose threw).
  void closeControllers() {
    if (!_connectionController.isClosed) _connectionController.close();
    if (!_resistanceController.isClosed) _resistanceController.close();
    if (!_batteryController.isClosed) _batteryController.close();
  }
}

// ── RecordingLocatorPort ─────────────────────────────────────────────────────

/// LocatorPort that records every call and vends fresh GatedFakeDevicePorts.
///
/// dispose() throws StateError on a second call (mirrors the real adapter's
/// double-dispose contract so _resetLocatorSession's try/catch is exercised).
class RecordingLocatorPort implements LocatorPort {
  int requestDevicesCallCount = 0;
  int createDeviceCallCount = 0;
  int disposeCount = 0;

  /// Replaceable Completer — hold open to block _resetLocatorSession at dispose.
  Completer<void> disposeCompleter = Completer()..complete();

  /// Replaceable Completer — hold open to block createDevice (connect-racing-drop probe).
  Completer<void> createDeviceCompleter = Completer()..complete();

  final StreamController<List<BciDeviceInfo>> _devicesController =
      StreamController<List<BciDeviceInfo>>();

  /// Last device returned from createDevice(); updated on every call.
  GatedFakeDevicePort? lastCreatedDevice;

  @override
  Stream<List<BciDeviceInfo>> requestDevices({
    BciScanDeviceType type = BciScanDeviceType.headband,
    int searchTime = 5,
  }) {
    requestDevicesCallCount++;
    return _devicesController.stream;
  }

  @override
  Future<DevicePort> createDevice(String serial) async {
    createDeviceCallCount++;
    await createDeviceCompleter.future;
    final device = GatedFakeDevicePort();
    lastCreatedDevice = device;
    return device;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    if (disposeCount > 1) {
      throw StateError('RecordingLocatorPort: double-dispose');
    }
    await disposeCompleter.future;
    if (!_devicesController.isClosed) _devicesController.close();
  }

  void emitDevices(List<BciDeviceInfo> devices) =>
      _devicesController.add(devices);
}

// ── RecordingLocatorRegistry ─────────────────────────────────────────────────

/// Tracks every RecordingLocatorPort vended by locatorFactory.
///
/// Provides registry-level helpers used by L2/H1 probes:
/// - liveCount = created − disposed (number with disposeCount == 0)
/// - assertNoOrphan() fails if any locator was replaced before being disposed
class RecordingLocatorRegistry {
  final List<RecordingLocatorPort> instances = [];
  bool _orphanDetected = false;

  late final LocatorPort Function() locatorFactory;

  RecordingLocatorRegistry() {
    locatorFactory = () {
      // If a previous locator still has disposeCount == 0 at the moment a new
      // one is created, that is a replace-without-dispose — record an orphan.
      if (instances.isNotEmpty && instances.last.disposeCount == 0) {
        _orphanDetected = true;
      }
      final port = RecordingLocatorPort();
      instances.add(port);
      return port;
    };
  }

  int get createdCount => instances.length;

  /// Number of locators that have not yet been disposed (disposeCount == 0).
  int get liveCount =>
      instances.where((p) => p.disposeCount == 0).length;

  /// Asserts no locator was overwritten while still live.
  /// Checks both the runtime-detected orphan flag and structural invariants.
  void assertNoOrphan() {
    expect(_orphanDetected, isFalse,
        reason: 'A locator was replaced without first being disposed (orphan detected at factory-call time)');
    // Every locator that has been replaced (all but the last) must be disposed.
    for (int i = 0; i < instances.length - 1; i++) {
      expect(instances[i].disposeCount, greaterThan(0),
          reason: 'Locator at index $i was never disposed before replacement');
    }
  }
}

// ── FakeClassifierSet / FakeClassifierFactory ─────────────────────────────────

/// Minimal ClassifierSet — enables a full connect() without neiry_kit.
class FakeClassifierSet implements ClassifierSet {
  final _nfbController = StreamController<BciNfbData>.broadcast();
  final _nfbErrorController = StreamController<String>.broadcast();
  final _cardioController = StreamController<CardioData>.broadcast();
  final _rrController = StreamController<RrInterval>.broadcast();
  final _emotionsController = StreamController<BciEmotionsData>.broadcast();
  final _emotionsErrorController = StreamController<String>.broadcast();
  final _motionController = StreamController<MotionData>.broadcast();

  int disposeCallCount = 0;

  @override
  Stream<BciNfbData> get nfbStateStream => _nfbController.stream;
  @override
  Stream<String> get nfbErrorStream => _nfbErrorController.stream;
  @override
  Stream<CardioData> get cardioStateStream => _cardioController.stream;
  @override
  Stream<RrInterval> get rrStream => _rrController.stream;
  @override
  Stream<BciEmotionsData> get emotionsStateStream => _emotionsController.stream;
  @override
  Stream<String> get emotionsErrorStream => _emotionsErrorController.stream;
  @override
  Stream<MotionData> get motionStream => _motionController.stream;

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    _nfbController.close();
    _nfbErrorController.close();
    _cardioController.close();
    _rrController.close();
    _emotionsController.close();
    _emotionsErrorController.close();
    _motionController.close();
  }
}

class FakeClassifierFactory implements ClassifierFactory {
  final FakeClassifierSet classifierSet;
  FakeClassifierFactory(this.classifierSet);

  @override
  ClassifierSet build(DevicePort device) => classifierSet;
}

// ── Fake gRPC APIs for Task 4 ─────────────────────────────────────────────────

/// Dart implicit-interface fake for BciDevicesGrpcApi.
/// BciDeviceRepository takes the concrete class, not IBciDevicesGrpcApi.
class _FakeBciDevicesGrpcApi implements BciDevicesGrpcApi {
  @override
  Future<List<({String id, String serial})>> listDevices() async => [];

  @override
  Future<({String id, String serial})> register(String serial) async =>
      (id: 'fake-id', serial: serial);

  @override
  Future<void> delete(String id) async {}
}

/// Dart implicit-interface fake for NfbCalibrationGrpcApi.
class _FakeNfbCalibrationGrpcApi implements NfbCalibrationGrpcApi {
  @override
  Future<void> record(String serial, NfbCalibrationData data) async {}

  @override
  Future<List<NfbCalibrationData>> list(String serial,
      {int limit = 50}) async => [];
}

// ── connectThenDrop helper ────────────────────────────────────────────────────

/// Result bundle returned by [_connectThenDrop].
class _DropSetup {
  final NeiryBciProvider provider;
  final RecordingLocatorRegistry registry;
  final RecordingLocatorPort l0; // initial locator (index 0)
  final GatedFakeDevicePort device; // device created during connect()
  final FakeClassifierSet classifierSet;

  _DropSetup({
    required this.provider,
    required this.registry,
    required this.l0,
    required this.device,
    required this.classifierSet,
  });
}

/// Builds a NeiryBciProvider, drives connect() to success, then emits an
/// unexpected drop — leaving the teardown Completers open (test controls timing).
///
/// After this returns:
/// - _teardownComplete is set (microtask scheduled, may be in-flight)
/// - device.stopStreamCompleter, device.disconnectCompleter,
///   device.disposeCompleter are fresh (unresolved)
/// - l0.disposeCompleter is fresh (unresolved)
Future<_DropSetup> _connectThenDrop({String serial = 'TEST-001'}) async {
  final registry = RecordingLocatorRegistry();
  final fakeSet = FakeClassifierSet();
  final fakeFactory = FakeClassifierFactory(fakeSet);

  final provider = NeiryBciProvider(
    locatorFactory: registry.locatorFactory,
    classifierFactory: fakeFactory,
  );

  // Initial locator is created in the constructor.
  final l0 = registry.instances.first;

  // Happy-path connect: device is created and classifiers are wired up.
  await provider.connect(serial);

  // Grab the device before gating teardown.
  final device = l0.lastCreatedDevice!;

  // Replace Completers with fresh (unsettled) ones BEFORE emitting the drop,
  // so the teardown microtask blocks on them when it runs.
  device.stopStreamCompleter = Completer();
  device.disconnectCompleter = Completer();
  device.disposeCompleter = Completer();
  l0.disposeCompleter = Completer();

  // Emit the drop. The StreamController.broadcast() is async: the listener
  // (_onConnectionStatus) is delivered as a microtask, not synchronously.
  device.emitConnection(BciLinkStatus.down);

  // Let the listener run so _teardownComplete is assigned and the teardown
  // microtask is scheduled. (plan-review #4)
  await Future<void>.delayed(Duration.zero);

  return _DropSetup(
    provider: provider,
    registry: registry,
    l0: l0,
    device: device,
    classifierSet: fakeSet,
  );
}

/// Completes all held teardown gates in the canonical sequence
/// (stopStream → disconnect → dispose → locator dispose) and waits for
/// teardown to finish.
Future<void> _completeTeardown(_DropSetup s) async {
  s.device.stopStreamCompleter.complete();
  await Future<void>.delayed(Duration.zero);
  s.device.disconnectCompleter.complete();
  await Future<void>.delayed(Duration.zero);
  s.device.disposeCompleter.complete();
  await Future<void>.delayed(Duration.zero);
  s.l0.disposeCompleter.complete();
  await Future<void>.delayed(Duration.zero);
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ── Phase 1: Sanity smoke ──────────────────────────────────────────────────

  group('Phase 1 — sanity smoke', () {
    test(
      'clean connect() leaves exactly one live locator (L0) and zero orphans',
      () async {
        final registry = RecordingLocatorRegistry();
        final fakeSet = FakeClassifierSet();
        final provider = NeiryBciProvider(
          locatorFactory: registry.locatorFactory,
          classifierFactory: FakeClassifierFactory(fakeSet),
        );

        await provider.connect('TEST-001');

        expect(registry.createdCount, 1, reason: 'only L0 created so far');
        expect(registry.liveCount, 1, reason: 'L0 is still live');
        registry.assertNoOrphan();

        provider.dispose();
        await Future<void>.delayed(Duration.zero);
      },
    );
  });

  // ── Phase 2: L2 — orphan locator leak ─────────────────────────────────────

  group('Phase 2 — L2 orphan-invariant probes', () {
    test(
      'pure drop: L0 disposed exactly once, one fresh locator (L1) created, '
      'liveCount == 1, no orphan',
      () async {
        final s = await _connectThenDrop();

        // While teardown is in-flight, L0 is not yet disposed.
        expect(s.l0.disposeCount, 0);
        expect(s.registry.liveCount, 1, reason: 'L0 still live (teardown in-flight)');

        // Complete the full teardown.
        await _completeTeardown(s);

        // After teardown: L0 disposed, L1 created.
        expect(s.registry.createdCount, 2, reason: 'L0 + L1');
        expect(s.l0.disposeCount, 1, reason: 'L0 disposed exactly once');
        expect(s.registry.liveCount, 1, reason: 'only L1 is live');
        s.registry.assertNoOrphan();

        s.provider.dispose();
        await Future<void>.delayed(Duration.zero);
      },
    );

    test(
      'drop then concurrent disconnect (a): liveCount ≤ 1 at all times, no orphan',
      () async {
        final s = await _connectThenDrop();

        // Call disconnect() while teardown is in-flight.
        // disconnect() gates on await _teardownComplete, so it queues behind it.
        final disconnectFuture = s.provider.disconnect();

        // While teardown is in-flight, liveCount may be 1 (L0 still live).
        expect(s.registry.liveCount, lessThanOrEqualTo(1));

        // Complete device teardown gates.
        await _completeTeardown(s);
        // Now the in-flight teardown completes, creating L1.
        // Then disconnect() proceeds and calls _resetLocatorSession() again
        // (disconnect()'s unconditional reset — this is correct churn, not a bug).

        // L1's disposeCompleter is pre-completed by default (fresh GatedFakeDevicePort
        // has pre-completed Completers in the locator's createDevice). So the
        // disconnect's second _resetLocatorSession runs to completion.
        await disconnectFuture;

        // Invariants: no two live locators at any point, no orphan.
        expect(s.registry.liveCount, lessThanOrEqualTo(1));
        s.registry.assertNoOrphan();

        // L0 was disposed exactly once (by the drop teardown, not by disconnect).
        expect(s.l0.disposeCount, 1);

        s.provider.dispose();
        await Future<void>.delayed(Duration.zero);
      },
    );

    test(
      'drop then concurrent disconnect (b): behavioral invariants hold '
      'regardless of reset count',
      () async {
        final s = await _connectThenDrop();

        // Parallel path: complete teardown first, then disconnect.
        await _completeTeardown(s);
        // L1 is now live, L0 disposed.
        expect(s.registry.liveCount, 1);
        s.registry.assertNoOrphan();

        // Now disconnect() — it awaits _teardownComplete (already done) and
        // calls _resetLocatorSession() unconditionally. That is correct churn.
        await s.provider.disconnect();

        expect(s.registry.liveCount, lessThanOrEqualTo(1));
        s.registry.assertNoOrphan();

        // L0 disposed exactly once; no locator disposed more than once without
        // a new replacement (tracked via assertNoOrphan).
        expect(s.l0.disposeCount, 1);

        s.provider.dispose();
        await Future<void>.delayed(Duration.zero);
      },
    );
  });

  // ── Phase 3: H1 — auto-reconnect hang ─────────────────────────────────────

  group('Phase 3 — H1 wait-and-fresh-locator probes', () {
    test(
      'H1 provider-level: scan() gates on in-flight teardown; requestDevices() '
      'is never called on the dropped (old) locator; fresh locator gets the call',
      () async {
        final s = await _connectThenDrop();

        // scan() started while teardown is in-flight. It must gate on
        // _teardownComplete and not call requestDevices() on L0.
        final scanned = <List<BciDeviceInfo>>[];
        final scanSub = s.provider.scan().listen(scanned.add);

        // Allow scan() to reach the gate.
        await Future<void>.delayed(Duration.zero);

        // Invariant: the old (dropped) locator must not have received a
        // requestDevices() call — that is the H1 hang signature.
        expect(s.l0.requestDevicesCallCount, 0,
            reason: 'old locator must not be scanned while teardown is in-flight');
        expect(scanned, isEmpty, reason: 'no events emitted while gated');

        // Complete the teardown → L1 is created.
        await _completeTeardown(s);

        // Give scan() time to proceed past the gate.
        await Future<void>.delayed(Duration.zero);

        // Now L1 should have received the requestDevices() call.
        final l1 = s.registry.instances[1];
        expect(l1.requestDevicesCallCount, 1,
            reason: 'fresh locator must receive requestDevices()');
        expect(s.l0.requestDevicesCallCount, 0,
            reason: 'old locator must still have 0 requestDevices() calls');

        // Emit a device from L1 — scan stream becomes live.
        l1.emitDevices([const BciDeviceInfo(serial: 'TEST-001', name: 'Headband')]);
        await Future<void>.delayed(Duration.zero);
        expect(scanned.length, 1, reason: 'scan emits on the fresh locator');

        await scanSub.cancel();
        s.provider.dispose();
        await Future<void>.delayed(Duration.zero);
      },
    );
  });

  // ── Phase 3 Task 4: H1 BciDeviceManager integration ───────────────────────

  group('Phase 3 — H1 reconnect integration (BciDeviceManager)', () {
    late SharedPreferences prefs;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test(
      'H1 manager-level: _attemptReconnect() uses fresh locator after unexpected drop; '
      'old locator never receives requestDevices()',
      () async {
        final registry = RecordingLocatorRegistry();
        final fakeSet = FakeClassifierSet();
        final provider = NeiryBciProvider(
          locatorFactory: registry.locatorFactory,
          classifierFactory: FakeClassifierFactory(fakeSet),
        );

        final repository = BciDeviceRepository(
          api: _FakeBciDevicesGrpcApi(),
          prefs: prefs,
        );
        final nfbRepo = NfbCalibrationRepository(
          prefs: prefs,
          api: _FakeNfbCalibrationGrpcApi(),
        );

        final manager = BciDeviceManager(
          provider: provider,
          cardioSource: provider,
          eegBandsSource: provider,
          emotionsSource: provider,
          repository: repository,
          nfbCalibrationRepository: nfbRepo,
        );

        // Drive connectDevice() to BciImpedance so _state is BciActive and
        // the connection-state listener will fire _attemptReconnect() on a drop.
        await manager.connectDevice('TEST-001');
        expect(manager.state, isA<BciImpedance>());
        expect(manager.connectedSerial, 'TEST-001');

        final l0 = registry.instances.first;
        final device = l0.lastCreatedDevice!;

        // Gate teardown before emitting the drop.
        device.stopStreamCompleter = Completer();
        device.disconnectCompleter = Completer();
        device.disposeCompleter = Completer();
        l0.disposeCompleter = Completer();

        device.emitConnection(BciLinkStatus.down);
        await Future<void>.delayed(Duration.zero);

        // Manager transitions to BciScanning via _attemptReconnect().
        expect(manager.state, isA<BciScanning>());

        // Old locator must not be scanned yet (gate is in-flight).
        expect(l0.requestDevicesCallCount, 0,
            reason: 'old locator must not receive requestDevices() while teardown is in-flight');

        // Complete teardown so L1 is created and scan() can proceed.
        device.stopStreamCompleter.complete();
        await Future<void>.delayed(Duration.zero);
        device.disconnectCompleter.complete();
        await Future<void>.delayed(Duration.zero);
        device.disposeCompleter.complete();
        await Future<void>.delayed(Duration.zero);
        l0.disposeCompleter.complete();
        await Future<void>.delayed(Duration.zero);

        // Fresh locator L1 should now have the requestDevices() call.
        expect(registry.createdCount, greaterThanOrEqualTo(2));
        final l1 = registry.instances[1];
        expect(l1.requestDevicesCallCount, 1,
            reason: 'fresh locator receives requestDevices() from _attemptReconnect()');
        expect(l0.requestDevicesCallCount, 0,
            reason: 'old locator remains at 0');

        // Emit the device from L1's scan stream → manager should reconnect.
        l1.emitDevices([const BciDeviceInfo(serial: 'TEST-001', name: 'Headband')]);
        await Future<void>.delayed(Duration.zero);

        // Manager proceeds to connect via L1 → BciImpedance again.
        await Future<void>.delayed(Duration.zero);
        expect(manager.state, isA<BciImpedance>(),
            reason: 'manager reconnected through the fresh locator');

        await manager.dispose();
        provider.dispose();
        await Future<void>.delayed(Duration.zero);
      },
    );
  });

  // ── Phase 4: Adversarial interleavings ────────────────────────────────────

  group('Phase 4 — adversarial interleavings', () {
    test(
      'dispose between gate-await and requestDevices(): scan lands on a live locator',
      () async {
        final s = await _connectThenDrop();

        // Start scan() — it gates on _teardownComplete.
        final scanSub = s.provider.scan().listen((_) {});
        await Future<void>.delayed(Duration.zero);

        // Complete teardown (swaps L0 → L1). The scan's gate resolves and
        // requestDevices() will run on whatever _locator is at that point.
        await _completeTeardown(s);
        await Future<void>.delayed(Duration.zero);

        // requestDevices() must have landed on a live (non-disposed) locator.
        // L0 is disposed and must have 0 calls. L1 is live and gets the call.
        expect(s.l0.requestDevicesCallCount, 0,
            reason: 'requestDevices() must not be called on a disposed locator');
        final l1 = s.registry.instances[1];
        expect(l1.requestDevicesCallCount, 1,
            reason: 'requestDevices() lands on the live L1');
        expect(l1.disposeCount, 0, reason: 'L1 is not disposed');

        await scanSub.cancel();
        s.provider.dispose();
        await Future<void>.delayed(Duration.zero);
      },
    );

    test(
      'double unexpected-drop: second down event is a no-op '
      '(idempotency guard); liveCount ≤ 1, no orphan, no extra reset',
      () async {
        final s = await _connectThenDrop();

        // Emit a second BciLinkStatus.down while teardown is in-flight.
        // _onConnectionStatus(down) guard: if _device == null, return.
        // After the first drop, _device was nulled synchronously inside
        // _teardownAfterUnexpectedDrop(), so the second event is a no-op.
        s.device.emitConnection(BciLinkStatus.down);
        await Future<void>.delayed(Duration.zero);

        // Only one reset in progress; created count still 1.
        expect(s.registry.createdCount, 1,
            reason: 'no extra locator created by the second drop');
        expect(s.registry.liveCount, lessThanOrEqualTo(1));

        // Complete the one teardown.
        await _completeTeardown(s);

        // After teardown: exactly two locators (L0 + L1), L0 disposed once.
        expect(s.registry.createdCount, 2);
        expect(s.l0.disposeCount, 1,
            reason: 'L0 disposed exactly once despite two drop events');
        expect(s.registry.liveCount, 1);
        s.registry.assertNoOrphan();

        s.provider.dispose();
        await Future<void>.delayed(Duration.zero);
      },
    );

    test(
      'drop-before-subscribe is inert: BciLinkStatus.down emitted before '
      '_subscribeDeviceStreams() has no effect (no teardown, liveCount == 1)',
      () async {
        final registry = RecordingLocatorRegistry();
        final fakeSet = FakeClassifierSet();
        final provider = NeiryBciProvider(
          locatorFactory: registry.locatorFactory,
          classifierFactory: FakeClassifierFactory(fakeSet),
        );

        final l0 = registry.instances.first;

        // Gate createDevice so connect() blocks before _subscribeDeviceStreams().
        l0.createDeviceCompleter = Completer();

        // Start connect() but don't await it yet.
        final connectFuture = provider.connect('TEST-001');
        await Future<void>.delayed(Duration.zero);

        // Device has been created... actually not yet, createDevice is gated.
        // createDevice hasn't returned so _device is not set.
        // Emit down on the old device — but there is no subscription yet.
        // (There's no device at all; this is a pre-connect drop on the locator's
        // broadcast stream, which has no subscriber in the provider.)
        // We emit on a manually-created device to confirm the provider ignores it.
        final orphanDevice = GatedFakeDevicePort();
        orphanDevice.emitConnection(BciLinkStatus.down);
        await Future<void>.delayed(Duration.zero);

        // Release createDevice so connect() can finish.
        l0.createDeviceCompleter.complete();
        await connectFuture;

        // connect() succeeded with no teardown side-effects.
        expect(registry.createdCount, 1, reason: 'only L0, no teardown reset');
        expect(l0.disposeCount, 0, reason: 'no teardown ran');
        expect(registry.liveCount, 1);
        registry.assertNoOrphan();

        orphanDevice.closeControllers();
        provider.dispose();
        await Future<void>.delayed(Duration.zero);
      },
    );
  });

  // ── Phase 4 Task 6: Partial L1 — thrown teardown on connect() failure ──────

  group('Phase 4 — partial L1: thrown teardown on connect() failure', () {
    test(
      'connect() failure cleanup swallows disconnect()/dispose() throws; '
      'locator is still reset cleanly (old disposed, fresh created, liveCount == 1)',
      () async {
        // NeiryClassifierFactory (default) casts the device to NeiryDeviceAdapter
        // and throws TypeError — entering the :172 catch block. The device has
        // throwOnDispose = true: disconnect() succeeds (:178), dispose() throws
        // (:179) but the inner try/catch (:177-180) swallows it, then
        // _resetLocatorSession() still runs before the TypeError is reThrown.
        final registry = RecordingLocatorRegistry();

        LocatorPort throwingFactory() {
          final port = _ThrowingDeviceLocatorPort();
          registry.instances.add(port);
          return port;
        }

        final provider = NeiryBciProvider(locatorFactory: throwingFactory);

        await expectLater(
          provider.connect('TEST-001'),
          throwsA(isA<TypeError>()),
        );

        final l0 = registry.instances.first as _ThrowingDeviceLocatorPort;
        expect(l0.lastCreatedDevice?.disconnectCallCount, 1,
            reason: 'disconnect() was called in the failure cleanup');
        expect(l0.lastCreatedDevice?.disposeCallCount, 1,
            reason: 'dispose() was called in the failure cleanup');

        // Despite the throw, _resetLocatorSession() ran: L0 disposed, L1 created.
        expect(registry.createdCount, 2,
            reason: '_resetLocatorSession created L1 after cleanup');
        expect(l0.disposeCount, 1,
            reason: 'L0 disposed exactly once by _resetLocatorSession');
        expect(registry.liveCount, 1, reason: 'only L1 is live');
        registry.assertNoOrphan();

        // dispose() threw before closing stream controllers — close manually.
        l0.lastCreatedDevice?.closeControllers();

        provider.dispose();
        await Future<void>.delayed(Duration.zero);
      },
    );
  });

  // ── Phase 5: green-up ──────────────────────────────────────────────────────
  // (Run-time validation handled by Task 7: flutter test.)
}

// ── _ThrowingDeviceLocatorPort ────────────────────────────────────────────────

/// RecordingLocatorPort that vends GatedFakeDevicePort instances with
/// throwOnDispose = true. throwOnDisconnect is intentionally NOT set: if
/// disconnect() throws first, dispose() is never reached (same try/catch at
/// :177-180) and we cannot assert both call counts.
class _ThrowingDeviceLocatorPort extends RecordingLocatorPort {
  @override
  Future<DevicePort> createDevice(String serial) async {
    createDeviceCallCount++;
    final device = GatedFakeDevicePort()
      ..throwOnDispose = true; // disconnect() succeeds; dispose() throws + is swallowed
    lastCreatedDevice = device;
    return device;
  }
}
