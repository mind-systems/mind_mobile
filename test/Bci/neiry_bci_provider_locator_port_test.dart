import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:mind/Bci/NeiryBciProvider.dart';
import 'package:mind/Bci/Models/BciDeviceInfo.dart';
import 'package:mind/Bci/Models/BciChannelQuality.dart';
import 'package:mind/Bci/Models/BciLinkStatus.dart';
import 'package:mind/Bci/Ports/DevicePort.dart';
import 'package:mind/Bci/Ports/LocatorPort.dart';

// ---------------------------------------------------------------------------
// Stub DevicePort — minimal implementation; no neiry.Device under the hood.
// Full device-driven characterization is B1's job, not this test.
// ---------------------------------------------------------------------------

class _StubDevicePort implements DevicePort {
  @override
  Future<void> connect() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stopStream() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {}

  @override
  bool get isStarted => false;

  @override
  Stream<BciLinkStatus> get connectionStateStream => const Stream.empty();

  @override
  Stream<List<BciChannelQuality>> get resistanceStream => const Stream.empty();

  @override
  Stream<int> get batteryStream => const Stream.empty();
}

// ---------------------------------------------------------------------------
// Fake LocatorPort — test-controlled async; never touches neiry_kit.
// ---------------------------------------------------------------------------

class FakeLocatorPort implements LocatorPort {
  final _devicesController = StreamController<List<BciDeviceInfo>>();
  final _disposeCompleter = Completer<void>();
  int createDeviceCallCount = 0;
  int disposeCallCount = 0;

  @override
  Stream<List<BciDeviceInfo>> requestDevices({
    BciScanDeviceType type = BciScanDeviceType.headband,
    int searchTime = 5,
  }) =>
      _devicesController.stream;

  @override
  Future<DevicePort> createDevice(String serial) async {
    createDeviceCallCount++;
    return _StubDevicePort();
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    _disposeCompleter.complete();
    _devicesController.close();
  }

  /// Push a device list into the scan stream.
  void emitDevices(List<BciDeviceInfo> devices) =>
      _devicesController.add(devices);

  /// Push an error into the scan stream.
  void emitError(Object error) => _devicesController.addError(error);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('NeiryBciProvider — LocatorPort injectable seam', () {
    test(
      'scan() emits BciDeviceInfo from the fake locator, not from the real SDK',
      () async {
        final fake = FakeLocatorPort();
        final provider = NeiryBciProvider(locatorFactory: () => fake);

        final emitted = <List<BciDeviceInfo>>[];
        final sub = provider.scan().listen(emitted.add);

        // Allow the async* generator to run through `await _teardownComplete`
        // and reach `yield*` — requires a full event-loop turn (not just a
        // microtask) so the scheduled microtasks inside the generator complete.
        await Future<void>.delayed(Duration.zero);

        // Fake emits a known device list.
        fake.emitDevices(
            [const BciDeviceInfo(serial: 'TEST-001', name: 'FakeHeadband')]);

        // Allow the event to propagate through the stream chain.
        await Future<void>.delayed(Duration.zero);

        expect(emitted.length, 1);
        expect(emitted[0].length, 1);
        expect(emitted[0][0].serial, 'TEST-001');
        expect(emitted[0][0].name, 'FakeHeadband');

        await sub.cancel();
        provider.dispose();
      },
    );

    test(
      'scan() emits multiple successive device lists from the fake',
      () async {
        final fake = FakeLocatorPort();
        final provider = NeiryBciProvider(locatorFactory: () => fake);

        final emitted = <List<BciDeviceInfo>>[];
        final sub = provider.scan().listen(emitted.add);
        await Future<void>.delayed(Duration.zero);

        fake.emitDevices([const BciDeviceInfo(serial: 'A', name: 'DevA')]);
        fake.emitDevices([
          const BciDeviceInfo(serial: 'B', name: 'DevB'),
          const BciDeviceInfo(serial: 'C', name: 'DevC'),
        ]);
        await Future<void>.delayed(Duration.zero);

        expect(emitted.length, 2);
        expect(emitted[0][0].serial, 'A');
        expect(emitted[1].length, 2);
        expect(emitted[1][1].serial, 'C');

        await sub.cancel();
        provider.dispose();
      },
    );

    test(
      'default constructor uses real adapter — no locatorFactory arg needed',
      () {
        // Just verifies that NeiryBciProvider() constructs without error.
        // (The real NeiryLocatorAdapter is wired; no assertions about behavior.)
        expect(() => NeiryBciProvider(), returnsNormally);
      },
    );

    test(
      'scan() ends cleanly (no error) when dispose() closes the queue before enqueue resolves',
      () async {
        final fake = FakeLocatorPort();
        final provider = NeiryBciProvider(locatorFactory: () => fake);

        var errored = false;
        var done = false;
        final sub = provider.scan().listen(
          (_) {},
          onError: (_) => errored = true,
          onDone: () => done = true,
        );
        // dispose() immediately — _doDispose() closes the queue synchronously
        // before its first await, so the pending enqueue slot sees _closed==true
        // and rejects with QueueClosedException before the settle.
        provider.dispose();
        await Future<void>.delayed(Duration.zero); // settle AFTER dispose
        expect(done, isTrue);
        expect(errored, isFalse,
            reason: 'QueueClosedException must be swallowed, not delivered to onError');
        await sub.cancel();
      },
    );

    test(
      'scan() propagates non-QueueClosedException errors from the scan stream',
      () async {
        final fake = FakeLocatorPort();
        final provider = NeiryBciProvider(locatorFactory: () => fake);

        final errors = <Object>[];
        final sub = provider.scan().listen((_) {}, onError: errors.add);
        // Settle first so the generator reaches yield* and is subscribed to the
        // fake stream before the error is emitted.
        await Future<void>.delayed(Duration.zero);
        fake.emitError(Exception('scan failed'));
        await Future<void>.delayed(Duration.zero);
        expect(errors, isNotEmpty);
        await sub.cancel();
        provider.dispose();
      },
    );
  });
}
