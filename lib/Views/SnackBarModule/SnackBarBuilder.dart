import 'package:flutter/material.dart';
import 'Models/SnackBarEvent.dart';
import 'Models/SnackBarType.dart';

class SnackBarBuilder {
  static SnackBar build(SnackBarEvent event) {
    return SnackBar(
      content: Text(
        event.message,
        style: TextStyle(color: _getTextColor(event.type)),
      ),
      backgroundColor: const Color(0xFF1A237E),
      duration: event.duration,
      action: event.action,
    );
  }

  static Color _getTextColor(SnackBarType type) {
    switch (type) {
      case SnackBarType.error:
        return Colors.red;
      case SnackBarType.info:
        return Colors.white;
    }
  }
}
