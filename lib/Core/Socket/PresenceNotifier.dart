import 'package:flutter/widgets.dart';
import 'package:rxdart/rxdart.dart';

import 'package:mind/Core/Socket/LiveSocketService.dart';
import 'package:mind/Core/Socket/PresenceStatus.dart';

class PresenceNotifier with WidgetsBindingObserver {
  final LiveSocketService _liveSocketService;

  final _status = BehaviorSubject<PresenceStatus>.seeded(PresenceStatus.online);

  Stream<PresenceStatus> get status => _status.stream;

  PresenceNotifier({required LiveSocketService liveSocketService})
      : _liveSocketService = liveSocketService {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _status.add(PresenceStatus.online);
        _liveSocketService.emitLive('presence:foreground');
      case AppLifecycleState.paused:
        _status.add(PresenceStatus.background);
        _liveSocketService.emitLive('presence:background');
      case AppLifecycleState.hidden:
        _status.add(PresenceStatus.background);
        _liveSocketService.emitLive('presence:background');
      case AppLifecycleState.detached:
        _status.add(PresenceStatus.background);
        _liveSocketService.emitLive('presence:background');
      case AppLifecycleState.inactive:
        break;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _status.close();
  }
}
