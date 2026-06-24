import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:mind/Bci/NeiryBciProvider.dart';
import 'package:mind/Bci/Models/BciChannelQuality.dart';
import 'package:mind/Bci/Models/BciDeviceInfo.dart';
import 'package:mind/Bci/Models/BciEmotionsData.dart';
import 'package:mind/Bci/Models/BciLinkStatus.dart';
import 'package:mind/Bci/Models/BciNfbData.dart';
import 'package:mind/Bci/Ports/ClassifierSet.dart';
import 'package:mind/Bci/Ports/DevicePort.dart';
import 'package:mind/Bci/Ports/LocatorPort.dart';
import 'package:mind/Biometrics/Models/CardioData.dart';
import 'package:mind/Biometrics/Models/MotionData.dart';
import 'package:mind/Biometrics/Models/RrInterval.dart';
import 'package:mind/Biometrics/Models/SensorSource.dart';

// ---------------------------------------------------------------------------
// FakeClassifierSet — implements ClassifierSet with seven broadcast controllers
// and a call-counted dispose().
// ---------------------------------------------------------------------------

class FakeClassifierSet implements ClassifierSet {
  final _nfbStateController = StreamController<BciNfbData>.broadcast();
  final _nfbErrorController = StreamController<String>.broadcast();
  final _cardioStateController = StreamController<CardioData>.broadcast();
  final _rrController = StreamController<RrInterval>.broadcast();
  final _emotionsStateController = StreamController<BciEmotionsData>.broadcast();
  final _emotionsErrorController = StreamController<String>.broadcast();
  final _motionController = StreamController<MotionData>.broadcast();

  int disposeCallCount = 0;
  bool throwOnDispose = false;

  @override
  Stream<BciNfbData> get nfbStateStream => _nfbStateController.stream;

  @override
  Stream<String> get nfbErrorStream => _nfbErrorController.stream;

  @override
  Stream<CardioData> get cardioStateStream => _cardioStateController.stream;

  @override
  Stream<RrInterval> get rrStream => _rrController.stream;

  @override
  Stream<BciEmotionsData> get emotionsStateStream =>
      _emotionsStateController.stream;

  @override
  Stream<String> get emotionsErrorStream => _emotionsErrorController.stream;

  @override
  Stream<MotionData> get motionStream => _motionController.stream;

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    if (throwOnDispose) throw StateError('FakeClassifierSet: dispose error');
    _nfbStateController.close();
    _nfbErrorController.close();
    _cardioStateController.close();
    _rrController.close();
    _emotionsStateController.close();
    _emotionsErrorController.close();
    _motionController.close();
  }

  // Emit helpers —————————————————————————————————————————————————————————————

  void emitNfb(BciNfbData data) => _nfbStateController.add(data);
  void emitCardio(CardioData data) => _cardioStateController.add(data);
  void emitRr(RrInterval data) => _rrController.add(data);
  void emitEmotions(BciEmotionsData data) => _emotionsStateController.add(data);
  void emitMotion(MotionData data) => _motionController.add(data);
}

// ---------------------------------------------------------------------------
// FakeDevicePort — controllable test double for DevicePort.
// Owns its FakeClassifierSet; returns it from buildClassifierSet().
// ---------------------------------------------------------------------------

class FakeDevicePort implements DevicePort {
  final _connectionController = StreamController<BciLinkStatus>.broadcast();
  final _resistanceController =
      StreamController<List<BciChannelQuality>>.broadcast();
  final _batteryController = StreamController<int>.broadcast();

  final FakeClassifierSet classifierSet;

  int connectCallCount = 0;
  int startCallCount = 0;
  int stopStreamCallCount = 0;
  int disconnectCallCount = 0;
  int disposeCallCount = 0;
  int buildClassifierSetCallCount = 0;

  bool throwOnBuildClassifierSet = false;

  bool _isStarted = false;

  FakeDevicePort(this.classifierSet);

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
  }

  @override
  Future<void> disconnect() async {
    disconnectCallCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    _connectionController.close();
    _resistanceController.close();
    _batteryController.close();
  }

  @override
  ClassifierSet buildClassifierSet() {
    buildClassifierSetCallCount++;
    if (throwOnBuildClassifierSet) {
      throw StateError('FakeDevicePort: buildClassifierSet error');
    }
    return classifierSet;
  }
}

// ---------------------------------------------------------------------------
// _ControlledLocatorPort — returns FakeDevicePort from createDevice().
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
    if (!_devicesController.isClosed) _devicesController.close();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Task 6 — classifier port injectability ──────────────────────────────────

  group('NeiryBciProvider — ClassifierSet injectable via DevicePort', () {
    late FakeClassifierSet fakeSet;
    late FakeDevicePort fakeDevice;
    late _ControlledLocatorPort fakeLocator;
    late NeiryBciProvider provider;

    setUp(() {
      fakeSet = FakeClassifierSet();
      fakeDevice = FakeDevicePort(fakeSet);
      fakeLocator = _ControlledLocatorPort(fakeDevice);
      provider = NeiryBciProvider(
        locatorFactory: () => fakeLocator,
      );
    });

    tearDown(() {
      provider.dispose();
    });

    // ── Test 1: happy-path connect ────────────────────────────────────────────

    test(
      'connect() with FakeDevicePort completes without throwing; '
      'buildClassifierSet() called once; device.start() called once',
      () async {
        await provider.connect('FAKE-001');

        expect(fakeDevice.buildClassifierSetCallCount, 1,
            reason: 'buildClassifierSet() must be called exactly once per connect()');
        expect(fakeDevice.startCallCount, 1,
            reason: 'device.start() must be called once after buildClassifierSet()');
        expect(fakeDevice.connectCallCount, 1,
            reason: 'device.connect() must be called before buildClassifierSet()');
      },
    );

    test(
      'classifier streams surface on the matching provider public streams '
      'after connect()',
      () async {
        await provider.connect('FAKE-001');

        final ts = DateTime(2024, 1, 1);

        // nfbStream
        final nfbReceived = <BciNfbData>[];
        final nfbSub = provider.nfbStream.listen(nfbReceived.add);
        fakeSet.emitNfb(BciNfbData(timestamp: ts, alpha: 0.5));
        await Future<void>.delayed(Duration.zero);
        expect(nfbReceived.length, 1);
        expect(nfbReceived[0].alpha, 0.5);
        await nfbSub.cancel();

        // cardioStream
        final cardioReceived = <CardioData>[];
        final cardioSub = provider.cardioStream.listen(cardioReceived.add);
        fakeSet.emitCardio(CardioData(
          heartRate: 72,
          metricsAvailable: true,
          hasArtifacts: false,
          timestamp: ts,
          source: SensorSource.neiry,
        ));
        await Future<void>.delayed(Duration.zero);
        expect(cardioReceived.length, 1);
        expect(cardioReceived[0].heartRate, 72);
        await cardioSub.cancel();

        // rrStream
        final rrReceived = <RrInterval>[];
        final rrSub = provider.rrStream.listen(rrReceived.add);
        fakeSet.emitRr(RrInterval(
          intervalMs: 830,
          timestamp: ts,
          isArtifact: false,
          source: SensorSource.neiry,
        ));
        await Future<void>.delayed(Duration.zero);
        expect(rrReceived.length, 1);
        expect(rrReceived[0].intervalMs, 830);
        await rrSub.cancel();

        // emotionsStream
        final emotionsReceived = <BciEmotionsData>[];
        final emotionsSub = provider.emotionsStream.listen(emotionsReceived.add);
        fakeSet.emitEmotions(BciEmotionsData(timestamp: ts, attention: 0.8));
        await Future<void>.delayed(Duration.zero);
        expect(emotionsReceived.length, 1);
        expect(emotionsReceived[0].attention, 0.8);
        await emotionsSub.cancel();

        // motionStream
        final motionReceived = <MotionData>[];
        final motionSub = provider.motionStream.listen(motionReceived.add);
        fakeSet.emitMotion(MotionData(
          accelerometer: (x: 0.1, y: 0.2, z: 9.8),
          gyroscope: (x: 0.0, y: 0.0, z: 0.0),
          timestamp: ts,
          source: SensorSource.neiry,
        ));
        await Future<void>.delayed(Duration.zero);
        expect(motionReceived.length, 1);
        expect(motionReceived[0].accelerometer.z, closeTo(9.8, 0.001));
        await motionSub.cancel();
      },
    );

    // ── Test 2: dispose path ──────────────────────────────────────────────────

    test(
      'disconnect() calls FakeClassifierSet.dispose() once',
      () async {
        await provider.connect('FAKE-001');
        await provider.disconnect();

        expect(fakeSet.disposeCallCount, 1,
            reason: 'classifier set must be disposed on disconnect()');
      },
    );

    test(
      'throwOnDispose set still lets teardown complete — no exception escapes',
      () async {
        fakeSet.throwOnDispose = true;

        await provider.connect('FAKE-001');

        // disconnect() must absorb the classifier dispose error and complete.
        await expectLater(provider.disconnect(), completes);

        // dispose() was still called (even though it threw).
        expect(fakeSet.disposeCallCount, 1);
      },
    );
  });

  // ── Default constructor smoke check ─────────────────────────────────────────

  group('NeiryBciProvider — default constructor', () {
    test(
      'constructs without arguments (production path untouched)',
      () {
        expect(() => NeiryBciProvider(), returnsNormally);
      },
    );
  });

  // ── T5 positive: non-Neiry FakeDevicePort no longer causes CastError ─────────

  group('NeiryBciProvider — T5 positive (FakeDevicePort now completes connect())', () {
    test(
      'connect() with FakeDevicePort completes successfully — '
      'no CastError from a NeiryDeviceAdapter downcast',
      () async {
        final fakeSet = FakeClassifierSet();
        final fakeDevice = FakeDevicePort(fakeSet);
        final fakeLocator = _ControlledLocatorPort(fakeDevice);
        final provider = NeiryBciProvider(locatorFactory: () => fakeLocator);

        // T5: buildClassifierSet() is called on the DevicePort directly — no cast.
        await expectLater(provider.connect('FAKE-001'), completes);

        expect(fakeDevice.buildClassifierSetCallCount, 1);
        expect(fakeDevice.disconnectCallCount, 0,
            reason: 'no cleanup needed — connect succeeded');

        provider.dispose();
      },
    );

    test(
      'when throwOnBuildClassifierSet is set, connect() fails and cleanup runs',
      () async {
        final fakeSet = FakeClassifierSet();
        final fakeDevice = FakeDevicePort(fakeSet)
          ..throwOnBuildClassifierSet = true;
        final fakeLocator = _ControlledLocatorPort(fakeDevice);
        final provider = NeiryBciProvider(locatorFactory: () => fakeLocator);

        await expectLater(
          provider.connect('FAKE-001'),
          throwsA(isA<StateError>()),
        );

        // Cleanup path ran.
        expect(fakeDevice.disconnectCallCount, 1);
        expect(fakeDevice.disposeCallCount, 1);

        provider.dispose();
      },
    );
  });
}
