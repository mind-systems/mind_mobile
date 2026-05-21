import 'dart:async';
import 'dart:math' show min;

import 'package:neiry_kit/neiry_kit.dart';

import 'IBciDeviceProvider.dart';
import 'Models/BciCalibrationEvent.dart';
import 'Models/BciChannelQuality.dart';
import 'Models/BciConnectionState.dart';
import 'Models/BciDeviceInfo.dart';
import '../Logger.dart';

/// Adapter that bridges `neiry_kit` to [IBciDeviceProvider].
///
/// This is the **only** file in `mind_mobile` that may import `neiry_kit`.
/// All consumers must depend on [IBciDeviceProvider], never on this class.
class NeiryBciProvider implements IBciDeviceProvider {
  final DeviceLocator _locator = DeviceLocator();
  Device? _device;

  final _connectionStateController =
      StreamController<BciConnectionState>.broadcast();
  final _signalQualityController =
      StreamController<List<BciChannelQuality>>.broadcast();
  final _batteryController = StreamController<int>.broadcast();
  final _calibrationController =
      StreamController<BciCalibrationEvent>.broadcast();

  StreamSubscription<NeiryConnectionState>? _connectionSub;
  StreamSubscription<ResistanceData>? _resistanceSub;
  StreamSubscription<int>? _batterySub;
  StreamSubscription<CalibrationEvent>? _calibrationSub;

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

  // ── scan() ──────────────────────────────────────────────────────────────────

  @override
  Stream<List<BciDeviceInfo>> scan() => _locator
      .requestDevices(type: NeiryDeviceType.headband, searchTime: 5)
      .map((list) =>
          list.map((d) => BciDeviceInfo(serial: d.serial, name: d.name)).toList());

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
    } catch (e) {
      await _device?.disconnect();
      await _device?.dispose();
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
  }
}
