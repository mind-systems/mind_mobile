import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  StreamSubscription<BciPairingServiceEvent>? _eventsSubscription;

  BciPairingViewModel({required this.service});

  @override
  BciPairingState build() {
    ref.onDispose(() {
      _eventsSubscription?.cancel();
      _eventsSubscription = null;
    });
    return BciPairingState.initial();
  }

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

  /// Starts a new scan. Used by [BciDiscoverySection] after the user grants
  /// Bluetooth permission in Settings and returns to the app.
  void onRescan() => service.startScan();

  void onStartCalibration() => service.startCalibration();

  void onDisconnect() => service.disconnect();
}
