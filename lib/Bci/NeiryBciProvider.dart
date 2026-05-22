import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' show min;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:neiry_kit/neiry_kit.dart';
import 'package:permission_handler/permission_handler.dart';

import 'IBciDeviceProvider.dart';
import 'Models/BciCalibrationEvent.dart';
import 'Models/BciCardioData.dart';
import 'Models/BciChannelQuality.dart';
import 'Models/BciConnectionState.dart';
import 'Models/BciDeviceInfo.dart';
import 'Models/BciEmotionsData.dart';
import 'Models/BciNfbData.dart';
import 'Models/BluetoothPermissionDeniedException.dart';
import '../Logger.dart';

/// Adapter that bridges `neiry_kit` to [IBciDeviceProvider].
///
/// This is the **only** file in `mind_mobile` that may import `neiry_kit`.
/// All consumers must depend on [IBciDeviceProvider], never on this class.
class NeiryBciProvider implements IBciDeviceProvider {
  final DeviceLocator _locator = DeviceLocator();
  Device? _device;

  NfbClassifier? _nfbClassifier;
  CardioClassifier? _cardioClassifier;
  EmotionsClassifier? _emotionsClassifier;

  final _connectionStateController =
      StreamController<BciConnectionState>.broadcast();
  final _signalQualityController =
      StreamController<List<BciChannelQuality>>.broadcast();
  final _batteryController = StreamController<int>.broadcast();
  final _calibrationController =
      StreamController<BciCalibrationEvent>.broadcast();
  final _nfbController = StreamController<BciNfbData>.broadcast();
  final _cardioController = StreamController<BciCardioData>.broadcast();
  final _emotionsController = StreamController<BciEmotionsData>.broadcast();

  StreamSubscription<NeiryConnectionState>? _connectionSub;
  StreamSubscription<ResistanceData>? _resistanceSub;
  StreamSubscription<int>? _batterySub;
  StreamSubscription<CalibrationEvent>? _calibrationSub;
  StreamSubscription<NfbUserState>? _nfbSub;
  StreamSubscription<String>? _nfbErrorSub;
  StreamSubscription<CardioData>? _cardioSub;
  StreamSubscription<EmotionsStates>? _emotionsSub;
  StreamSubscription<String>? _emotionsErrorSub;

  // ── Stream getters ──────────────────────────────────────────────────────────

  @override
  Stream<BciConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  @override
  Stream<List<BciChannelQuality>> get signalQualityStream =>
      _signalQualityController.stream;

  @override
  Stream<int> get batteryStream => _batteryController.stream;

  @override
  Stream<BciCalibrationEvent> get calibrationStream =>
      _calibrationController.stream;

  @override
  Stream<BciNfbData> get nfbStream => _nfbController.stream;

  @override
  Stream<BciCardioData> get cardioStream => _cardioController.stream;

  @override
  Stream<BciEmotionsData> get emotionsStream => _emotionsController.stream;

  // ── scan() ──────────────────────────────────────────────────────────────────

  @override
  Stream<List<BciDeviceInfo>> scan() async* {
    if (Platform.isIOS) {
      final status = await Permission.bluetooth.status;
      if (status.isPermanentlyDenied || status.isRestricted) {
        logPrint('NeiryBciProvider: bluetooth permission permanently denied (iOS)');
        throw const BluetoothPermissionDeniedException();
      }
      // All other statuses (including denied / notDetermined) fall through so
      // CoreBluetooth presents its native prompt when requestDevices() runs.
    } else if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      final permissions = [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        if (sdkInt < 31) Permission.locationWhenInUse,
      ];

      final statuses = await permissions.request();

      final anyPermanentlyDenied =
          permissions.any((p) => statuses[p]?.isPermanentlyDenied == true);
      if (anyPermanentlyDenied) {
        logPrint('NeiryBciProvider: bluetooth permission permanently denied (Android)');
        throw const BluetoothPermissionDeniedException();
      }

      final allGranted = permissions.every((p) => statuses[p]?.isGranted == true);
      if (!allGranted) {
        // Normal denial — return silently; Android will re-prompt next time.
        return;
      }
    }

    yield* _locator
        .requestDevices(type: NeiryDeviceType.headband, searchTime: 5)
        .map((list) =>
            list.map((d) => BciDeviceInfo(serial: d.serial, name: d.name)).toList());
  }

  // ── connect() ───────────────────────────────────────────────────────────────

  @override
  Future<void> connect(String serial) async {
    if (_device != null) {
      throw StateError(
        'NeiryBciProvider: connect() called while already connected. '
        'Call disconnect() first.',
      );
    }
    _device = await _locator.createDevice(serial);
    try {
      await _device!.connect();
      await _device!.start();
      _nfbClassifier = NfbClassifier(_device!);
      _cardioClassifier = CardioClassifier(_device!);
      _emotionsClassifier = EmotionsClassifier(_device!);
    } catch (e) {
      try {
        await _nfbClassifier?.dispose();
      } catch (_) {}
      _nfbClassifier = null;
      try {
        await _cardioClassifier?.dispose();
      } catch (_) {}
      _cardioClassifier = null;
      try {
        await _emotionsClassifier?.dispose();
      } catch (_) {}
      _emotionsClassifier = null;
      try {
        await _device?.disconnect();
        await _device?.dispose();
      } catch (_) {}
      _device = null;
      rethrow;
    }
    _subscribeDeviceStreams();
  }

  void _subscribeDeviceStreams() {
    _connectionSub = _device!.connectionStateStream.listen(
      _onNeiryConnectionState,
      onError: (Object e) =>
          logPrint('NeiryBciProvider: connectionStateStream error: $e'),
    );
    _resistanceSub = _device!.resistanceStream.listen(
      _onResistance,
      onError: (Object e) =>
          logPrint('NeiryBciProvider: resistanceStream error: $e'),
    );
    _batterySub = _device!.batteryStream.listen(
      _batteryController.add,
      onError: (Object e) =>
          logPrint('NeiryBciProvider: batteryStream error: $e'),
    );
    // Classifiers are guaranteed non-null here: connect()'s try block
    // instantiates them before reaching this method.
    _nfbSub = _nfbClassifier!.stateStream.listen(
      _onNfbState,
      onError: (Object e) =>
          logPrint('NeiryBciProvider: nfb stateStream error: $e'),
    );
    _nfbErrorSub = _nfbClassifier!.errorStream.listen(
      (e) => logPrint('NeiryBciProvider: nfb error: $e'),
      onError: (Object e) =>
          logPrint('NeiryBciProvider: nfb errorStream error: $e'),
    );
    _cardioSub = _cardioClassifier!.stateStream.listen(
      _onCardioState,
      onError: (Object e) =>
          logPrint('NeiryBciProvider: cardio stateStream error: $e'),
    );
    _emotionsSub = _emotionsClassifier!.stateStream.listen(
      _onEmotionsState,
      onError: (Object e) =>
          logPrint('NeiryBciProvider: emotions stateStream error: $e'),
    );
    _emotionsErrorSub = _emotionsClassifier!.errorStream.listen(
      (e) => logPrint('NeiryBciProvider: emotions error: $e'),
      onError: (Object e) =>
          logPrint('NeiryBciProvider: emotions errorStream error: $e'),
    );
  }

  // ── NeiryConnectionState → BciConnectionState ───────────────────────────────

  void _onNeiryConnectionState(NeiryConnectionState s) {
    switch (s) {
      case NeiryConnectionState.connected:
        _connectionStateController.add(BciConnectionState.connecting);
      case NeiryConnectionState.disconnected:
        _connectionStateController.add(BciConnectionState.disconnected);
      case NeiryConnectionState.unsupportedConnection:
        logPrint('NeiryBciProvider: unsupported connection');
        _connectionStateController.add(BciConnectionState.disconnected);
    }
  }

  // ── ResistanceData → List<BciChannelQuality> ────────────────────────────────

  void _onResistance(ResistanceData r) {
    if (r.channelNames.length != r.values.length ||
        r.channelNames.length != r.channelCount) {
      logPrint(
        'NeiryBciProvider: channel count mismatch: '
        'names=${r.channelNames.length}, values=${r.values.length}, '
        'channelCount=${r.channelCount}',
      );
    }
    final count =
        min(min(r.channelNames.length, r.values.length), r.channelCount);
    final qualities = <BciChannelQuality>[];
    for (var i = 0; i < count; i++) {
      final name = r.channelNames[i];
      final value = r.values[i];
      final BciSignalLevel level;
      if (!value.isFinite || value > 200) {
        level = BciSignalLevel.red;
      } else if (value > 50) {
        level = BciSignalLevel.yellow;
      } else {
        level = BciSignalLevel.green;
      }
      qualities.add(BciChannelQuality(
        channelName: name,
        impedanceOhm: value,
        level: level,
      ));
    }
    _signalQualityController.add(qualities);
  }

  // ── NfbUserState → BciNfbData ───────────────────────────────────────────────

  void _onNfbState(NfbUserState s) {
    _nfbController.add(BciNfbData(
      delta: s.delta,
      theta: s.theta,
      alpha: s.alpha,
      smr: s.smr,
      beta: s.beta,
    ));
  }

  // ── CardioData → BciCardioData ──────────────────────────────────────────────

  void _onCardioState(CardioData c) {
    _cardioController.add(BciCardioData(
      heartRate: c.heartRate,
      metricsAvailable: c.metricsAvailable,
      hasArtifacts: c.hasArtifacts,
    ));
  }

  // ── EmotionsStates → BciEmotionsData ────────────────────────────────────────

  void _onEmotionsState(EmotionsStates e) {
    _emotionsController.add(BciEmotionsData(
      attention: e.attention,
      relaxation: e.relaxation,
      cognitiveLoad: e.cognitiveLoad,
      cognitiveControl: e.cognitiveControl,
      selfControl: e.selfControl,
    ));
  }

  // ── startCalibration() ──────────────────────────────────────────────────────

  @override
  Future<void> startCalibration() async {
    _calibrationSub?.cancel();
    _calibrationSub = NfbCalibrator.calibrateIndividual().listen(
      (event) {
        switch (event) {
          case CalibrationStageFinished(:final stage):
            _calibrationController.add(
              BciCalibrationStageFinished(stage.index + 1),
            );
          case CalibrationCompleted():
            _calibrationController.add(const BciCalibrationCompleted());
        }
      },
      onError: (Object e) {
        logPrint('NeiryBciProvider: calibration error: $e');
        _calibrationController.add(BciCalibrationFailed(e.toString()));
      },
    );
  }

  // ── disconnect() ────────────────────────────────────────────────────────────

  Future<void> _cancelDeviceSubscriptions() async {
    await _connectionSub?.cancel();
    _connectionSub = null;
    await _resistanceSub?.cancel();
    _resistanceSub = null;
    await _batterySub?.cancel();
    _batterySub = null;
    await _nfbSub?.cancel();
    _nfbSub = null;
    await _nfbErrorSub?.cancel();
    _nfbErrorSub = null;
    await _cardioSub?.cancel();
    _cardioSub = null;
    await _emotionsSub?.cancel();
    _emotionsSub = null;
    await _emotionsErrorSub?.cancel();
    _emotionsErrorSub = null;

    try {
      await _nfbClassifier?.dispose();
    } catch (e) {
      logPrint('NeiryBciProvider: nfb dispose error: $e');
    }
    _nfbClassifier = null;
    try {
      await _cardioClassifier?.dispose();
    } catch (e) {
      logPrint('NeiryBciProvider: cardio dispose error: $e');
    }
    _cardioClassifier = null;
    try {
      await _emotionsClassifier?.dispose();
    } catch (e) {
      logPrint('NeiryBciProvider: emotions dispose error: $e');
    }
    _emotionsClassifier = null;
  }

  @override
  Future<void> disconnect() async {
    await _cancelDeviceSubscriptions();
    try {
      await _device?.disconnect();
      await _device?.dispose();
    } catch (e) {
      logPrint('NeiryBciProvider: disconnect error: $e');
    }
    _device = null;
    // Emit explicitly — _connectionSub is already cancelled so the native
    // disconnected event would be missed without this.
    _connectionStateController.add(BciConnectionState.disconnected);
  }

  // ── dispose() ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    // Interface requires void; native teardown continues in the background.
    unawaited(_doDispose());
  }

  Future<void> _doDispose() async {
    await _cancelDeviceSubscriptions();
    await _calibrationSub?.cancel();
    _calibrationSub = null;
    try {
      await _device?.disconnect();
      await _device?.dispose();
    } catch (e) {
      logPrint('NeiryBciProvider: dispose error: $e');
    }
    _device = null;
    _connectionStateController.close();
    _signalQualityController.close();
    _batteryController.close();
    _calibrationController.close();
    _nfbController.close();
    _cardioController.close();
    _emotionsController.close();
  }
}
