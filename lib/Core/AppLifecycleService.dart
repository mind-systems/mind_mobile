import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mind/Logger.dart';

class AppLifecycleService {
  final _resumeController = StreamController<void>.broadcast();
  final _pauseController = StreamController<void>.broadcast();
  final _detachController = StreamController<void>.broadcast();
  late final AppLifecycleListener _listener;

  AppLifecycleService() {
    _listener = AppLifecycleListener(onResume: _onResume, onPause: _onPause, onDetach: _onDetach);
  }

  Stream<void> get onResume => _resumeController.stream;
  Stream<void> get onPause => _pauseController.stream;
  Stream<void> get onDetach => _detachController.stream;

  void _onResume() {
    logPrint('[AppLifecycleService] app resumed');
    _resumeController.add(null);
  }

  void _onPause() {
    logPrint('[AppLifecycleService] app paused');
    _pauseController.add(null);
  }

  void _onDetach() {
    logPrint('[AppLifecycleService] app detached');
    _detachController.add(null);
  }

  void dispose() {
    _listener.dispose();
    _resumeController.close();
    _pauseController.close();
    _detachController.close();
  }
}
