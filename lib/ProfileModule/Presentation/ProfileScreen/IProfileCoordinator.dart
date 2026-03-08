import 'package:flutter/foundation.dart';

abstract class IProfileCoordinator {
  void logout();

  void showPicker({
    required String title,
    required List<String> options,
    required int selectedIndex,
    required ValueChanged<int> onSelect,
  });
}
