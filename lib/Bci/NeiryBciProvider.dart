import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' show min;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:neiry_kit/neiry_kit.dart' as neiry;
import 'package:permission_handler/permission_handler.dart';

import 'package:mind/Biometrics/IHeartRateSource.dart';
import 'package:mind/Biometrics/IRrIntervalSource.dart';
import 'package:mind/Biometrics/IEegBandsSource.dart';
import 'package:mind/Biometrics/IEmotionsSource.dart';
import 'package:mind/Biometrics/IMotionSource.dart';
import 'package:mind/Biometrics/Models/CardioData.dart';
import 'package:mind/Biometrics/Models/RrInterval.dart';
import 'package:mind/Biometrics/Models/MotionData.dart';
import 'package:mind/Biometrics/Models/SensorSource.dart';

import 'IBciDeviceProvider.dart';
import 'Models/BciCalibrationEvent.dart';
import 'Models/BciChannelQuality.dart';
import 'Models/BciConnectionState.dart';
import 'Models/BciDeviceInfo.dart';
import 'Models/BciEmotionsData.dart';
import 'Models/BciNfbData.dart';
import 'Models/BluetoothPermissionDeniedException.dart';
import 'Models/NfbCalibrationData.dart';
import '../Logger.dart';

/// Adapter that bridges `neiry_kit` to [IBciDeviceProvider].
///
/// This is the **only** file in `mind_mobile` that may import `neiry_kit`.
/// All consumers must depend on [IBciDeviceProvider], never on this class.
class NeiryBciProvider implements IBciDeviceProvider, IHeartRateSource, IRrIntervalSource, IEegBandsSource, IEmotionsSource, IMotionSource {
  final _locator = neiry.DeviceLocator();
  neiry.Device? _device;

  neiry.NfbClassifier? _nfbClassifier;
  neiry.CardioClassifier? _cardioClassifier;
  neiry.EmotionsClassifier? _emotionsClassifier;
  neiry.MEMSClassifier? _memsClassifier;

  final _connectionStateController =
      StreamController<BciConnectionState>.broadcast();
  final _signalQualityController =
      StreamController<List<BciChannelQuality>>.broadcast();
  final _batteryController = StreamController<int>.broadcast();
  final _calibrationController =
      StreamController<BciCalibrationEvent>.broadcast();
  final _nfbController = StreamController<BciNfbData>.broadcast();
  final _cardioController = StreamController<CardioData>.broadcast();
  final _rrController = StreamController<RrInterval>.broadcast();
  final _emotionsController = StreamController<BciEmotionsData>.broadcast();
  final _motionController = StreamController<MotionData>.broadcast();

  StreamSubscription<neiry.NeiryConnectionState>? _connectionSub;
  StreamSubscription<neiry.ResistanceData>? _resistanceSub;
  StreamSubscription<int>? _batterySub;
  StreamSubscription<neiry.CalibrationEvent>? _calibrationSub;
  StreamSubscription<neiry.NfbUserState>? _nfbSub;
  StreamSubscription<String>? _nfbErrorSub;
  StreamSubscription<neiry.CardioData>? _cardioSub;
  StreamSubscription<neiry.RRInterval>? _rrSub;
  StreamSubscription<neiry.EmotionsStates>? _emotionsSub;
  StreamSubscription<String>? _emotionsErrorSub;
  StreamSubscription<List<neiry.MemsSample>>? _memsSub;

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
  Stream<CardioData> get cardioStream => _cardioController.stream;

  @override
  Stream<RrInterval> get rrStream => _rrController.stream;

  @override
  Stream<BciEmotionsData> get emotionsStream => _emotionsController.stream;

  @override
  Stream<MotionData> get motionStream => _motionController.stream;

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
        .requestDevices(type: neiry.NeiryDeviceType.headband, searchTime: 5)
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
      _nfbClassifier = neiry.NfbClassifier(_device!);
      _cardioClassifier = neiry.CardioClassifier(_device!);
      _emotionsClassifier = neiry.EmotionsClassifier(_device!);
      _memsClassifier = neiry.MEMSClassifier(_device!);
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
        await _memsClassifier?.dispose();
      } catch (_) {}
      _memsClassifier = null;
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
    // All four classifiers are guaranteed non-null here: connect()'s try block
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
    _rrSub = _cardioClassifier!.rrStream.listen(
      _onRrInterval,
      onError: (Object e) =>
          logPrint('NeiryBciProvider: rrStream error: $e'),
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
    _memsSub = _memsClassifier!.memsStream.listen(
      _onMemsBatch,
      onError: (Object e) =>
          logPrint('NeiryBciProvider: memsStream error: $e'),
    );
  }

  // ── NeiryConnectionState → BciConnectionState ───────────────────────────────

  void _onNeiryConnectionState(neiry.NeiryConnectionState s) {
    switch (s) {
      case neiry.NeiryConnectionState.connected:
        _connectionStateController.add(BciConnectionState.connecting);
      case neiry.NeiryConnectionState.disconnected:
        _connectionStateController.add(BciConnectionState.disconnected);
      case neiry.NeiryConnectionState.unsupportedConnection:
        logPrint('NeiryBciProvider: unsupported connection');
        _connectionStateController.add(BciConnectionState.disconnected);
    }
  }

  // ── ResistanceData → List<BciChannelQuality> ────────────────────────────────

  void _onResistance(neiry.ResistanceData r) {
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

  void _onNfbState(neiry.NfbUserState s) {
    _nfbController.add(BciNfbData(
      timestamp: s.timestamp,
      delta: s.delta,
      theta: s.theta,
      alpha: s.alpha,
      smr: s.smr,
      beta: s.beta,
    ));
  }

  // ── neiry.CardioData → CardioData ───────────────────────────────────────────

  void _onCardioState(neiry.CardioData c) {
    _cardioController.add(CardioData(
      heartRate: c.heartRate,
      metricsAvailable: c.metricsAvailable,
      hasArtifacts: c.hasArtifacts,
      timestamp: c.timestamp,
      source: SensorSource.neiry,
      hrv: null,
    ));
  }

  // ── neiry.RRInterval → RrInterval ───────────────────────────────────────────

  void _onRrInterval(neiry.RRInterval rr) {
    _rrController.add(RrInterval(
      intervalMs: rr.intervalMs,
      timestamp: rr.timestamp,
      isArtifact: rr.isArtifact,
      source: SensorSource.neiry,
    ));
  }

  // ── List<neiry.MemsSample> → MotionData ─────────────────────────────────────

  void _onMemsBatch(List<neiry.MemsSample> batch) {
    for (final s in batch) {
      _motionController.add(MotionData(
        accelerometer: s.accelerometer,
        gyroscope: s.gyroscope,
        timestamp: s.timestamp,
        source: SensorSource.neiry,
      ));
    }
  }

  // ── EmotionsStates → BciEmotionsData ────────────────────────────────────────

  void _onEmotionsState(neiry.EmotionsStates e) {
    _emotionsController.add(BciEmotionsData(
      timestamp: e.timestamp,
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
    _calibrationSub = neiry.NfbCalibrator.calibrateIndividual().listen(
      (event) {
        switch (event) {
          case neiry.CalibrationStageFinished(:final stage):
            _calibrationController.add(
              BciCalibrationStageFinished(stage.index + 1),
            );
          case neiry.CalibrationCompleted(:final data):
            final mapped = NfbCalibrationData(
              calibratedAt: data.timestamp ?? DateTime.now(),
              isValid: data.isValid,
              failReason: data.failReason.name,
              individualFrequency: data.individualFrequency,
              individualPeakFrequencyPower: data.individualPeakFrequencyPower,
              individualPeakFrequencySuppression: data.individualPeakFrequencySuppression,
              individualBandwidth: data.individualBandwidth,
              individualNormalizedPower: data.individualNormalizedPower,
              lowerFrequency: data.lowerFrequency,
              upperFrequency: data.upperFrequency,
            );
            _calibrationController.add(BciCalibrationCompleted(mapped));
        }
      },
      onError: (Object e) {
        logPrint('NeiryBciProvider: calibration error: $e');
        _calibrationController.add(BciCalibrationFailed(e.toString()));
      },
    );
  }

  // ── importCalibration() ────────────────────────────────────────────────────

  @override
  Future<void> importCalibration(NfbCalibrationData data) async {
    final neiryData = neiry.IndividualNfbData(
      timestamp: data.calibratedAt,
      failReason: neiry.NfbCalibrationFailReason.values
          .firstWhere((e) => e.name == data.failReason),
      individualFrequency: data.individualFrequency,
      individualPeakFrequency: data.individualFrequency,
      individualPeakFrequencyPower: data.individualPeakFrequencyPower,
      individualPeakFrequencySuppression:
          data.individualPeakFrequencySuppression,
      individualBandwidth: data.individualBandwidth,
      individualNormalizedPower: data.individualNormalizedPower,
      lowerFrequency: data.lowerFrequency,
      upperFrequency: data.upperFrequency,
    );
    await neiry.NfbCalibrator.importCalibrationData(neiryData);
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
    await _rrSub?.cancel();
    _rrSub = null;
    await _emotionsSub?.cancel();
    _emotionsSub = null;
    await _emotionsErrorSub?.cancel();
    _emotionsErrorSub = null;
    await _memsSub?.cancel();
    _memsSub = null;

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
    try {
      await _memsClassifier?.dispose();
    } catch (e) {
      logPrint('NeiryBciProvider: mems dispose error: $e');
    }
    _memsClassifier = null;
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
    _rrController.close();
    _emotionsController.close();
    _motionController.close();
  }
}
