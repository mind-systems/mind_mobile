import 'Models/BciPairingState.dart';

sealed class BciPairingServiceEvent {
  const BciPairingServiceEvent();
}

final class BciPairingStateUpdated extends BciPairingServiceEvent {
  final BciPairingState state;

  const BciPairingStateUpdated(this.state);
}

/// Service interface for the BCI pairing flow.
///
/// Implementers must derive rolling [BciPairingState] snapshots from the
/// domain notifier stream using a pure stateless reducer (RxDart `scan`).
/// Command methods are fire-and-forget — results arrive via [observeChanges].
abstract class IBciPairingService {
  /// Stream of state snapshots for the BCI pairing flow.
  ///
  /// Each emission carries the full rolling [BciPairingState] derived from
  /// domain events. Subscribe once and react to [BciPairingStateUpdated].
  Stream<BciPairingServiceEvent> observeChanges();

  /// Start scanning for nearby BCI devices.
  void startScan();

  /// Initiate a connection to the device identified by [serial].
  void connectDevice(String serial);

  /// Begin the calibration sequence after a device is connected.
  void startCalibration();

  /// Disconnect the current device and return to discovery.
  void disconnect();
}
