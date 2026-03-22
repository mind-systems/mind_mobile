import 'dart:async';
import 'dart:developer';
import 'package:flutter/widgets.dart';

class AppLifecycleService {
  final _resumeController = StreamController<void>.broadcast();
  late final AppLifecycleListener _listener;

  AppLifecycleService() {
    _listener = AppLifecycleListener(onResume: _onResume);
  }

  Stream<void> get onResume => _resumeController.stream;

  void _onResume() {
    log('[AppLifecycleService] app resumed', name: 'AppLifecycleService');
    _resumeController.add(null);
  }

  void dispose() {
    _listener.dispose();
    _resumeController.close();
  }
}
