import 'dart:async';
import 'dart:io' show Platform;

import 'package:mind/Core/Background/ForegroundKeepAlive.dart';
import 'package:mind/Core/Grpc/ModuleStateEvent.dart';

/// Subscribes to [moduleStateEvents] and drives [foregroundKeepAlive] in
/// response to module session lifecycle transitions.
///
/// Android-only. The subscription is a no-op on iOS (background audio handles
/// keep-alive there). Constructed during [App.initialize()] before any session
/// can start, so no [ModuleSessionStarted] event is missed.
class KeepAliveCoordinator {
  KeepAliveCoordinator({
    required ForegroundKeepAlive foregroundKeepAlive,
    required Stream<ModuleStateEvent> moduleStateEvents,
  })  : _foregroundKeepAlive = foregroundKeepAlive {
    if (!Platform.isAndroid) return;
    _subscription = moduleStateEvents.listen(_onEvent);
  }

  final ForegroundKeepAlive _foregroundKeepAlive;
  // ignore: unused_field — held to keep the subscription alive (GC prevention)
  StreamSubscription<ModuleStateEvent>? _subscription;

  void _onEvent(ModuleStateEvent event) {
    switch (event) {
      case ModuleSessionStarted():
        _foregroundKeepAlive.start();
      case ModuleSessionEnded():
        _foregroundKeepAlive.stop();
      case ModuleSessionAbandoned():
        _foregroundKeepAlive.stop();
      case ModuleSessionResumed():
        break;
      case ModuleSessionPaused():
        break;
      case ModuleSessionUnpaused():
        break;
    }
  }
}
