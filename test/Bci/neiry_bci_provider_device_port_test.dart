import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:mind/Bci/NeiryBciProvider.dart';
import 'package:mind/Bci/Models/BciChannelQuality.dart';
import 'package:mind/Bci/Models/BciDeviceInfo.dart';
import 'package:mind/Bci/Models/BciLinkStatus.dart';
import 'package:mind/Bci/Ports/DevicePort.dart';
import 'package:mind/Bci/Ports/LocatorPort.dart';

// ---------------------------------------------------------------------------
// FakeDevicePort — controllable test double for DevicePort.
// Does NOT import neiry_kit — implements only the port surface declared in
// lib/Bci/Ports/DevicePort.dart.
// ---------------------------------------------------------------------------

class FakeDevicePort implements DevicePort {
  // Broadcast stream controllers so the provider and tests can both subscribe
  // without ordering constraints.
  final _connectionController = StreamController<BciLinkStatus>.broadcast();
  final _resistanceController =
      StreamController<List<BciChannelQuality>>.broadcast();
  final _batteryController = StreamController<int>.broadcast();

  // Call counters — ordered access lets characterization tests assert sequencing.
  int connectCallCount = 0;
  int startCallCount = 0;
  int stopStreamCallCount = 0;
  int disconnectCallCount = 0;
  int disposeCallCount = 0;

  bool _isStarted = false;

  // Test-controlled async — pre-completed by default so methods return
  // immediately. Replace with a fresh unsettled Completer to gate teardown
  // ordering in characterization tests.
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
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    await disposeCompleter.future;
    _connectionController.close();
    _resistanceController.close();
    _batteryController.close();
  }

  // Stream-emission helpers.
  void emitConnection(BciLinkStatus status) =>
      _connectionController.add(status);
  void emitResistance(List<BciChannelQuality> channels) =>
      _resistanceController.add(channels);
  void emitBattery(int level) => _batteryController.add(level);
}

// ---------------------------------------------------------------------------
// _ControlledLocatorPort — returns FakeDevicePort from createDevice().
// Mirrors the FakeLocatorPort seam style from neiry_bci_provider_locator_port_test.dart.
// ---------------------------------------------------------------------------

class _ControlledLocatorPort implements LocatorPort {
  final FakeDevicePort fakeDevice;
  final _devicesController = StreamController<List<BciDeviceInfo>>();
  int createDeviceCallCount = 0;

  _ControlledLocatorPort(this.fakeDevice);

  @override
  Stream<List<BciDeviceInfo>> requestDevices({
    BciScanDeviceType type = BciScanDeviceType.headband,
    int searchTime = 5,
  }) =>
      _devicesController.stream;

  @override
  Future<DevicePort> createDevice(String serial) async {
    createDeviceCallCount++;
    return fakeDevice;
  }

  @override
  Future<void> dispose() async {
    // Do NOT await close() — on a controller with no listener the returned
    // Future never completes, which would block _resetLocatorSession() forever.
    if (!_devicesController.isClosed) _devicesController.close();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Task 2 ─────────────────────────────────────────────────────────────────

  group('NeiryBciProvider — DevicePort injectable seam', () {
    test(
      'connect() routes through the injected DevicePort; '
      'NeiryDeviceAdapter cast throws; cleanup calls disconnect() + dispose()',
      () async {
        final fakeDevice = FakeDevicePort();
        final fakeLocator = _ControlledLocatorPort(fakeDevice);
        final provider = NeiryBciProvider(locatorFactory: () => fakeLocator);

        // Full connect() happy-path is A3-gated: classifier construction still
        // requires rawDevice from a concrete NeiryDeviceAdapter. The assertion
        // below is intentionally scoped to the seam — verify createDevice is
        // called, connect() is forwarded to the fake, and the catch-block
        // cleanup at NeiryBciProvider.dart:177-200 runs.
        await expectLater(
          provider.connect('FAKE-001'),
          throwsA(isA<TypeError>()),
        );

        // Seam was reached exactly once.
        expect(fakeLocator.createDeviceCallCount, 1,
            reason: 'createDevice must be called once per connect()');
        // connect() was forwarded to the DevicePort.
        expect(fakeDevice.connectCallCount, 1,
            reason: 'connect() must be forwarded to the DevicePort');
        // Cleanup path ran (NeiryBciProvider.dart:195-196).
        expect(fakeDevice.disconnectCallCount, 1,
            reason: 'disconnect() must be called in the catch-block cleanup');
        expect(fakeDevice.disposeCallCount, 1,
            reason: 'dispose() must be called in the catch-block cleanup');

        provider.dispose();
      },
    );
  });

  // ── Task 3 ─────────────────────────────────────────────────────────────────

  group('FakeDevicePort — port contract exercise (ready for B1/B2 characterization)', () {
    late FakeDevicePort fake;

    setUp(() => fake = FakeDevicePort());

    tearDown(() async {
      // Close stream controllers if dispose() was not already called by the test.
      if (fake.disposeCallCount == 0) await fake.dispose();
    });

    test('emitConnection routes BciLinkStatus values to stream listeners',
        () async {
      final received = <BciLinkStatus>[];
      final sub = fake.connectionStateStream.listen(received.add);

      fake.emitConnection(BciLinkStatus.up);
      fake.emitConnection(BciLinkStatus.down);
      await Future<void>.delayed(Duration.zero);

      expect(received, [BciLinkStatus.up, BciLinkStatus.down]);
      await sub.cancel();
    });

    test('emitResistance routes channel quality lists to stream listeners',
        () async {
      final received = <List<BciChannelQuality>>[];
      final sub = fake.resistanceStream.listen(received.add);

      fake.emitResistance([
        const BciChannelQuality(
          channelName: 'O1',
          impedanceOhm: 5000,
          level: BciSignalLevel.green,
        ),
        const BciChannelQuality(
          channelName: 'O2',
          impedanceOhm: 12000,
          level: BciSignalLevel.yellow,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(received.length, 1);
      expect(received[0].length, 2);
      expect(received[0][0].channelName, 'O1');
      expect(received[0][1].level, BciSignalLevel.yellow);
      await sub.cancel();
    });

    test('emitBattery routes integer values to stream listeners', () async {
      final received = <int>[];
      final sub = fake.batteryStream.listen(received.add);

      fake.emitBattery(85);
      fake.emitBattery(42);
      await Future<void>.delayed(Duration.zero);

      expect(received, [85, 42]);
      await sub.cancel();
    });

    test('isStarted reflects start() and stopStream()', () async {
      expect(fake.isStarted, isFalse);

      await fake.start();
      expect(fake.isStarted, isTrue);
      expect(fake.startCallCount, 1);

      await fake.stopStream();
      expect(fake.isStarted, isFalse);
      expect(fake.stopStreamCallCount, 1);
    });

    test(
      'stopStream(), disconnect(), dispose() are awaitable, call-counted, '
      'and complete deterministically via the default pre-completed Completers',
      () async {
        await fake.stopStream();
        await fake.disconnect();
        await fake.dispose();

        expect(fake.stopStreamCallCount, 1);
        expect(fake.disconnectCallCount, 1);
        expect(fake.disposeCallCount, 1);
      },
    );

    test(
      'stopStream() blocks until stopStreamCompleter is completed when replaced',
      () async {
        // Replace the pre-completed Completer with a fresh, unsettled one to
        // drive teardown ordering in characterization tests.
        fake.stopStreamCompleter = Completer();

        var done = false;
        final stopFuture = fake.stopStream().then((_) => done = true);

        await Future<void>.delayed(Duration.zero);
        expect(done, isFalse, reason: 'should be blocked on the Completer');

        fake.stopStreamCompleter.complete();
        await stopFuture;
        expect(done, isTrue);
      },
    );
  });

  // ── Default constructor smoke check ─────────────────────────────────────────

  group('NeiryBciProvider — default constructor', () {
    test('constructs without a locatorFactory argument (real adapter path untouched)', () {
      // Confirms NeiryLocatorAdapter is still wired as the default; no behavior
      // change from introducing the DevicePort seam.
      expect(() => NeiryBciProvider(), returnsNormally);
    });
  });
}
