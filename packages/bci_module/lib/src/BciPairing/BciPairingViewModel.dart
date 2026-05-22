import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'IBciPairingCoordinator.dart';
import 'IBciPairingService.dart';
import 'Models/BciPairingState.dart';

final bciPairingViewModelProvider =
    NotifierProvider<BciPairingViewModel, BciPairingState>(() {
  throw UnimplementedError(
    'BciPairingViewModel must be overridden via ProviderScope',
  );
});

class BciPairingViewModel extends Notifier<BciPairingState> {
  final IBciPairingService service;
  final IBciPairingCoordinator coordinator;

  StreamSubscription<BciPairingServiceEvent>? _eventsSubscription;

  BciPairingViewModel({
    required this.service,
    required this.coordinator,
  });

  @override
  BciPairingState build() {
    ref.onDispose(() => _eventsSubscription?.cancel());
    return BciPairingState.initial();
  }

  /// Called once by the module assembler after the provider scope is created.
  void initState() {
    if (_eventsSubscription != null) return;
    _eventsSubscription = service.observeChanges().listen(_onServiceEvent);
    service.startScan();
  }

  void _onServiceEvent(BciPairingServiceEvent event) {
    switch (event) {
      case BciPairingStateUpdated(:final state):
        this.state = state;
    }
  }

  // ===== User gestures =====

  void onDeviceTap(String serial) => service.connectDevice(serial);

  void onStartCalibration() => service.startCalibration();

  void onDisconnect() => service.disconnect();

  void onClose() => coordinator.close();
}
