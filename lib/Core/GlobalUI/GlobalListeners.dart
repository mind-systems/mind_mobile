import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/Core/GlobalUI/GlobalKeys.dart';
import 'package:mind/Core/Grpc/ModuleStateEvent.dart';
import 'package:mind_l10n/mind_l10n.dart';
import 'package:mind_ui/mind_ui.dart';

/// Listens to global app events and coordinates UI presentation.
///
/// Handles:
/// - Snackbar events via [GlobalSnackBarNotifier]
/// - Session expiry via [sessionExpiredStream] (fires only when an authenticated
///   session is actually cleared — not for guest 401s)
/// - Session abandonment via [sessionAbandonedStream] (fires when the server
///   confirms a session was abandoned while the client believed it was active)
/// - Whole-tree termination via [sessionTerminatedStream] (fires with a
///   [SessionTerminationReason] — the snackbar copy is picked by reason)
/// - Start give-up via [sessionStartFailedStream] (fires when a pending start
///   never confirmed within its retry budget)
///
/// Should wrap the root widget of the application.
class GlobalListeners extends ConsumerStatefulWidget {
  final Stream<void> sessionExpiredStream;
  final Stream<void> sessionAbandonedStream;
  final Stream<SessionTerminationReason> sessionTerminatedStream;
  final Stream<void> sessionStartFailedStream;
  final Widget child;

  const GlobalListeners({
    required this.sessionExpiredStream,
    required this.sessionAbandonedStream,
    required this.sessionTerminatedStream,
    required this.sessionStartFailedStream,
    required this.child,
    super.key,
  });

  @override
  ConsumerState<GlobalListeners> createState() => _GlobalListenersState();
}

class _GlobalListenersState extends ConsumerState<GlobalListeners> {
  StreamSubscription<void>? _sessionExpiredSubscription;
  StreamSubscription<void>? _sessionAbandonedSubscription;
  StreamSubscription<SessionTerminationReason>? _sessionTerminatedSubscription;
  StreamSubscription<void>? _sessionStartFailedSubscription;

  @override
  void initState() {
    super.initState();
    _sessionExpiredSubscription = widget.sessionExpiredStream.listen((_) {
      _showSnackBar(SnackBarEvent.error(_sessionExpiredMessage()));
    });
    _sessionAbandonedSubscription = widget.sessionAbandonedStream.listen((_) {
      _showSnackBar(SnackBarEvent.error(_sessionAbandonedMessage()));
    });
    _sessionTerminatedSubscription = widget.sessionTerminatedStream.listen((reason) {
      switch (reason) {
        case SessionTerminationReason.movedToAnotherDevice:
          _showSnackBar(SnackBarEvent.error(_sessionMovedToAnotherDeviceMessage()));
        case SessionTerminationReason.abandoned:
        case SessionTerminationReason.rootDeath:
          _showSnackBar(SnackBarEvent.error(_sessionAbandonedMessage()));
      }
    });
    _sessionStartFailedSubscription = widget.sessionStartFailedStream.listen((_) {
      _showSnackBar(SnackBarEvent.error(_sessionStartFailedMessage()));
    });
  }

  @override
  void dispose() {
    _sessionExpiredSubscription?.cancel();
    _sessionAbandonedSubscription?.cancel();
    _sessionTerminatedSubscription?.cancel();
    _sessionStartFailedSubscription?.cancel();
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

  String _sessionAbandonedMessage() {
    const fallback = 'Session ended unexpectedly';
    final context = rootScaffoldMessengerKey.currentContext;
    if (context == null || !context.mounted) return fallback;
    return AppLocalizations.of(context)?.sessionAbandoned ?? fallback;
  }

  String _sessionMovedToAnotherDeviceMessage() {
    const fallback = 'Session moved to another device';
    final context = rootScaffoldMessengerKey.currentContext;
    if (context == null || !context.mounted) return fallback;
    return AppLocalizations.of(context)?.sessionMovedToAnotherDevice ?? fallback;
  }

  String _sessionStartFailedMessage() {
    const fallback = "Couldn't start session";
    final context = rootScaffoldMessengerKey.currentContext;
    if (context == null || !context.mounted) return fallback;
    return AppLocalizations.of(context)?.sessionStartFailed ?? fallback;
  }

  void _showSnackBar(SnackBarEvent event) {
    final snackBar = SnackBarBuilder.build(event);
    rootScaffoldMessengerKey.currentState?.showSnackBar(snackBar);
  }
}
