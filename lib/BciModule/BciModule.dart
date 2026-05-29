import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bci_module/bci_module.dart';
import 'package:mind/BciModule/BciPairingService.dart';
import 'package:mind/BciModule/BciDataService.dart';
import 'package:mind/BciModule/BciDataCoordinator.dart';
import 'package:mind/Core/App.dart';

class BciModule {
  static Widget buildPairing(BuildContext context) {
    final service = BciPairingService(bciNotifier: App.shared.bciNotifier);
    return ProviderScope(
      overrides: [
        bciPairingViewModelProvider.overrideWith(
          () => BciPairingViewModel(service: service),
        ),
      ],
      child: const BciPairingScreen(),
    );
  }

  static Widget buildDataScreen(BuildContext context) {
    final service = BciDataService(bciNotifier: App.shared.bciNotifier);
    final coordinator = BciDataCoordinator(context);
    return ProviderScope(
      overrides: [
        bciDataViewModelProvider.overrideWith(
          () => BciDataViewModel(service: service, coordinator: coordinator),
        ),
      ],
      child: const BciDataScreen(),
    );
  }
}
