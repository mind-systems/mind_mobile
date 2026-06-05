import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:bci_module/bci_module.dart';
import 'package:mind/Bci/BciNotifier.dart';
import 'package:mind/Bci/Models/BciNotifierEvent.dart';
import 'package:mind/Bci/Models/BciConnectionState.dart';
import 'package:mind/Bci/Models/BciCalibrationEvent.dart';
import 'package:mind/BciModule/BciChannelQualityMapping.dart';

class BciPairingService implements IBciPairingService {
  final BciNotifier bciNotifier;

  // Tracks the serial passed to connectDevice() so the reducer can embed it
  // in BciPairingState.connectedSerial. For auto-connect (known device,
  // BciNotifier initiates without a user tap), this is null — we fall back
  // to the single device in the scanned list.
  String? _connectingSerial;

  BciPairingService({required this.bciNotifier});

  // NOTE: BciNotifier._subject is a BehaviorSubject that caches only the single
  // most-recent event. A new subscriber replays one event — not one per variant.
  // BciPairingViewModel.build() calls startScan() on subscribe to trigger fresh
  // emissions; do not assume full history is available on subscribe.
  @override
  Stream<BciPairingServiceEvent> observeChanges() {
    return bciNotifier.stream
        .scan<BciPairingState>(
          (acc, event, _) => _reduce(acc, event),
          BciPairingState.initial(),
        )
        .map((state) => BciPairingStateUpdated(state));
  }

  // ── Command methods ───────────────────────────────────────────────────────

  @override
  void startScan() => unawaited(bciNotifier.startScan());

  @override
  void connectDevice(String serial) {
    _connectingSerial = serial;
    unawaited(bciNotifier.connectDevice(serial));
  }

  @override
  void startCalibration() => unawaited(bciNotifier.startCalibration());

  @override
  void disconnect() => unawaited(bciNotifier.disconnect());

  // ── Reducer ───────────────────────────────────────────────────────────────

  BciPairingState _reduce(BciPairingState acc, BciNotifierEvent event) {
    switch (event) {
      // errorMessage is cleared on every non-error BciStateChanged branch so
      // the UI never shows stale error text alongside a fresh "connecting" /
      // "scanning" state. Error text is only re-populated by BciError or
      // BciCalibrationFailed.
      case BciStateChanged(:final state):
        return _reduceStateChanged(acc, state);

      case BciDevicesDiscovered(:final devices):
        final known = bciNotifier.knownSerials.toSet();
        final dtos = devices
            .map((d) => BciScannedDeviceDTO(
                  serial: d.serial,
                  name: d.name,
                  isKnown: known.contains(d.serial),
                ))
            .toList(growable: false);
        return acc.copyWith(devices: dtos);

      case BciSignalQualityUpdated(:final channels):
        return acc.copyWith(channels: mapBciChannelQualities(channels));

      case BciCalibrationEventReceived(:final event):
        return _reduceCalibrationEvent(acc, event);

      case BciBatteryUpdated(:final percent):
        return acc.copyWith(batteryPercent: percent);

      case BciError(:final message):
        return acc.copyWith(errorMessage: message);

      case BciNfbUpdated():
      case BciCardioUpdated():
      case BciEmotionsUpdated():
        return acc;
    }
  }

  BciPairingState _reduceStateChanged(
    BciPairingState acc,
    BciConnectionState state,
  ) {
    switch (state) {
      case BciConnectionState.disconnected:
        _connectingSerial = null;
        return acc.copyWith(
          stage: BciPairingStage.discovery,
          isScanning: false,
          isConnecting: false,
          isBluetoothPermissionDenied: false,
          connectedSerial: null,
          calibration: null,                         // cleared via _undefined sentinel
          channels: const <BciChannelQualityDTO>[], // MUST be empty list — null is a no-op
          batteryPercent: null,                      // cleared via _undefined sentinel
          errorMessage: null,                        // cleared via _undefined sentinel
        );

      case BciConnectionState.scanning:
        _connectingSerial = null;
        return acc.copyWith(
          stage: BciPairingStage.discovery,
          isScanning: true,
          isConnecting: false,
          isBluetoothPermissionDenied: false,
          connectedSerial: null,
          errorMessage: null,
        );

      case BciConnectionState.bluetoothPermissionDenied:
        return acc.copyWith(
          stage: BciPairingStage.discovery,
          isScanning: false,
          isConnecting: false,
          isBluetoothPermissionDenied: true,
          batteryPercent: null,                      // cleared via _undefined sentinel
          errorMessage: null,
        );

      case BciConnectionState.connecting:
        // For auto-connect (known device, BciNotifier initiates without a tap),
        // _connectingSerial is null. Fall back to the single scanned device.
        _connectingSerial ??=
            acc.devices.length == 1 ? acc.devices.first.serial : null;
        return acc.copyWith(
          stage: BciPairingStage.discovery,
          isScanning: false,
          isConnecting: true,
          connectedSerial: _connectingSerial,
          errorMessage: null,
        );

      case BciConnectionState.impedance:
        return acc.copyWith(
          stage: BciPairingStage.impedance,
          isScanning: false,
          isConnecting: false,
          connectedSerial: _connectingSerial ?? acc.connectedSerial,
          errorMessage: null,
        );

      case BciConnectionState.calibrating:
        return acc.copyWith(
          stage: BciPairingStage.calibrating,
          isScanning: false,
          isConnecting: false,
          errorMessage: null,
          calibration: const BciCalibrationProgressDTO(
            stagesCompleted: 0,
            isComplete: false,
          ),
        );

      case BciConnectionState.ready:
        return acc.copyWith(
          stage: BciPairingStage.ready,
          isScanning: false,
          isConnecting: false,
          errorMessage: null,
        );
    }
  }

  BciPairingState _reduceCalibrationEvent(
    BciPairingState acc,
    BciCalibrationEvent event,
  ) {
    switch (event) {
      case BciCalibrationStageFinished(:final stage):
        return acc.copyWith(
          calibration: BciCalibrationProgressDTO(
            stagesCompleted: stage,
            isComplete: acc.calibration?.isComplete ?? false,
          ),
        );

      case BciCalibrationCompleted():
        return acc.copyWith(
          calibration: BciCalibrationProgressDTO(
            stagesCompleted: acc.calibration?.stagesCompleted ?? 0,
            isComplete: true,
          ),
        );

      case BciCalibrationFailed(:final reason):
        return acc.copyWith(calibration: null, errorMessage: reason);
    }
  }
}
