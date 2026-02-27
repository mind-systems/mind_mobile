import 'package:flutter/foundation.dart' show VoidCallback;

class ModuleItem {
  final String title;
  final String iconPath;
  final VoidCallback onTap;

  const ModuleItem({
    required this.title,
    required this.iconPath,
    required this.onTap,
  });
}
