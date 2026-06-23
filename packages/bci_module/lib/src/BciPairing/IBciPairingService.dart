import 'Models/BciPairingState.dart';

sealed class BciPairingServiceEvent {
  const BciPairingServiceEvent();
}

final class BciPairingStateUpdated extends BciPairingServiceEvent {
  final BciPairingState state;

  const BciPairingStateUpdated(this.state);
}

abstract class IBciPairingService {
  Stream<BciPairingServiceEvent> observeChanges();

  void startScan();

  void connectDevice(String serial);

  void startCalibration();

  void startQuickCalibration();

  void disconnect();
}
