import 'dart:async';

import 'package:collection/collection.dart';
import 'package:mind/Bci/BciDeviceRepository.dart';
import 'package:mind/Bci/NfbCalibrationRepository.dart';
import 'package:mind/Bci/IBciDeviceProvider.dart';
import 'package:mind/Bci/Models/BciCalibrationEvent.dart';
import 'package:mind/Bci/Models/BciChannelQuality.dart';
import 'package:mind/Bci/Models/BciConnectionState.dart';
import 'package:mind/Bci/Models/BciDeviceInfo.dart';
import 'package:mind/Bci/Models/BciEmotionsData.dart';
import 'package:mind/Bci/Models/BciNfbData.dart';
import 'package:mind/Bci/Models/BluetoothPermissionDeniedException.dart';
import 'package:mind/Biometrics/IEegBandsSource.dart';
import 'package:mind/Biometrics/IEmotionsSource.dart';
import 'package:mind/Biometrics/IHeartRateSource.dart';
import 'package:mind/Biometrics/Models/CardioData.dart';
import 'package:mind/Logger.dart';

class BciDeviceManager {
  final IBciDeviceProvider _provider;
  final IHeartRateSource _cardioSource;
  final IEegBandsSource _eegBandsSource;
  final IEmotionsSource _emotionsSource;
  final BciDeviceRepository _repository;
  final NfbCalibrationRepository _nfbCalibrationRepository;

  // Internal state
  bool _disposed = false;
  BciConnectionState _state = BciConnectionState.disconnected;
  String? _connectedSerial;
  bool _suppressAutoReconnect = false;
  List<BciDeviceInfo> _discoveredDevices = const <BciDeviceInfo>[];

  // Broadcast controllers
  final _stateController = StreamController<BciConnectionState>.broadcast();
  final _discoveredDevicesController = StreamController<List<BciDeviceInfo>>.broadcast();

  // Provider stream subscriptions (nullable, assigned in constructor via _subscribeProviderStreams)
  StreamSubscription<BciConnectionState>? _connectionStateSub;
  StreamSubscription<BciCalibrationEvent>? _calibrationSub;
  StreamSubscription<List<BciDeviceInfo>>? _scanSub;

  BciDeviceManager({
    required IBciDeviceProvider provider,
    required IHeartRateSource cardioSource,
    required IEegBandsSource eegBandsSource,
    required IEmotionsSource emotionsSource,
    required BciDeviceRepository repository,
    required NfbCalibrationRepository nfbCalibrationRepository,
  })  : _provider = provider,
        _cardioSource = cardioSource,
        _eegBandsSource = eegBandsSource,
        _emotionsSource = emotionsSource,
        _repository = repository,
        _nfbCalibrationRepository = nfbCalibrationRepository {
    _subscribeProviderStreams();
  }

  void _subscribeProviderStreams() {
    _connectionStateSub = _provider.connectionStateStream.listen((state) {
      if (state == BciConnectionState.disconnected &&
          _state != BciConnectionState.disconnected &&
          _state != BciConnectionState.scanning &&
          _state != BciConnectionState.connecting &&
          _state != BciConnectionState.bluetoothPermissionDenied) {
        logPrint('BciDeviceManager: unexpected disconnect');
        _setState(BciConnectionState.disconnected);
        if (!_suppressAutoReconnect && _connectedSerial != null) {
          unawaited(_attemptReconnect());
        }
      }
    });
    _calibrationSub = _provider.calibrationStream.listen((event) {
      switch (event) {
        case BciCalibrationStageFinished():
          break; // stage progress forwarded to UI via public calibrationStream — no state change
        case BciCalibrationCompleted(data: final data):
          // _connectedSerial is captured synchronously — Dart is single-threaded
          // within a listener callback, so the null check and dereference are safe.
          // Edge case: a late-arriving event after disconnect→reconnect-to-different-device
          // would record under the new serial; accepted as a thin race given that
          // calibration events fire immediately during calibrateIndividual().
          if (data.isValid && _connectedSerial != null) {
            unawaited(_nfbCalibrationRepository.record(_connectedSerial!, data).catchError(
              (Object e) => logPrint('BciDeviceManager: nfbCalibration record failed: $e'),
            ));
          }
          if (_state == BciConnectionState.calibrating) _setState(BciConnectionState.ready);
        case BciCalibrationFailed(:final reason):
          logPrint('BciDeviceManager: calibration failed: $reason');
          if (_state == BciConnectionState.calibrating) _setState(BciConnectionState.impedance);
      }
    });
  }

  // ── Public getters ──────────────────────────────────────────────────────────

  BciConnectionState get state => _state;
  String? get connectedSerial => _connectedSerial;
  Stream<BciConnectionState> get stateStream => _stateController.stream;
  Stream<List<BciDeviceInfo>> get discoveredDevicesStream => _discoveredDevicesController.stream;
  Stream<List<BciChannelQuality>> get signalQualityStream => _provider.signalQualityStream;
  Stream<int> get batteryStream => _provider.batteryStream;
  Stream<BciCalibrationEvent> get calibrationStream => _provider.calibrationStream;
  Stream<BciNfbData> get nfbStream => _eegBandsSource.nfbStream;
  Stream<CardioData> get cardioStream => _cardioSource.cardioStream;
  Stream<BciEmotionsData> get emotionsStream => _emotionsSource.emotionsStream;
  List<BciDeviceInfo> get discoveredDevices => _discoveredDevices;
  List<String> cachedSerials() => _repository.cachedSerials();

  // ── Internal helpers ────────────────────────────────────────────────────────

  void _setState(BciConnectionState next) {
    if (_disposed || next == _state) return;
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    _disposed = true;
    await _connectionStateSub?.cancel();
    await _calibrationSub?.cancel();
    await _scanSub?.cancel();
    await _stateController.close();
    await _discoveredDevicesController.close();
  }

  // ── Public API (stubs — bodies land in later tasks) ─────────────────────────

  Future<void> startScan() async {
    _suppressAutoReconnect = false;
    // Bypass _setState dedup — manager stays alive between screen sessions and
    // may already be in scanning state, which would silence the event and leave
    // the new subscriber without a fresh BciStateChanged(scanning).
    _state = BciConnectionState.scanning;
    if (!_disposed && !_stateController.isClosed) {
      _stateController.add(BciConnectionState.scanning);
    }

    unawaited(_repository.fetchKnownSerials().catchError((Object e) {
      logPrint('BciDeviceManager: fetchKnownSerials failed: $e');
      return <String>[];
    }));

    final cachedSerials = _repository.cachedSerials();

    await _scanSub?.cancel();
    _scanSub = _provider.scan().listen(
      (discovered) async {
        if (_disposed) return;
        _discoveredDevices = discovered;
        if (!_discoveredDevicesController.isClosed) {
          _discoveredDevicesController.add(discovered);
        }

        if (cachedSerials.isEmpty) return;

        final autoConnect = discovered.firstWhereOrNull(
          (d) => cachedSerials.contains(d.serial),
        );
        if (autoConnect != null && _state == BciConnectionState.scanning) {
          await _scanSub?.cancel();
          _scanSub = null;
          await connectDevice(autoConnect.serial);
        }
      },
      onError: (Object e) {
        // startScan() bypasses _setState dedup (direct _state assignment + add),
        // so a subsequent bluetoothPermissionDenied is always a real transition.
        if (e is BluetoothPermissionDeniedException) {
          logPrint('BciDeviceManager: bluetooth permission denied — cannot scan');
          _setState(BciConnectionState.bluetoothPermissionDenied);
        } else {
          logPrint('BciDeviceManager: scan error: $e');
          _setState(BciConnectionState.disconnected);
        }
      },
      onDone: () {
        if (_state == BciConnectionState.scanning) {
          _setState(BciConnectionState.disconnected);
        }
      },
    );
  }

  Future<void> connectDevice(String serial) async {
    _setState(BciConnectionState.connecting);
    try {
      await _provider.connect(serial);
      _connectedSerial = serial;
      unawaited(_repository.registerDevice(serial).catchError(
        (Object e) => logPrint('BciDeviceManager: registerDevice failed: $e'),
      ));

      var restored = false;
      final cal = _nfbCalibrationRepository.latestValid(serial);
      if (cal != null) {
        try {
          await _provider.importCalibration(cal);
          restored = true;
        } catch (e) {
          logPrint('BciDeviceManager: importCalibration failed: $e');
          // Fall through to normal impedance/calibration flow.
        }
      }

      // Guard against disconnect() racing with the awaited importCalibration call.
      // If the user disconnected mid-flight, _state has moved to disconnected and
      // we must not override it back to ready/impedance.
      if (_state == BciConnectionState.connecting) {
        _setState(restored ? BciConnectionState.ready : BciConnectionState.impedance);
      }
    } catch (e) {
      logPrint('BciDeviceManager: connect failed: $e');
      _setState(BciConnectionState.disconnected);
    }
  }

  Future<void> startCalibration() async {
    if (_state != BciConnectionState.impedance) return;
    _setState(BciConnectionState.calibrating);
    try {
      await _provider.startCalibration();
      // success path: calibration events flow through _provider.calibrationStream
      // and are handled by the listener in _subscribeProviderStreams.
    } catch (e) {
      logPrint('BciDeviceManager: startCalibration failed: $e');
      _setState(BciConnectionState.impedance);
    }
  }

  Future<void> disconnect() async {
    _suppressAutoReconnect = true;
    await _scanSub?.cancel();
    _scanSub = null;
    await _provider.disconnect();
    _connectedSerial = null;
    _setState(BciConnectionState.disconnected);
  }

  Future<void> _attemptReconnect() async {
    _setState(BciConnectionState.scanning);
    await _scanSub?.cancel();
    _scanSub = _provider.scan().listen(
      (discovered) async {
        if (_disposed) return;
        _discoveredDevices = discovered;
        if (!_discoveredDevicesController.isClosed) {
          _discoveredDevicesController.add(discovered);
        }
        final match = discovered.firstWhereOrNull(
          (d) => d.serial == _connectedSerial,
        );
        if (match != null && _state == BciConnectionState.scanning) {
          await _scanSub?.cancel();
          _scanSub = null;
          await connectDevice(match.serial);
        }
      },
      onError: (Object e) {
        // Dedup safety: the only caller is the disconnect listener which
        // transitions _state → disconnected before invoking _attemptReconnect(),
        // so _setState(scanning) at line 185 always fires. If you add another
        // caller that may leave _state already at scanning (or bluetoothPermissionDenied),
        // audit this path.
        if (e is BluetoothPermissionDeniedException) {
          logPrint('BciDeviceManager: bluetooth permission denied — cannot reconnect');
          _setState(BciConnectionState.bluetoothPermissionDenied);
        } else {
          logPrint('BciDeviceManager: reconnect scan error: $e');
          _setState(BciConnectionState.disconnected);
        }
      },
      onDone: () {
        if (_state == BciConnectionState.scanning && _connectedSerial != null) {
          _setState(BciConnectionState.disconnected);
        }
      },
    );
  }
}
