import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/Core/GlobalUI/GlobalKeys.dart';
import 'package:mind_ui/mind_ui.dart';

/// Listens to global app events and coordinates UI presentation.
///
/// Handles:
/// - Snackbar events via [GlobalSnackBarNotifier]
/// - Session expiry via [sessionExpiredStream] (fires only when an authenticated
///   session is actually cleared — not for guest 401s)
/// - Auth errors via [authErrorStream]
///
/// Should wrap the root widget of the application.
class GlobalListeners extends ConsumerStatefulWidget {
  final Stream<void> sessionExpiredStream;
  final Stream<String> authErrorStream;
  final Widget child;

  const GlobalListeners({
    required this.sessionExpiredStream,
    required this.authErrorStream,
    required this.child,
    super.key,
  });

  @override
  ConsumerState<GlobalListeners> createState() => _GlobalListenersState();
}

class _GlobalListenersState extends ConsumerState<GlobalListeners> {
  StreamSubscription<void>? _sessionExpiredSubscription;
  StreamSubscription<String>? _authErrorSubscription;

  @override
  void initState() {
    super.initState();
    _sessionExpiredSubscription = widget.sessionExpiredStream.listen((_) {
      _showSnackBar(SnackBarEvent.error('Сессия истекла'));
    });

    _authErrorSubscription = widget.authErrorStream.listen((error) {
      _showSnackBar(SnackBarEvent.error('Ошибка входа: $error'));
    });
  }

  @override
  void dispose() {
    _sessionExpiredSubscription?.cancel();
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
