import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:bci_module/bci_module.dart' show IBciPairingCoordinator;

class BciPairingCoordinator implements IBciPairingCoordinator {
  final BuildContext context;

  BciPairingCoordinator(this.context);

  @override
  void close() {
    if (!context.mounted) return;
    context.pop();
  }
}
