import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:bci_module/bci_module.dart' show IBciDataCoordinator, BciPairingScreen;

class BciDataCoordinator implements IBciDataCoordinator {
  final BuildContext context;

  BciDataCoordinator(this.context);

  @override
  void openPairing() {
    if (!context.mounted) return;
    context.push(BciPairingScreen.path);
  }
}
