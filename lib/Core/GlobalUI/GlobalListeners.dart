import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/Core/GlobalUI/GlobalKeys.dart';
import 'package:mind/User/LogoutNotifier.dart';
import 'package:mind/Views/SnackBarModule/GlobalSnackBarNotifier.dart';
import 'package:mind/Views/SnackBarModule/Models/SnackBarEvent.dart';
import 'package:mind/Views/SnackBarModule/SnackBarBuilder.dart';

/// Слушает глобальные события приложения и координирует показ UI.
///
/// Обрабатывает:
/// - События снэкбаров через [GlobalSnackBarNotifier]
/// - События логаута через [LogoutNotifier]
///
/// Должен оборачивать корневой виджет приложения.
class GlobalListeners extends ConsumerStatefulWidget {
  final LogoutNotifier logoutNotifier;
  final Stream<String> authErrorStream;
  final Widget child;

  const GlobalListeners({
    required this.logoutNotifier,
    required this.authErrorStream,
    required this.child,
    super.key,
  });

  @override
  ConsumerState<GlobalListeners> createState() => _GlobalListenersState();
}

class _GlobalListenersState extends ConsumerState<GlobalListeners> {
  StreamSubscription<void>? _logoutSubscription;
  StreamSubscription<String>? _authErrorSubscription;

  @override
  void initState() {
    super.initState();
    _logoutSubscription = widget.logoutNotifier.stream.listen((_) {
      _showSnackBar(SnackBarEvent.error('Сессия истекла'));
    });

    _authErrorSubscription = widget.authErrorStream.listen((error) {
      _showSnackBar(SnackBarEvent.error('Ошибка входа: $error'));
    });
  }

  @override
  void dispose() {
    _logoutSubscription?.cancel();
    _authErrorSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SnackBarEvent?>(globalSnackBarNotifierProvider, (
      previous,
      next,
    ) {
      if (next != null) {
        _showSnackBar(next);
      }
    });

    return widget.child;
  }

  void _showSnackBar(SnackBarEvent event) {
    final snackBar = SnackBarBuilder.build(event);
    rootScaffoldMessengerKey.currentState?.showSnackBar(snackBar);
  }
}
