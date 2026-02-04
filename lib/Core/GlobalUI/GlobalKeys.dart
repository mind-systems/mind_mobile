import 'package:flutter/material.dart';

/// Глобальный ключ для показа SnackBar из любого места приложения.
///
/// Используется в [GlobalListeners] для вызова ScaffoldMessenger без BuildContext.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
