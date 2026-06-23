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

  BciPairingService({required this.bciNotifier});

  // NOTE: BciNotifier._subject is a BehaviorSubject — replays only the single
  // most-recent event to new subscribers. We prepend a synthetic
  // BciStateChanged(currentState) so the reducer always seeds connection state
  // correctly regardless of which event happens to be cached.
  @override
  Stream<BciPairingServiceEvent> observeChanges() {
    return bciNotifier.stream
        .startWith(BciStateChanged(bciNotifier.currentState))
        .scan<BciPairingState>(
          (acc, event, _) => _reduce(acc, event),
          BciPairingState.initial(),
        )
        .map((state) => BciPairingStateUpdated(state));
  }

  // ── Command methods ───────────────────────────────────────────────────────

  @override
  void startScan() {
    final current = bciNotifier.currentState;
    if (current is BciIdle || current is BciScanning || current is BciPermissionDenied) {
      unawaited(bciNotifier.startScan());
    }
  }

  @override
  void connectDevice(String serial) {
    unawaited(bciNotifier.connectDevice(serial));
  }

  @override
  void startCalibration() => unawaited(bciNotifier.startCalibration());

  @override
  void startQuickCalibration() => unawaited(bciNotifier.startQuickCalibration());

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

  // The reducer reads only [acc] and [state] — no external mutable reads.
  // Identity is derived purely from the sealed state variant: [BciActive]
  // branches carry [serial] directly, so [connectedSerial] is always correct
  // for both user-tap connect and manager-internal auto-connect.
  BciPairingState _reduceStateChanged(
    BciPairingState acc,
    BciConnectionState state,
  ) {
    switch (state) {
      case BciIdle():
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

      case BciScanning():
        return acc.copyWith(
          stage: BciPairingStage.discovery,
          isScanning: true,
          isConnecting: false,
          isBluetoothPermissionDenied: false,
          connectedSerial: null,
          errorMessage: null,
        );

      case BciPermissionDenied():
        return acc.copyWith(
          stage: BciPairingStage.discovery,
          isScanning: false,
          isConnecting: false,
          isBluetoothPermissionDenied: true,
          batteryPercent: null,                      // cleared via _undefined sentinel
          errorMessage: null,
        );

      case BciConnecting(:final serial):
        return acc.copyWith(
          stage: BciPairingStage.discovery,
          isScanning: false,
          isConnecting: true,
          connectedSerial: serial,
          errorMessage: null,
        );

      case BciImpedance(:final serial):
        return acc.copyWith(
          stage: BciPairingStage.impedance,
          isScanning: false,
          isConnecting: false,
          connectedSerial: serial,
          errorMessage: null,
        );

      case BciCalibrating(:final serial, :final totalStages):
        return acc.copyWith(
          stage: BciPairingStage.calibrating,
          isScanning: false,
          isConnecting: false,
          connectedSerial: serial,
          errorMessage: null,
          calibration: BciCalibrationProgressDTO(
            stagesCompleted: 0,
            isComplete: false,
            failed: false,
            totalStages: totalStages,
          ),
        );

      case BciReady(:final serial):
        return acc.copyWith(
          stage: BciPairingStage.ready,
          isScanning: false,
          isConnecting: false,
          connectedSerial: serial,
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
            failed: false,
            failReason: acc.calibration?.failReason,
            totalStages: acc.calibration?.totalStages ?? 4,
          ),
        );

      case BciCalibrationCompleted(:final data):
        if (data.isValid) {
          return acc.copyWith(
            calibration: BciCalibrationProgressDTO(
              stagesCompleted: acc.calibration?.stagesCompleted ?? 0,
              isComplete: true,
              failed: false,
              totalStages: acc.calibration?.totalStages ?? 4,
            ),
          );
        } else {
          return acc.copyWith(
            calibration: BciCalibrationProgressDTO(
              stagesCompleted: acc.calibration?.stagesCompleted ?? 0,
              isComplete: false,
              failed: true,
              failReason: data.failReason,
              totalStages: acc.calibration?.totalStages ?? 4,
            ),
          );
        }

      case BciCalibrationFailed(:final reason):
        return acc.copyWith(
          calibration: BciCalibrationProgressDTO(
            stagesCompleted: acc.calibration?.stagesCompleted ?? 0,
            isComplete: false,
            failed: true,
            failReason: reason,
            totalStages: acc.calibration?.totalStages ?? 4,
          ),
        );
    }
  }
}
