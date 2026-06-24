// Direct unit tests for BciDeviceManager:
//   — _setState dedup logic
//   — forward connection path (scan → connect → impedance)
//   — calibration transitions and invalid-result routing
//   — connectedSerial derivation
//   — auto-reconnect policy on link drop
//   — reconnect scan termination and error handling
//   — startScan error and completion paths

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';

import 'package:mind/Bci/BciDeviceManager.dart';
import 'package:mind/Bci/BciDeviceRepository.dart';
import 'package:mind/Bci/IBciDeviceProvider.dart';
import 'package:mind/Bci/NfbCalibrationRepository.dart';
import 'package:mind/Bci/Models/BciCalibrationEvent.dart';
import 'package:mind/Bci/Models/BciChannelQuality.dart';
import 'package:mind/Bci/Models/BciConnectionState.dart';
import 'package:mind/Bci/Models/BciDeviceInfo.dart';
import 'package:mind/Bci/Models/BciEmotionsData.dart';
import 'package:mind/Bci/Models/BciLinkStatus.dart';
import 'package:mind/Bci/Models/BciNfbData.dart';
import 'package:mind/Bci/Models/BluetoothPermissionDeniedException.dart';
import 'package:mind/Bci/Models/NfbCalibrationData.dart';
import 'package:mind/Biometrics/IEegBandsSource.dart';
import 'package:mind/Biometrics/IEmotionsSource.dart';
import 'package:mind/Biometrics/IHeartRateSource.dart';
import 'package:mind/Biometrics/Models/CardioData.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class FakeIBciDeviceProvider implements IBciDeviceProvider {
  final _connectionStateController = StreamController<BciLinkStatus>.broadcast();
  final _calibrationController = StreamController<BciCalibrationEvent>.broadcast();
  final _signalQualityController = StreamController<List<BciChannelQuality>>.broadcast();
  final _batteryController = StreamController<int>.broadcast();

  final List<StreamController<List<BciDeviceInfo>>> _scanControllers = [];

  int connectCallCount = 0;
  int disconnectCallCount = 0;
  int startCalibrationCallCount = 0;
  int startQuickCalibrationCallCount = 0;

  Object? connectThrows;
  Object? startCalibrationThrows;
  Object? startQuickCalibrationThrows;
  Object? disconnectThrows;

  /// When non-null, connect() awaits this before proceeding.
  /// Allows tests to observe the BciConnecting phase in-flight.
  Completer<void>? connectGate;

  int get scanCallCount => _scanControllers.length;

  StreamController<List<BciDeviceInfo>> get latestScanController =>
      _scanControllers.last;

  @override
  Stream<List<BciDeviceInfo>> scan() {
    final controller = StreamController<List<BciDeviceInfo>>();
    _scanControllers.add(controller);
    return controller.stream;
  }

  @override
  Future<void> connect(String serial) async {
    connectCallCount++;
    await connectGate?.future;
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

  @override
  Stream<List<BciChannelQuality>> get signalQualityStream => _signalQualityController.stream;

  @override
  Stream<int> get batteryStream => _batteryController.stream;

  @override
  Stream<BciCalibrationEvent> get calibrationStream => _calibrationController.stream;

  void emitConnectionStatus(BciLinkStatus status) =>
      _connectionStateController.add(status);

  void emitCalibrationEvent(BciCalibrationEvent event) =>
      _calibrationController.add(event);

  @override
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

class FakeBciDeviceRepository implements BciDeviceRepository {
  List<String> knownSerials = [];

  int fetchKnownSerialsCallCount = 0;
  int registerDeviceCallCount = 0;

  Object? fetchKnownSerialsThrows;
  Object? registerDeviceThrows;

  @override
  List<String> cachedSerials() => List<String>.unmodifiable(knownSerials);

  @override
  Future<List<String>> fetchKnownSerials() async {
    fetchKnownSerialsCallCount++;
    if (fetchKnownSerialsThrows != null) throw fetchKnownSerialsThrows!;
    return List<String>.from(knownSerials);
  }

  @override
  Future<void> registerDevice(String serial) async {
    registerDeviceCallCount++;
    if (!knownSerials.contains(serial)) knownSerials.add(serial);
    if (registerDeviceThrows != null) throw registerDeviceThrows!;
  }

  @override
  Future<void> deleteDevice(String id) async {}
}

class FakeNfbCalibrationRepository implements NfbCalibrationRepository {
  final Map<String, List<NfbCalibrationData>> _historyMap = {};

  int recordCallCount = 0;
  int refreshFromServerCallCount = 0;

  Object? recordThrows;

  @override
  List<NfbCalibrationData> history(String serial) =>
      List<NfbCalibrationData>.unmodifiable(_historyMap[serial] ?? const []);

  @override
  NfbCalibrationData? latestValid(String serial) {
    for (final d in history(serial)) {
      if (d.isValid) return d;
    }
    return null;
  }

  @override
  Future<void> record(
    String serial,
    NfbCalibrationData data, {
    @visibleForTesting bool awaitApiSync = false,
  }) async {
    recordCallCount++;
    if (recordThrows != null) throw recordThrows!;
    _historyMap[serial] = [data, ...(_historyMap[serial] ?? [])];
  }

  @override
  Future<void> refreshFromServer(String serial) async {
    refreshFromServerCallCount++;
  }
}

class FakeHeartRateSource implements IHeartRateSource {
  @override
  Stream<CardioData> get cardioStream =>
      StreamController<CardioData>.broadcast().stream;
}

class FakeEegBandsSource implements IEegBandsSource {
  @override
  Stream<BciNfbData> get nfbStream =>
      StreamController<BciNfbData>.broadcast().stream;
}

class FakeEmotionsSource implements IEmotionsSource {
  @override
  Stream<BciEmotionsData> get emotionsStream =>
      StreamController<BciEmotionsData>.broadcast().stream;
}

// ── Builder helpers ────────────────────────────────────────────────────────────

NfbCalibrationData buildCalibrationData({required bool isValid}) {
  return NfbCalibrationData(
    calibratedAt: DateTime(2024, 1, 1),
    isValid: isValid,
    failReason: isValid ? 'none' : 'tooManyArtifacts',
    individualFrequency: 0,
    individualPeakFrequency: 0,
    individualPeakFrequencyPower: 0,
    individualPeakFrequencySuppression: 0,
    individualBandwidth: 0,
    individualNormalizedPower: 0,
    lowerFrequency: 0,
    upperFrequency: 0,
  );
}

BciDeviceInfo buildDeviceInfo(String serial) =>
    BciDeviceInfo(serial: serial, name: 'Headband-$serial');

// ── Test suite ────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BciDeviceManager', () {
    late FakeIBciDeviceProvider provider;
    late FakeBciDeviceRepository repository;
    late FakeNfbCalibrationRepository nfbRepo;
    late BciDeviceManager manager;
    late bool managerDisposed;

    setUp(() {
      provider = FakeIBciDeviceProvider();
      repository = FakeBciDeviceRepository();
      nfbRepo = FakeNfbCalibrationRepository();
      manager = BciDeviceManager(
        provider: provider,
        cardioSource: FakeHeartRateSource(),
        eegBandsSource: FakeEegBandsSource(),
        emotionsSource: FakeEmotionsSource(),
        repository: repository,
        nfbCalibrationRepository: nfbRepo,
      );
      managerDisposed = false;
    });

    tearDown(() async {
      final gate = provider.connectGate;
      if (gate != null && !gate.isCompleted) {
        gate.complete();
      }
      if (!managerDisposed) {
        await manager.dispose();
      }
      provider.dispose();
    });

    // Drive the manager to BciImpedance state.
    Future<void> driveToImpedance([String serial = 'TEST-001']) =>
        manager.connectDevice(serial);

    // Drive the manager to BciCalibrating state.
    Future<void> driveToCalibrating([String serial = 'TEST-001']) async {
      await driveToImpedance(serial);
      await manager.startCalibration();
    }

    // Trigger an unexpected disconnect and pump twice so _attemptReconnect
    // runs and sets up its scan subscription.
    Future<void> triggerLinkDrop() async {
      provider.emitConnectionStatus(BciLinkStatus.down);
      await Future<void>.delayed(Duration.zero); // pump 1: listener fires
      await Future<void>.delayed(Duration.zero); // pump 2: _attemptReconnect runs
    }

    // ── Phase 1: _setState dedup ─────────────────────────────────────────────

    group('_setState dedup — Task 1', () {
      test('should not emit when transitioning to the same non-active state',
          () async {
        // Manager starts in BciIdle. disconnect() calls _setState(BciIdle()) which
        // is deduped (same non-Active type → no emission).
        final emitted = <BciConnectionState>[];
        final sub = manager.stateStream.listen(emitted.add);

        await manager.disconnect();

        await Future<void>.delayed(Duration.zero);
        expect(emitted, isEmpty);

        await sub.cancel();
      });

      test(
          'should not emit when transitioning to the same active type with the same serial',
          () async {
        provider.connectGate = Completer<void>();

        final emitted = <BciConnectionState>[];
        final sub = manager.stateStream.listen(emitted.add);

        // First call emits BciConnecting('A').
        unawaited(manager.connectDevice('A'));
        await Future<void>.delayed(Duration.zero);
        final countAfterFirst = emitted.length;
        expect(countAfterFirst, 1);

        // Second call with same serial while already BciConnecting('A') — deduped.
        unawaited(manager.connectDevice('A'));
        await Future<void>.delayed(Duration.zero);
        expect(emitted.length, countAfterFirst);

        await sub.cancel();
      });

      test(
          'should emit when transitioning between different active types with the same serial',
          () async {
        final emitted = <BciConnectionState>[];
        final sub = manager.stateStream.listen(emitted.add);

        await manager.connectDevice('A');
        await Future<void>.delayed(Duration.zero); // let stream events deliver

        // BciConnecting('A') and BciImpedance('A') are different types — both emit.
        expect(emitted.length, 2);
        expect(emitted[0], isA<BciConnecting>());
        expect((emitted[0] as BciConnecting).serial, 'A');
        expect(emitted[1], isA<BciImpedance>());
        expect((emitted[1] as BciImpedance).serial, 'A');

        await sub.cancel();
      });

      test(
          'should emit when transitioning to the same active type with a different serial',
          () async {
        provider.connectGate = Completer<void>();

        final emitted = <BciConnectionState>[];
        final sub = manager.stateStream.listen(emitted.add);

        unawaited(manager.connectDevice('A'));
        await Future<void>.delayed(Duration.zero);
        expect(emitted.length, 1);

        // Different serial — not deduped.
        unawaited(manager.connectDevice('B'));
        await Future<void>.delayed(Duration.zero);
        expect(emitted.length, 2);
        expect((emitted[0] as BciConnecting).serial, 'A');
        expect((emitted[1] as BciConnecting).serial, 'B');

        await sub.cancel();
      });

      test('should not emit any state after dispose', () async {
        int doneCount = 0;
        final emitted = <BciConnectionState>[];
        manager.stateStream.listen(emitted.add, onDone: () => doneCount++);

        await manager.dispose();
        managerDisposed = true;

        await Future<void>.delayed(Duration.zero);
        expect(doneCount, 1);
        expect(emitted, isEmpty);

        // Post-dispose events have no effect.
        provider.emitConnectionStatus(BciLinkStatus.down);
        await Future<void>.delayed(Duration.zero);
        expect(emitted, isEmpty);
      });
    });

    // ── Phase 2: Scan and connect lifecycle ──────────────────────────────────

    group('scan and connect lifecycle — Task 2', () {
      test('should emit BciScanning when startScan is called from idle',
          () async {
        final emitted = <BciConnectionState>[];
        final sub = manager.stateStream.listen(emitted.add);

        await manager.startScan();

        expect(manager.state, isA<BciScanning>());
        expect(emitted, [isA<BciScanning>()]);

        await sub.cancel();
      });

      test('should re-emit BciScanning on consecutive startScan calls',
          () async {
        final emitted = <BciConnectionState>[];
        final sub = manager.stateStream.listen(emitted.add);

        await manager.startScan();
        await manager.startScan();

        // Both calls bypass dedup and emit BciScanning.
        expect(emitted.length, 2);
        expect(emitted[0], isA<BciScanning>());
        expect(emitted[1], isA<BciScanning>());

        await sub.cancel();
      });

      test(
          'should emit discovered devices on discoveredDevicesStream when scan yields results',
          () async {
        final discovered = <List<BciDeviceInfo>>[];
        final sub = manager.discoveredDevicesStream.listen(discovered.add);

        await manager.startScan();

        final devices = [buildDeviceInfo('DEV-1'), buildDeviceInfo('DEV-2')];
        provider.latestScanController.add(devices);
        await Future<void>.delayed(Duration.zero);

        expect(discovered.length, 1);
        expect(discovered[0], devices);

        await sub.cancel();
      });

      test('should auto-connect when scan discovers a cached serial while scanning',
          () async {
        repository.knownSerials = ['TEST-001'];

        await manager.startScan();

        provider.latestScanController
            .add([buildDeviceInfo('TEST-001'), buildDeviceInfo('OTHER')]);
        await Future<void>.delayed(Duration.zero); // listener starts, cancel+connect
        await Future<void>.delayed(Duration.zero); // connectDevice's connect resolves
        await Future<void>.delayed(Duration.zero); // BciImpedance set

        expect(manager.state, isA<BciImpedance>());
        expect((manager.state as BciImpedance).serial, 'TEST-001');
      });

      test(
          'should emit BciConnecting then BciImpedance when connectDevice succeeds',
          () async {
        final emitted = <BciConnectionState>[];
        final sub = manager.stateStream.listen(emitted.add);

        await manager.connectDevice('TEST-001');
        await Future<void>.delayed(Duration.zero); // let stream events deliver

        expect(emitted[0], isA<BciConnecting>());
        expect(emitted[1], isA<BciImpedance>());

        await sub.cancel();
      });

      test('should call registerDevice with the serial on successful connect',
          () async {
        await manager.connectDevice('TEST-001');
        await Future<void>.delayed(Duration.zero); // let unawaited registerDevice run

        expect(repository.registerDeviceCallCount, 1);
      });

      test('should emit BciIdle when provider.connect throws', () async {
        provider.connectThrows = Exception('connection refused');

        final emitted = <BciConnectionState>[];
        final sub = manager.stateStream.listen(emitted.add);

        await manager.connectDevice('TEST-001');
        await Future<void>.delayed(Duration.zero); // let catch block and stream events settle

        expect(manager.state, isA<BciIdle>());
        expect(manager.connectedSerial, isNull);
        expect(emitted.last, isA<BciIdle>());

        await sub.cancel();
      });
    });

    // ── Phase 3: startCalibration / startQuickCalibration ────────────────────

    group('startCalibration / startQuickCalibration entry — Task 3', () {
      test(
          'should emit BciCalibrating with totalStages 4 on startCalibration from impedance',
          () async {
        await driveToImpedance();

        final emitted = <BciConnectionState>[];
        final sub = manager.stateStream.listen(emitted.add);

        await manager.startCalibration();

        expect(emitted.last, isA<BciCalibrating>());
        expect((emitted.last as BciCalibrating).totalStages, 4);
        expect((emitted.last as BciCalibrating).serial, 'TEST-001');

        await sub.cancel();
      });

      test(
          'should emit BciCalibrating with totalStages 1 on startQuickCalibration from impedance',
          () async {
        await driveToImpedance();

        final emitted = <BciConnectionState>[];
        final sub = manager.stateStream.listen(emitted.add);

        await manager.startQuickCalibration();

        expect(emitted.last, isA<BciCalibrating>());
        expect((emitted.last as BciCalibrating).totalStages, 1);

        await sub.cancel();
      });

      test(
          'should do nothing and not call provider when startCalibration is called outside impedance',
          () async {
        // State is BciIdle (not BciImpedance).
        await manager.startCalibration();

        expect(manager.state, isA<BciIdle>());
        expect(provider.startCalibrationCallCount, 0);
      });

      test(
          'should do nothing and not call provider when startQuickCalibration is called outside impedance',
          () async {
        await manager.startScan();
        await manager.startQuickCalibration();

        expect(manager.state, isA<BciScanning>());
        expect(provider.startQuickCalibrationCallCount, 0);
      });

      test('should route back to BciImpedance when provider.startCalibration throws',
          () async {
        provider.startCalibrationThrows = StateError('hardware error');
        await driveToImpedance();

        await manager.startCalibration();

        expect(manager.state, isA<BciImpedance>());
      });

      test(
          'should route back to BciImpedance when provider.startQuickCalibration throws',
          () async {
        provider.startQuickCalibrationThrows = Exception('network error');
        await driveToImpedance();

        await manager.startQuickCalibration();

        expect(manager.state, isA<BciImpedance>());
      });
    });

    // ── Phase 4: Calibration event routing ───────────────────────────────────

    group('calibration event routing — Task 4', () {
      test(
          'should emit BciReady when BciCalibrationCompleted arrives with isValid true',
          () async {
        await driveToCalibrating();

        provider.emitCalibrationEvent(
            BciCalibrationCompleted(buildCalibrationData(isValid: true)));
        await Future<void>.delayed(Duration.zero);

        expect(manager.state, isA<BciReady>());
        expect((manager.state as BciReady).serial, 'TEST-001');
      });

      test(
          'should call nfbCalibrationRepository.record with the captured serial on valid completion',
          () async {
        await driveToCalibrating();

        provider.emitCalibrationEvent(
            BciCalibrationCompleted(buildCalibrationData(isValid: true)));
        await Future<void>.delayed(Duration.zero);

        expect(nfbRepo.recordCallCount, 1);
      });

      test(
          'should emit BciImpedance not BciReady when BciCalibrationCompleted arrives with isValid false',
          () async {
        await driveToCalibrating();

        provider.emitCalibrationEvent(
            BciCalibrationCompleted(buildCalibrationData(isValid: false)));
        await Future<void>.delayed(Duration.zero);

        expect(manager.state, isA<BciImpedance>());
        expect(manager.state, isNot(isA<BciReady>()));
      });

      test('should not call record when completion is invalid', () async {
        await driveToCalibrating();

        provider.emitCalibrationEvent(
            BciCalibrationCompleted(buildCalibrationData(isValid: false)));
        await Future<void>.delayed(Duration.zero);

        expect(nfbRepo.recordCallCount, 0);
      });

      test('should emit BciImpedance when BciCalibrationFailed arrives',
          () async {
        await driveToCalibrating();

        provider.emitCalibrationEvent(
            const BciCalibrationFailed('device_error'));
        await Future<void>.delayed(Duration.zero);

        expect(manager.state, isA<BciImpedance>());
      });

      test('should not change state on BciCalibrationStageFinished', () async {
        await driveToCalibrating();

        final stateBefore = manager.state;

        provider.emitCalibrationEvent(const BciCalibrationStageFinished(1));
        await Future<void>.delayed(Duration.zero);

        expect(manager.state.runtimeType, stateBefore.runtimeType);
        expect(manager.state, isA<BciCalibrating>());
      });

      test('should ignore calibration completion when not in BciCalibrating',
          () async {
        await driveToImpedance();
        expect(manager.state, isA<BciImpedance>());

        provider.emitCalibrationEvent(
            BciCalibrationCompleted(buildCalibrationData(isValid: true)));
        await Future<void>.delayed(Duration.zero);

        // Guard at line 81 fires — state stays BciImpedance.
        expect(manager.state, isA<BciImpedance>());
        expect(nfbRepo.recordCallCount, 0);
      });

      test('should still emit BciReady when record throws', () async {
        nfbRepo.recordThrows = Exception('storage failure');
        await driveToCalibrating();

        provider.emitCalibrationEvent(
            BciCalibrationCompleted(buildCalibrationData(isValid: true)));
        await Future<void>.delayed(Duration.zero); // listener runs
        await Future<void>.delayed(Duration.zero); // catchError runs

        // record threw but _setState(BciReady) was called immediately after
        // the unawaited record future was scheduled.
        expect(manager.state, isA<BciReady>());
      });
    });

    // ── Phase 5: connectedSerial and connecting state ────────────────────────

    group('connectedSerial and connecting state — Task 5', () {
      test('should expose connectedSerial as null while idle or scanning',
          () async {
        expect(manager.connectedSerial, isNull);

        await manager.startScan();
        expect(manager.connectedSerial, isNull);
      });

      test(
          'should report state as BciConnecting between setState and provider.connect completing',
          () async {
        provider.connectGate = Completer<void>();

        unawaited(manager.connectDevice('A'));
        await Future<void>.delayed(Duration.zero);

        expect(manager.state, isA<BciConnecting>());
        expect(manager.connectedSerial, isNull); // not set until connect() returns

        provider.connectGate!.complete();
        await Future<void>.delayed(Duration.zero);

        expect(manager.state, isA<BciImpedance>());
      });

      test('should set connectedSerial to the target serial after a successful connect',
          () async {
        await manager.connectDevice('SERIAL-A');

        expect(manager.connectedSerial, 'SERIAL-A');
      });

      test(
          'should preserve connectedSerial across impedance, calibrating, and ready phases',
          () async {
        await driveToImpedance('SERIAL-A');
        expect(manager.connectedSerial, 'SERIAL-A');

        await manager.startCalibration();
        expect(manager.connectedSerial, 'SERIAL-A');

        provider.emitCalibrationEvent(
            BciCalibrationCompleted(buildCalibrationData(isValid: true)));
        await Future<void>.delayed(Duration.zero);
        expect(manager.state, isA<BciReady>());
        expect(manager.connectedSerial, 'SERIAL-A');
      });

      test('should clear connectedSerial and set suppress flag on disconnect',
          () async {
        await driveToImpedance();
        expect(manager.connectedSerial, 'TEST-001');

        await manager.disconnect();

        expect(manager.connectedSerial, isNull);
        expect(manager.state, isA<BciIdle>());
      });
    });

    // ── Phase 6: Auto-reconnect triggers and guards ──────────────────────────

    group('reconnect trigger and guards — Task 6', () {
      test(
          'should emit BciIdle then call scan again when down arrives while in an active phase',
          () async {
        await driveToImpedance();

        final emitted = <BciConnectionState>[];
        final sub = manager.stateStream.listen(emitted.add);

        await triggerLinkDrop();

        // BciIdle from connection listener + BciScanning from _attemptReconnect
        expect(emitted.length, greaterThanOrEqualTo(2));
        expect(emitted[0], isA<BciIdle>());
        expect(emitted[1], isA<BciScanning>());
        expect(provider.scanCallCount, 1);

        await sub.cancel();
      });

      test(
          'should reconnect by calling connectDevice when the scan rediscovers the remembered serial',
          () async {
        await driveToImpedance();
        final connectCountAfterSetup = provider.connectCallCount;

        await triggerLinkDrop();

        // _attemptReconnect has started its scan — emit the remembered device.
        provider.latestScanController.add([buildDeviceInfo('TEST-001')]);
        await Future<void>.delayed(Duration.zero); // listener starts
        await Future<void>.delayed(Duration.zero); // connectDevice runs
        await Future<void>.delayed(Duration.zero); // BciImpedance set

        expect(manager.state, isA<BciImpedance>());
        expect(provider.connectCallCount, connectCountAfterSetup + 1);
      });

      test('should not attempt reconnect after an explicit disconnect', () async {
        await driveToImpedance();
        await manager.disconnect(); // sets _suppressAutoReconnect = true, state = BciIdle

        provider.emitConnectionStatus(BciLinkStatus.down);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // State is already BciIdle (not BciActive) → line-68 guard also fires.
        // Either way: no reconnect scan.
        expect(manager.state, isA<BciIdle>());
        expect(provider.scanCallCount, 0);
      });

      test(
          'should not attempt reconnect when connectedSerial is null while BciActive',
          () async {
        // BciConnecting is BciActive, but _connectedSerial is null until
        // connect() returns (set at line 221).
        provider.connectGate = Completer<void>();

        unawaited(manager.connectDevice('A'));
        await Future<void>.delayed(Duration.zero);

        expect(manager.state, isA<BciConnecting>());
        expect(manager.connectedSerial, isNull);

        final scansBefore = provider.scanCallCount;

        provider.emitConnectionStatus(BciLinkStatus.down);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Line-71 guard: connectedSerial is null → no reconnect.
        expect(provider.scanCallCount, scansBefore);
      });

      test('should ignore down when not in an active phase', () async {
        await manager.startScan(); // state = BciScanning (not BciActive)

        provider.emitConnectionStatus(BciLinkStatus.down);
        await Future<void>.delayed(Duration.zero);

        // Line-68 guard: BciScanning is not BciActive → listener body skipped.
        expect(manager.state, isA<BciScanning>());
        expect(provider.scanCallCount, 1); // only from startScan, no reconnect
      });

      test('should ignore BciLinkStatus.up entirely', () async {
        await driveToImpedance();

        provider.emitConnectionStatus(BciLinkStatus.up);
        await Future<void>.delayed(Duration.zero);

        // .up does not match the condition at line 68 — no state change.
        expect(manager.state, isA<BciImpedance>());
      });

      test(
          'should re-enable reconnect (clear suppress flag) when startScan is called',
          () async {
        await driveToImpedance();
        await manager.disconnect(); // suppress = true

        // startScan clears _suppressAutoReconnect (line 156).
        await manager.startScan();

        // Now re-connect to get back to an active state.
        provider.latestScanController.add([buildDeviceInfo('TEST-001')]);
        repository.knownSerials = ['TEST-001'];

        // Drive to impedance via a new connectDevice call.
        await manager.connectDevice('TEST-001');
        expect(manager.state, isA<BciImpedance>());

        final scansBefore = provider.scanCallCount;

        // Unexpected drop — reconnect is now re-enabled.
        await triggerLinkDrop();

        // _attemptReconnect should have fired a new scan.
        expect(provider.scanCallCount, greaterThan(scansBefore));
      });
    });

    // ── Phase 7: Reconnect scan termination and errors ───────────────────────

    group('reconnect scan termination and error handling — Task 7', () {
      test(
          'should emit BciIdle when the reconnect scan completes without finding the device',
          () async {
        await driveToImpedance();
        await triggerLinkDrop();

        // Reconnect scan completes without emitting the remembered device.
        provider.latestScanController.close();
        await Future<void>.delayed(Duration.zero);

        // onDone: _state is BciScanning && _connectedSerial != null → BciIdle.
        expect(manager.state, isA<BciIdle>());
      });

      test(
          'should emit BciIdle when the reconnect scan errors with a non-permission exception',
          () async {
        await driveToImpedance();
        await triggerLinkDrop();

        provider.latestScanController.addError(Exception('ble adapter unavailable'));
        await Future<void>.delayed(Duration.zero);

        expect(manager.state, isA<BciIdle>());
      });

      test(
          'should emit BciPermissionDenied when the reconnect scan throws BluetoothPermissionDeniedException',
          () async {
        await driveToImpedance();
        await triggerLinkDrop();

        provider.latestScanController
            .addError(const BluetoothPermissionDeniedException());
        await Future<void>.delayed(Duration.zero);

        expect(manager.state, isA<BciPermissionDenied>());
      });
    });

    // ── Phase 8: startScan error and completion paths ────────────────────────

    group('startScan error handling — Task 8', () {
      test(
          'should emit BciPermissionDenied when the scan throws BluetoothPermissionDeniedException',
          () async {
        await manager.startScan();

        provider.latestScanController
            .addError(const BluetoothPermissionDeniedException());
        await Future<void>.delayed(Duration.zero);

        expect(manager.state, isA<BciPermissionDenied>());
      });

      test('should emit BciIdle when the scan throws a non-permission exception',
          () async {
        await manager.startScan();

        provider.latestScanController.addError(Exception('adapter off'));
        await Future<void>.delayed(Duration.zero);

        expect(manager.state, isA<BciIdle>());
      });

      test(
          'should emit BciIdle when the scan stream completes while still scanning',
          () async {
        await manager.startScan();
        expect(manager.state, isA<BciScanning>());

        provider.latestScanController.close();
        await Future<void>.delayed(Duration.zero);

        // onDone: _state is BciScanning → BciIdle.
        expect(manager.state, isA<BciIdle>());
      });
    });
  });
}
