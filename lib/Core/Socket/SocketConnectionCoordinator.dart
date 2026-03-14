import 'dart:async';

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
        _isAuthenticated = true;
        _liveSocketService.connect();
      } else if (state is GuestState) {
        _isAuthenticated = false;
        _liveSocketService.disconnect();
      }
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.none)) {
        _liveSocketService.disconnect();
      } else if (_isAuthenticated) {
        _liveSocketService.connect();
      }
    });
  }

  void dispose() {
    _authSubscription.cancel();
    _connectivitySubscription.cancel();
  }
}
