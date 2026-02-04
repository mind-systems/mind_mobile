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
class GlobalListeners extends ConsumerWidget {
  final Widget child;

  const GlobalListeners({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<SnackBarEvent?>(globalSnackBarNotifierProvider, (
      previous,
      next,
    ) {
      if (next != null) {
        _showSnackBar(next);
      }
    });

    ref.listen<void>(logoutNotifierProvider, (previous, next) {
      _showSnackBar(SnackBarEvent.error('Сессия истекла'));
    });

    return child;
  }

  void _showSnackBar(SnackBarEvent event) {
    final snackBar = SnackBarBuilder.build(event);
    rootScaffoldMessengerKey.currentState?.showSnackBar(snackBar);
  }
}
