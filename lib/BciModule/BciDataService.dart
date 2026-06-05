import 'package:rxdart/rxdart.dart';
import 'package:bci_module/bci_module.dart';
import 'package:mind/Bci/BciNotifier.dart';
import 'package:mind/Bci/Models/BciNotifierEvent.dart';
import 'package:mind/Bci/Models/BciConnectionState.dart';
import 'package:mind/BciModule/BciChannelQualityMapping.dart';

class BciDataService implements IBciDataService {
  final BciNotifier bciNotifier;

  BciDataService({required this.bciNotifier});

  // NOTE: BciNotifier._subject is a BehaviorSubject — replays only the single
  // most-recent event to new subscribers. We prepend a synthetic
  // BciStateChanged(currentState) so the reducer always seeds connection state
  // correctly regardless of which event happens to be cached.
  @override
  Stream<BciDataEvent> get events {
    return bciNotifier.stream
        .startWith(BciStateChanged(bciNotifier.currentState))
        .scan<BciDataState>(
          (acc, event, _) => _reduce(acc, event),
          BciDataState.initial(),
        )
        .map((state) => BciDataStateUpdated(state));
  }

  // ── Reducer ───────────────────────────────────────────────────────────────

  BciDataState _reduce(BciDataState acc, BciNotifierEvent event) {
    switch (event) {
      case BciNfbUpdated(:final data):
        return acc.copyWith(
          nfb: BciNfbDTO(
            delta: data.delta,
            theta: data.theta,
            alpha: data.alpha,
            smr: data.smr,
            beta: data.beta,
          ),
        );

      case BciCardioUpdated(:final data):
        return acc.copyWith(
          heartRate: (data.metricsAvailable && !data.hasArtifacts)
              ? data.heartRate.round()
              : null,
        );

      case BciEmotionsUpdated(:final data):
        return acc.copyWith(
          emotions: BciEmotionsDTO(
            attention: data.attention,
            cognitiveLoad: data.cognitiveLoad,
            relaxation: data.relaxation,
            cognitiveControl: data.cognitiveControl,
            selfControl: data.selfControl,
          ),
        );

      case BciBatteryUpdated(:final percent):
        return acc.copyWith(batteryPercent: percent);

      case BciSignalQualityUpdated(:final channels):
        return acc.copyWith(channels: mapBciChannelQualities(channels));

      case BciStateChanged(:final state):
        switch (state) {
          case BciConnectionState.disconnected:
          case BciConnectionState.bluetoothPermissionDenied:
            return acc.copyWith(
              isConnected: false,
              heartRate: null,
              nfb: null,
              emotions: null,
              batteryPercent: null,
              channels: const <BciChannelQualityDTO>[],
            );
          case BciConnectionState.scanning:
          case BciConnectionState.connecting:
            return acc.copyWith(isConnected: false);
          case BciConnectionState.impedance:
          case BciConnectionState.calibrating:
          case BciConnectionState.ready:
            return acc.copyWith(isConnected: true);
        }

      case BciDevicesDiscovered():
      case BciCalibrationEventReceived():
      case BciError():
        return acc;
    }
  }
}
