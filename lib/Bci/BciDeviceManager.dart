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
import 'package:mind/Bci/Models/BciLinkStatus.dart';
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
  BciConnectionState _state = BciIdle();
  // Reconnect memory: the serial of the last successfully-targeted device.
  // Kept across unexpected disconnects so _attemptReconnect() knows which
  // device to look for. Cleared only on explicit disconnect().
  String? _connectedSerial;
  bool _suppressAutoReconnect = false;
  List<BciDeviceInfo> _discoveredDevices = const <BciDeviceInfo>[];

  // Broadcast controllers
  final _stateController = StreamController<BciConnectionState>.broadcast();
  final _discoveredDevicesController = StreamController<List<BciDeviceInfo>>.broadcast();

  // Provider stream subscriptions (nullable, assigned in constructor via _subscribeProviderStreams)
  StreamSubscription<BciLinkStatus>? _connectionStateSub;
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
    _connectionStateSub = _provider.connectionStateStream.listen((status) {
      // React to link-layer drops only when a device-bound phase is active.
      // Idle / scanning / permission-denied are unaffected by BLE drops.
      if (status == BciLinkStatus.down && _state is BciActive) {
        logPrint('BciDeviceManager: unexpected disconnect');
        _setState(BciIdle());
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
          if (_state is BciCalibrating) {
            _setState(BciReady((_state as BciCalibrating).serial));
          }
        case BciCalibrationFailed(:final reason):
          logPrint('BciDeviceManager: calibration failed: $reason');
          if (_state is BciCalibrating) {
            _setState(BciImpedance((_state as BciCalibrating).serial));
          }
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

  /// Transitions to [next], suppressing duplicate emissions.
  ///
  /// Dedup compares runtime type; for [BciActive] subtypes, the [BciActive.serial]
  /// is compared too so transitioning between the same phase on different devices
  /// always fires. The [startScan] direct-write bypass is intentional and handled
  /// separately — it re-emits [BciScanning] even when already scanning to ensure
  /// fresh subscribers receive a seeding event.
  void _setState(BciConnectionState next) {
    if (_disposed) return;
    if (next.runtimeType == _state.runtimeType) {
      // Same non-Active type → already in this state, nothing to emit.
      if (next is! BciActive) return;
      // Same Active type + same serial → no real transition.
      if (next.serial == (_state as BciActive).serial) return;
    }
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

  // ── Public API ──────────────────────────────────────────────────────────────

  Future<void> startScan() async {
    _suppressAutoReconnect = false;
    // Bypass _setState dedup — manager stays alive between screen sessions and
    // may already be in scanning state, which would silence the event and leave
    // the new subscriber without a fresh BciStateChanged(scanning).
    _state = BciScanning();
    if (!_disposed && !_stateController.isClosed) {
      _stateController.add(BciScanning());
    }

    unawaited(_repository.fetchKnownSerials().catchError((Object e) {
      logPrint('BciDeviceManager: fetchKnownSerials failed: $e');
      return <String>[];
    }));

    for (final serial in _repository.cachedSerials()) {
      unawaited(_nfbCalibrationRepository.refreshFromServer(serial).catchError(
        (Object e) => logPrint('BciDeviceManager: refreshFromServer failed for $serial: $e'),
      ));
    }

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
        if (autoConnect != null && _state is BciScanning) {
          await _scanSub?.cancel();
          _scanSub = null;
          await connectDevice(autoConnect.serial);
        }
      },
      onError: (Object e) {
        // startScan() bypasses _setState dedup (direct _state assignment + add),
        // so a subsequent BciPermissionDenied is always a real transition.
        if (e is BluetoothPermissionDeniedException) {
          logPrint('BciDeviceManager: bluetooth permission denied — cannot scan');
          _setState(BciPermissionDenied());
        } else {
          logPrint('BciDeviceManager: scan error: $e');
          _setState(BciIdle());
        }
      },
      onDone: () {
        if (_state is BciScanning) {
          _setState(BciIdle());
        }
      },
    );
  }

  Future<void> connectDevice(String serial) async {
    _setState(BciConnecting(serial));
    try {
      await _provider.connect(serial);
      _connectedSerial = serial;
      unawaited(_repository.registerDevice(serial).catchError(
        (Object e) => logPrint('BciDeviceManager: registerDevice failed: $e'),
      ));

      // Guard against disconnect() racing with the awaited connect call. If the user
      // disconnected mid-flight, _state moved away from BciConnecting and must not be overridden.
      if (_state is BciConnecting) {
        _setState(BciImpedance(serial));
      }
    } catch (e) {
      logPrint('BciDeviceManager: connect failed: $e');
      _setState(BciIdle());
    }
  }

  Future<void> startCalibration() async {
    if (_state is! BciImpedance) return;
    final serial = (_state as BciImpedance).serial;
    _setState(BciCalibrating(serial));
    try {
      await _provider.startCalibration();
      // success path: calibration events flow through _provider.calibrationStream
      // and are handled by the listener in _subscribeProviderStreams.
    } catch (e) {
      logPrint('BciDeviceManager: startCalibration failed: $e');
      _setState(BciImpedance(serial));
    }
  }

  Future<void> disconnect() async {
    _suppressAutoReconnect = true;
    await _scanSub?.cancel();
    _scanSub = null;
    await _provider.disconnect();
    _connectedSerial = null;
    _setState(BciIdle());
  }

  Future<void> _attemptReconnect() async {
    _setState(BciScanning());
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
        if (match != null && _state is BciScanning) {
          await _scanSub?.cancel();
          _scanSub = null;
          await connectDevice(match.serial);
        }
      },
      onError: (Object e) {
        // Dedup safety: the only caller is the disconnect listener which
        // transitions _state → BciIdle before invoking _attemptReconnect(),
        // so _setState(BciScanning()) at the top always fires. If you add another
        // caller that may leave _state already at scanning (or BciPermissionDenied),
        // audit this path.
        if (e is BluetoothPermissionDeniedException) {
          logPrint('BciDeviceManager: bluetooth permission denied — cannot reconnect');
          _setState(BciPermissionDenied());
        } else {
          logPrint('BciDeviceManager: reconnect scan error: $e');
          _setState(BciIdle());
        }
      },
      onDone: () {
        if (_state is BciScanning && _connectedSerial != null) {
          _setState(BciIdle());
        }
      },
    );
  }
}
