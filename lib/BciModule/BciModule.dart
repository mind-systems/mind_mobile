import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bci_module/bci_module.dart';
import 'package:mind/BciModule/BciPairingService.dart';
import 'package:mind/BciModule/BciPairingCoordinator.dart';
import 'package:mind/Core/App.dart';

class BciModule {
  static Widget buildPairing(BuildContext context) {
    final service = BciPairingService(bciNotifier: App.shared.bciNotifier);
    final coordinator = BciPairingCoordinator(context);
    return ProviderScope(
      overrides: [
        bciPairingViewModelProvider.overrideWith(
          () => BciPairingViewModel(service: service, coordinator: coordinator),
        ),
      ],
      child: const BciPairingScreen(),
    );
  }
}
