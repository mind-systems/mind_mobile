import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/Core/GlobalUI/GlobalKeys.dart';
import 'package:mind_l10n/mind_l10n.dart';
import 'package:mind_ui/mind_ui.dart';

/// Listens to global app events and coordinates UI presentation.
///
/// Handles:
/// - Snackbar events via [GlobalSnackBarNotifier]
/// - Session expiry via [sessionExpiredStream] (fires only when an authenticated
///   session is actually cleared — not for guest 401s)
///
/// Should wrap the root widget of the application.
class GlobalListeners extends ConsumerStatefulWidget {
  final Stream<void> sessionExpiredStream;
  final Widget child;

  const GlobalListeners({
    required this.sessionExpiredStream,
    required this.child,
    super.key,
  });

  @override
  ConsumerState<GlobalListeners> createState() => _GlobalListenersState();
}

class _GlobalListenersState extends ConsumerState<GlobalListeners> {
  StreamSubscription<void>? _sessionExpiredSubscription;

  @override
  void initState() {
    super.initState();
    _sessionExpiredSubscription = widget.sessionExpiredStream.listen((_) {
      _showSnackBar(SnackBarEvent.error(_sessionExpiredMessage()));
    });
  }

  @override
  void dispose() {
    _sessionExpiredSubscription?.cancel();
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

  // Session expiry arrives without UI context (the interceptor fires anywhere),
  // so localization is resolved at show-time from the messenger's own context.
  String _sessionExpiredMessage() {
    const fallback = 'Session expired';
    final context = rootScaffoldMessengerKey.currentContext;
    if (context == null || !context.mounted) return fallback;
    return AppLocalizations.of(context)?.sessionExpired ?? fallback;
  }

  void _showSnackBar(SnackBarEvent event) {
    final snackBar = SnackBarBuilder.build(event);
    rootScaffoldMessengerKey.currentState?.showSnackBar(snackBar);
  }
}
