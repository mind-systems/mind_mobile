import 'dart:async';

import 'package:mind/Core/Socket/LiveSocketService.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/UserNotifier.dart';

class SocketConnectionCoordinator {
  final LiveSocketService _liveSocketService;
  late final StreamSubscription<AuthState> _subscription;

  SocketConnectionCoordinator({
    required UserNotifier userNotifier,
    required LiveSocketService liveSocketService,
  }) : _liveSocketService = liveSocketService {
    _subscription = userNotifier.stream.listen((state) {
      if (state is AuthenticatedState) {
        _liveSocketService.connect();
      } else if (state is GuestState) {
        _liveSocketService.disconnect();
      }
    });
  }

  void dispose() {
    _subscription.cancel();
  }
}
