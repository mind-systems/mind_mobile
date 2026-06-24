import 'dart:async';
import 'dart:io' show Platform;

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

import 'IBciDeviceProvider.dart';
import 'SerialCommandQueue.dart';
import 'Models/BciCalibrationEvent.dart';
import 'Models/BciChannelQuality.dart';
import 'Models/BciLinkStatus.dart';
import 'Models/BciDeviceInfo.dart';
import 'Models/BciEmotionsData.dart';
import 'Models/BciNfbData.dart';
import 'Models/BluetoothPermissionDeniedException.dart';
import 'Models/NfbCalibrationData.dart';
import 'Ports/ClassifierSet.dart';
import 'Ports/DevicePort.dart';
import 'Ports/LocatorPort.dart';
import 'Ports/NeiryLocatorAdapter.dart';
import '../Logger.dart';

/// Adapter that bridges `neiry_kit` to [IBciDeviceProvider].
///
/// Only this file and the port adapters ([NeiryLocatorAdapter],
/// [NeiryDeviceAdapter], [NeiryClassifierSet]) may import `neiry_kit`.
/// All other consumers must depend on [IBciDeviceProvider] or the port
/// interfaces, never on this class or the adapter implementations.
class NeiryBciProvider implements IBciDeviceProvider, IHeartRateSource, IRrIntervalSource, IEegBandsSource, IEmotionsSource, IMotionSource {
  late LocatorPort _locator;
  final LocatorPort Function() _locatorFactory;
  DevicePort? _device;
  ClassifierSet? _classifierSet;
  bool _disposed = false;
  final SerialCommandQueue _queue = SerialCommandQueue();

  NeiryBciProvider({
    LocatorPort Function()? locatorFactory,
  })  : _locatorFactory = locatorFactory ?? (() => NeiryLocatorAdapter()) {
    _locator = _locatorFactory();
  }

  final _connectionStateController =
      StreamController<BciLinkStatus>.broadcast();
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

  StreamSubscription<BciLinkStatus>? _connectionSub;
  StreamSubscription<List<BciChannelQuality>>? _resistanceSub;
  StreamSubscription<int>? _batterySub;
  StreamSubscription<neiry.CalibrationEvent>? _calibrationSub;
  StreamSubscription<BciNfbData>? _nfbSub;
  StreamSubscription<String>? _nfbErrorSub;
  StreamSubscription<CardioData>? _cardioSub;
  StreamSubscription<RrInterval>? _rrSub;
  StreamSubscription<BciEmotionsData>? _emotionsSub;
  StreamSubscription<String>? _emotionsErrorSub;
  StreamSubscription<MotionData>? _memsSub;

  // ── Stream getters ──────────────────────────────────────────────────────────

  @override
  Stream<BciLinkStatus> get connectionStateStream =>
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

    // Enqueue the requestDevices() call so it runs on whatever _locator exists
    // *after* any in-flight teardown command completes (the fresh post-recreate
    // locator). The yield* runs outside the queue slot — it does not block it.
    final Stream<List<BciDeviceInfo>> devicesStream;
    try {
      devicesStream = await _queue.enqueue(
        () async => _locator.requestDevices(type: BciScanDeviceType.headband, searchTime: 5),
      );
    } on QueueClosedException {
      // dispose() closed the queue before the enqueue resolved — end the scan
      // stream cleanly; do not propagate the closure as an error to the consumer.
      return;
    }
    yield* devicesStream;
  }

  // ── connect() ───────────────────────────────────────────────────────────────

  @override
  Future<void> connect(String serial) {
    return _queue.enqueue(() async {
      if (_device != null) {
        throw StateError(
          'NeiryBciProvider: connect() called while already connected. '
          'Call disconnect() first.',
        );
      }
      _device = await _locator.createDevice(serial);
      try {
        await _device!.connect();
        _classifierSet = _device!.buildClassifierSet();
        await _device!.start();
      } catch (e) {
        try {
          await _classifierSet?.dispose();
        } catch (_) {}
        _classifierSet = null;
        try {
          await _device?.disconnect();
          await _device?.dispose();
        } catch (_) {}
        _device = null;
        await _resetLocatorSession();
        rethrow;
      }
      _subscribeDeviceStreams();
    });
  }

  void _subscribeDeviceStreams() {
    _connectionSub = _device!.connectionStateStream.listen(
      _onConnectionStatus,
      onError: (Object e) =>
          logPrint('NeiryBciProvider: connectionStateStream error: $e'),
    );
    _resistanceSub = _device!.resistanceStream.listen(
      _signalQualityController.add,
      onError: (Object e) =>
          logPrint('NeiryBciProvider: resistanceStream error: $e'),
    );
    _batterySub = _device!.batteryStream.listen(
      _batteryController.add,
      onError: (Object e) =>
          logPrint('NeiryBciProvider: batteryStream error: $e'),
    );
    // All ClassifierSet streams are guaranteed non-null here: connect()'s try
    // block builds the set before reaching this method.
    _nfbSub = _classifierSet!.nfbStateStream.listen(
      _nfbController.add,
      onError: (Object e) =>
          logPrint('NeiryBciProvider: nfb stateStream error: $e'),
    );
    _nfbErrorSub = _classifierSet!.nfbErrorStream.listen(
      (e) => logPrint('NeiryBciProvider: nfb error: $e'),
      onError: (Object e) =>
          logPrint('NeiryBciProvider: nfb errorStream error: $e'),
    );
    _cardioSub = _classifierSet!.cardioStateStream.listen(
      _cardioController.add,
      onError: (Object e) =>
          logPrint('NeiryBciProvider: cardio stateStream error: $e'),
    );
    _rrSub = _classifierSet!.rrStream.listen(
      _rrController.add,
      onError: (Object e) =>
          logPrint('NeiryBciProvider: rrStream error: $e'),
    );
    _emotionsSub = _classifierSet!.emotionsStateStream.listen(
      _emotionsController.add,
      onError: (Object e) =>
          logPrint('NeiryBciProvider: emotions stateStream error: $e'),
    );
    _emotionsErrorSub = _classifierSet!.emotionsErrorStream.listen(
      (e) => logPrint('NeiryBciProvider: emotions error: $e'),
      onError: (Object e) =>
          logPrint('NeiryBciProvider: emotions errorStream error: $e'),
    );
    _memsSub = _classifierSet!.motionStream.listen(
      _motionController.add,
      onError: (Object e) =>
          logPrint('NeiryBciProvider: memsStream error: $e'),
    );
  }

  // ── BciLinkStatus handler ───────────────────────────────────────────────────

  /// Handles domain-level connection status events from [DevicePort.connectionStateStream].
  ///
  /// [BciLinkStatus.down] covers both normal disconnects and
  /// unsupported-connection events — [NeiryDeviceAdapter] maps and logs the
  /// latter before it reaches this handler.
  void _onConnectionStatus(BciLinkStatus status) {
    switch (status) {
      case BciLinkStatus.up:
        _connectionStateController.add(BciLinkStatus.up);
      case BciLinkStatus.down:
        // Idempotency guard: our own disconnect() already nulls _device and
        // emits; a second native event in that window is redundant noise.
        if (_device == null) return;
        // Null fields synchronously BEFORE emitting — reconnect's connect()
        // throws StateError if _device is non-null when it runs.
        _teardownAfterUnexpectedDrop();
        _connectionStateController.add(BciLinkStatus.down);
    }
  }

  // ── startCalibration() ──────────────────────────────────────────────────────

  @override
  Future<void> startCalibration() {
    return _queue.enqueue(() async {
      if (_disposed) return;
      await _calibrationSub?.cancel();
      _calibrationSub = neiry.NfbCalibrator.calibrateIndividual().listen(
        (event) {
          switch (event) {
            case neiry.CalibrationStageFinished(:final stage):
              _emitCalibration(
                BciCalibrationStageFinished(stage.index + 1),
              );
            case neiry.CalibrationCompleted(:final data):
              final mapped = NfbCalibrationData(
                calibratedAt: data.timestamp ?? DateTime.now(),
                isValid: data.isValid,
                failReason: data.failReason.name,
                individualFrequency: data.individualFrequency,
                individualPeakFrequency: data.individualPeakFrequency,
                individualPeakFrequencyPower: data.individualPeakFrequencyPower,
                individualPeakFrequencySuppression: data.individualPeakFrequencySuppression,
                individualBandwidth: data.individualBandwidth,
                individualNormalizedPower: data.individualNormalizedPower,
                lowerFrequency: data.lowerFrequency,
                upperFrequency: data.upperFrequency,
              );
              _emitCalibration(BciCalibrationCompleted(mapped));
          }
        },
        onError: (Object e) {
          logPrint('NeiryBciProvider: calibration error: $e');
          _emitCalibration(BciCalibrationFailed(e.toString()));
        },
      );
    });
  }

  // ── startQuickCalibration() ─────────────────────────────────────────────────

  @override
  Future<void> startQuickCalibration() {
    return _queue.enqueue(() async {
      if (_disposed) return;
      await _calibrationSub?.cancel();
      _calibrationSub = null;
      try {
        final data = await neiry.NfbCalibrator.calibrateIndividualQuick();
        final mapped = NfbCalibrationData(
          calibratedAt: data.timestamp ?? DateTime.now(),
          isValid: data.isValid,
          failReason: data.failReason.name,
          individualFrequency: data.individualFrequency,
          individualPeakFrequency: data.individualPeakFrequency,
          individualPeakFrequencyPower: data.individualPeakFrequencyPower,
          individualPeakFrequencySuppression: data.individualPeakFrequencySuppression,
          individualBandwidth: data.individualBandwidth,
          individualNormalizedPower: data.individualNormalizedPower,
          lowerFrequency: data.lowerFrequency,
          upperFrequency: data.upperFrequency,
        );
        _emitCalibration(BciCalibrationCompleted(mapped));
      } catch (e) {
        logPrint('NeiryBciProvider: quick calibration error: $e');
        _emitCalibration(BciCalibrationFailed(e.toString()));
      }
    });
  }

  // ── importCalibration() ────────────────────────────────────────────────────

  @override
  Future<void> importCalibration(NfbCalibrationData data) {
    return _queue.enqueue(() async {
      if (_disposed) return;
      final neiryData = neiry.IndividualNfbData(
        timestamp: data.calibratedAt,
        failReason: neiry.NfbCalibrationFailReason.values
            .firstWhere((e) => e.name == data.failReason),
        individualFrequency: data.individualFrequency,
        individualPeakFrequency: data.individualPeakFrequency,
        individualPeakFrequencyPower: data.individualPeakFrequencyPower,
        individualPeakFrequencySuppression:
            data.individualPeakFrequencySuppression,
        individualBandwidth: data.individualBandwidth,
        individualNormalizedPower: data.individualNormalizedPower,
        lowerFrequency: data.lowerFrequency,
        upperFrequency: data.upperFrequency,
      );
      await neiry.NfbCalibrator.importCalibrationData(neiryData);
    });
  }

  void _emitCalibration(BciCalibrationEvent event) {
    if (_disposed || _calibrationController.isClosed) return;
    _calibrationController.add(event);
  }

  // ── disconnect() ────────────────────────────────────────────────────────────

  /// Disposes the current locator and replaces it with a fresh one so the
  /// next connect() goes through a brand-new native session. The SDK caches
  /// clCDevice per serial inside the locator and never evicts on release, so
  /// reusing the same locator returns a stale device on reconnect.
  /// No-op once the provider has been terminally disposed.
  Future<void> _resetLocatorSession() async {
    if (_disposed) return;
    try {
      await _locator.dispose();
    } catch (_) {
      // StateError on double-dispose — locator already torn down.
    }
    if (_disposed) return;
    _locator = _locatorFactory();
  }

  /// Captures device + classifier-set + subscription fields into locals, nulls
  /// them immediately (so reconnect sees a clean slate), then schedules the
  /// actual heavy disposal asynchronously to avoid re-entrancy while
  /// [_connectionSub]'s callback is still on the stack.
  ///
  /// Does NOT touch [_calibrationSub] or the [StreamController]s — they must
  /// stay alive so reconnect can resume emitting.
  void _teardownAfterUnexpectedDrop() {
    if (_disposed) return;
    final device = _device;
    final classifierSet = _classifierSet;

    final connectionSub = _connectionSub;
    final resistanceSub = _resistanceSub;
    final batterySub = _batterySub;
    final nfbSub = _nfbSub;
    final nfbErrorSub = _nfbErrorSub;
    final cardioSub = _cardioSub;
    final rrSub = _rrSub;
    final emotionsSub = _emotionsSub;
    final emotionsErrorSub = _emotionsErrorSub;
    final memsSub = _memsSub;

    _device = null;
    _classifierSet = null;

    _connectionSub = null;
    _resistanceSub = null;
    _batterySub = null;
    _nfbSub = null;
    _nfbErrorSub = null;
    _cardioSub = null;
    _rrSub = null;
    _emotionsSub = null;
    _emotionsErrorSub = null;
    _memsSub = null;

    unawaited(_queue.enqueue(() async {
      try {
        // Step 1: stopStream() = nativeUnregister + nativeStop — stops SDK background
        // threads before any Dart subscription is cancelled (Invariant A). Native side
        // may already be gone on unexpected drop; wrap in try/catch and continue.
        try { await device?.stopStream(); } catch (_) {}

        // Step 2: cancel fan-in subscriptions (safe — background threads stopped).
        await connectionSub?.cancel();
        await resistanceSub?.cancel();
        await batterySub?.cancel();
        await nfbSub?.cancel();
        await nfbErrorSub?.cancel();
        await cardioSub?.cancel();
        await rrSub?.cancel();
        await emotionsSub?.cancel();
        await emotionsErrorSub?.cancel();
        await memsSub?.cancel();

        // Step 3: dispose classifiers (safe — handle still alive, no nativeRelease yet).
        try {
          await classifierSet?.dispose();
        } catch (e) {
          logPrint('NeiryBciProvider: classifier dispose error: $e');
        }

        // Step 4: nativeDisconnect + nativeRelease (Invariant C).
        try {
          await device?.disconnect();
          await device?.dispose();
        } catch (e) {
          logPrint('NeiryBciProvider: unexpected drop dispose error: $e');
        }
      } finally {
        await _resetLocatorSession();
      }
    }).catchError(
      // A QueueClosedException here means dispose() closed the queue before this
      // fire-and-forget teardown's slot ran. For the normal path _doDispose's
      // terminal teardown owns cleanup. In the narrow dispose-races-an-in-flight-
      // disconnect window, the device/subs captured (and nulled) above are a
      // knowingly-accepted leak (see C1 reviews) — too rare to justify the riskier
      // capture-inside-the-command fix, which would break the double-drop idempotency.
      // Any other error (e.g. a throwing sub.cancel() or a recreate failure) is
      // logged and swallowed — top-level safety net so teardown never escapes as an
      // unhandled zone error.
      (Object e) {
        if (e is! QueueClosedException) {
          logPrint('NeiryBciProvider: unexpected drop teardown error: $e');
        }
      },
    ));
  }

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
      await _classifierSet?.dispose();
    } catch (e) {
      logPrint('NeiryBciProvider: classifier dispose error: $e');
    }
    _classifierSet = null;
  }

  @override
  Future<void> disconnect() {
    return _queue.enqueue(() async {
      // Step 1: stopStream() = nativeUnregister + nativeStop — stops SDK background
      // threads before any Dart subscription is cancelled (Invariant A).
      // Only called when streaming is active; calling it on an unstarted device throws.
      if (_device?.isStarted == true) {
        try {
          await _device!.stopStream();
        } catch (e) {
          logPrint('NeiryBciProvider: stopStream error: $e');
        }
      }
      // Steps 2+3: cancel fan-in subscriptions and dispose classifier set.
      // Safe — SDK threads are stopped, handle still alive (no nativeRelease yet).
      await _cancelDeviceSubscriptions();
      // Step 4: nativeDisconnect + nativeRelease (Invariant C).
      try {
        await _device?.disconnect();
      } catch (e) {
        logPrint('NeiryBciProvider: disconnect error: $e');
      }
      // Step 5: Dart cleanup — no-op on native (already disconnected above).
      try {
        await _device?.dispose();
      } catch (e) {
        logPrint('NeiryBciProvider: dispose error: $e');
      }
      _device = null;
      await _resetLocatorSession();
      // Emit explicitly — _connectionSub is already cancelled so the native
      // disconnected event would be missed without this.
      _connectionStateController.add(BciLinkStatus.down);
    });
  }

  // ── dispose() ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    // Interface requires void; native teardown continues in the background.
    unawaited(_doDispose());
  }

  Future<void> _doDispose() async {
    _disposed = true;
    // Close the queue to new enqueues and drop any unstarted tail commands
    // (poison-pill). Then wait for the currently-executing command (if any)
    // to finish so the terminal teardown below does not interleave with it.
    _queue.close();
    await _queue.idle;

    // Terminal teardown — same invariant sequence as disconnect(), but does
    // NOT call _resetLocatorSession() (no locator recreate on the terminal path).
    if (_device?.isStarted == true) {
      try { await _device!.stopStream(); } catch (_) {}
    }
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
    try {
      await _locator.dispose();
    } catch (_) {
      // StateError if already disposed by a teardown path that ran first.
    }
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
