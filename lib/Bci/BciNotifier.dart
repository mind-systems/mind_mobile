import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'package:mind/Bci/BciDeviceManager.dart';
import 'package:mind/Bci/Models/BciConnectionState.dart';
import 'package:mind/Bci/Models/BciDeviceInfo.dart';
import 'package:mind/Bci/Models/BciNotifierEvent.dart';
import 'package:mind/Logger.dart';

/// Domain notifier that wraps [BciDeviceManager] and exposes a single typed
/// event stream ([BciNotifierEvent]) for the presentation layer.
///
/// This class is a passive translator only — it subscribes to each manager
/// stream and re-emits the corresponding [BciNotifierEvent] variant. It does
/// not hold aggregate state; the manager owns the canonical device state.
class BciNotifier {
  final BciDeviceManager _manager;

  final BehaviorSubject<BciNotifierEvent> _subject = BehaviorSubject<BciNotifierEvent>();

  StreamSubscription<dynamic>? _stateSub;
  StreamSubscription<dynamic>? _devicesSub;
  StreamSubscription<dynamic>? _signalSub;
  StreamSubscription<dynamic>? _calibrationSub;
  StreamSubscription<dynamic>? _batterySub;

  BciNotifier({required BciDeviceManager manager}) : _manager = manager {
    _stateSub = manager.stateStream.listen(
      (state) => _subject.add(BciStateChanged(state)),
      onError: (Object e) {
        logPrint('BciNotifier: stateStream error: $e');
        _subject.add(BciError(e.toString()));
      },
    );

    _devicesSub = manager.discoveredDevicesStream.listen(
      (devices) => _subject.add(BciDevicesDiscovered(devices)),
      onError: (Object e) {
        logPrint('BciNotifier: discoveredDevicesStream error: $e');
        _subject.add(BciError(e.toString()));
      },
    );

    _signalSub = manager.signalQualityStream.listen(
      (channels) => _subject.add(BciSignalQualityUpdated(channels)),
      onError: (Object e) {
        logPrint('BciNotifier: signalQualityStream error: $e');
        _subject.add(BciError(e.toString()));
      },
    );

    _calibrationSub = manager.calibrationStream.listen(
      (event) => _subject.add(BciCalibrationEventReceived(event)),
      onError: (Object e) {
        logPrint('BciNotifier: calibrationStream error: $e');
        _subject.add(BciError(e.toString()));
      },
    );

    _batterySub = manager.batteryStream.listen(
      (percent) => _subject.add(BciBatteryUpdated(percent)),
      onError: (Object e) {
        logPrint('BciNotifier: batteryStream error: $e');
        _subject.add(BciError(e.toString()));
      },
    );
  }

  // ── Public surface ──────────────────────────────────────────────────────────

  Stream<BciNotifierEvent> get stream => _subject.stream;

  BciConnectionState get currentState => _manager.state;

  List<BciDeviceInfo> get discoveredDevices => _manager.discoveredDevices;

  List<String> get knownSerials => _manager.cachedSerials();

  Future<void> startScan() => _manager.startScan();

  Future<void> connectDevice(String serial) => _manager.connectDevice(serial);

  Future<void> startCalibration() => _manager.startCalibration();

  Future<void> disconnect() => _manager.disconnect();

  Future<void> dispose() async {
    await _stateSub?.cancel();
    await _devicesSub?.cancel();
    await _signalSub?.cancel();
    await _calibrationSub?.cancel();
    await _batterySub?.cancel();
    await _subject.close();
    await _manager.dispose();
  }
}
