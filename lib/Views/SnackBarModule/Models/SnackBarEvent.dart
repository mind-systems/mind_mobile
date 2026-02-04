import 'package:flutter/material.dart';
import 'SnackBarType.dart';

class SnackBarEvent {
  final String message;
  final SnackBarType type;
  final Duration duration;
  final SnackBarAction? action;

  SnackBarEvent({
    required this.message,
    required this.type,
    this.duration = const Duration(seconds: 3),
    this.action,
  });

  static SnackBarEvent error(
    String message, {
    Duration? duration,
    SnackBarAction? action,
  }) {
    return SnackBarEvent(
      message: message,
      type: SnackBarType.error,
      duration: duration ?? const Duration(seconds: 3),
      action: action,
    );
  }

  static SnackBarEvent info(
    String message, {
    Duration? duration,
    SnackBarAction? action,
  }) {
    return SnackBarEvent(
      message: message,
      type: SnackBarType.info,
      duration: duration ?? const Duration(seconds: 3),
      action: action,
    );
  }
}
