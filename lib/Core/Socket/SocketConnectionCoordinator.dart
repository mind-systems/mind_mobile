import 'dart:async';
import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mind/Core/Socket/LiveSocketService.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/UserNotifier.dart';

class SocketConnectionCoordinator {
  final LiveSocketService _liveSocketService;

  bool _isAuthenticated = false;

  late final StreamSubscription<AuthState> _authSubscription;
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  SocketConnectionCoordinator({
    required UserNotifier userNotifier,
    required LiveSocketService liveSocketService,
  }) : _liveSocketService = liveSocketService {
    _authSubscription = userNotifier.stream.listen((state) {
      if (state is AuthenticatedState) {
        log('[SocketCoordinator] auth → authenticated, connecting', name: 'SocketConnectionCoordinator');
        _isAuthenticated = true;
        _liveSocketService.connect();
      } else if (state is GuestState) {
        log('[SocketCoordinator] auth → guest, disconnecting', name: 'SocketConnectionCoordinator');
        _isAuthenticated = false;
        _liveSocketService.disconnect();
      }
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      log('[SocketCoordinator] connectivity changed: $results', name: 'SocketConnectionCoordinator');
      if (results.contains(ConnectivityResult.none)) {
        log('[SocketCoordinator] no connectivity, disconnecting', name: 'SocketConnectionCoordinator');
        _liveSocketService.disconnect();
      } else if (_isAuthenticated) {
        log('[SocketCoordinator] connectivity restored, reconnecting', name: 'SocketConnectionCoordinator');
        _liveSocketService.connect();
      }
    });
  }

  void dispose() {
    _authSubscription.cancel();
    _connectivitySubscription.cancel();
  }
}
