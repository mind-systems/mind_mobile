import 'package:flutter/foundation.dart';

abstract class IProfileCoordinator {
  void logout();

  void showThemePicker({
    required List<String> keys,
    required int selectedIndex,
    required ValueChanged<int> onSelect,
  });

  void showLanguagePicker({
    required List<String> keys,
    required int selectedIndex,
    required ValueChanged<int> onSelect,
  });
}
