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
///
/// [dispose] cancels the subscription. It exists as a test seam — production
/// code does not call it because this coordinator lives for the app's lifetime.
class KeepAliveCoordinator {
  KeepAliveCoordinator({
    required ForegroundKeepAlive foregroundKeepAlive,
    required Stream<ModuleStateEvent> moduleStateEvents,
    bool Function() isAndroid = _platformIsAndroid,
  })  : _foregroundKeepAlive = foregroundKeepAlive,
        _isAndroid = isAndroid() {
    if (!_isAndroid) return;
    _subscription = moduleStateEvents.listen(_onEvent);
  }

  static bool _platformIsAndroid() => Platform.isAndroid;

  final ForegroundKeepAlive _foregroundKeepAlive;
  final bool _isAndroid;
  StreamSubscription<ModuleStateEvent>? _subscription;

  void dispose() => _subscription?.cancel();

  /// Starts or stops the foreground service in response to the breath
  /// activity's local [isLive] edge. No-op on iOS.
  Future<void> onLocalLifecycle(bool isLive) async {
    if (!_isAndroid) return;
    if (isLive) {
      await _foregroundKeepAlive.start();
    } else {
      await _foregroundKeepAlive.stop();
    }
  }

  Future<void> _onEvent(ModuleStateEvent event) async {
    switch (event) {
      case ModuleSessionStarted():
        await _foregroundKeepAlive.start();
      case ModuleSessionEnded():
        await _foregroundKeepAlive.stop();
      case ModuleSessionAbandoned():
        await _foregroundKeepAlive.stop();
      case SessionTerminated():
        await _foregroundKeepAlive.stop();
      case ModuleSessionResumed():
        break;
      case ModuleSessionPaused():
        break;
      case ModuleSessionUnpaused():
        break;
    }
  }
}
