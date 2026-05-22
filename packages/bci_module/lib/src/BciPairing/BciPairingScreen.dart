import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'BciPairingViewModel.dart';
import 'Views/BciCalibrationSection.dart';
import 'Views/BciDiscoverySection.dart';
import 'Views/BciImpedanceSection.dart';
import 'Views/BciPairingTopBar.dart';

/// Full-screen BCI device pairing flow — discovery, impedance check, and
/// calibration — driven by [bciPairingViewModelProvider].
class BciPairingScreen extends ConsumerStatefulWidget {
  const BciPairingScreen({super.key});

  static const String name = 'bci_pairing';
  static const String path = '/$name';

  @override
  ConsumerState<BciPairingScreen> createState() => _BciPairingScreenState();
}

class _BciPairingScreenState extends ConsumerState<BciPairingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(bciPairingViewModelProvider.notifier).initState();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BciPairingTopBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              BciDiscoverySection(),
              Divider(height: 1),
              BciImpedanceSection(),
              Divider(height: 1),
              BciCalibrationSection(),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
