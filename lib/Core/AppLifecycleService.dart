import 'dart:async';
import 'dart:developer';
import 'package:flutter/widgets.dart';

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
    log('[AppLifecycleService] app resumed', name: 'AppLifecycleService');
    _resumeController.add(null);
  }

  void _onPause() {
    log('[AppLifecycleService] app paused', name: 'AppLifecycleService');
    _pauseController.add(null);
  }

  void _onDetach() {
    log('[AppLifecycleService] app detached', name: 'AppLifecycleService');
    _detachController.add(null);
  }

  void dispose() {
    _listener.dispose();
    _resumeController.close();
    _pauseController.close();
    _detachController.close();
  }
}
