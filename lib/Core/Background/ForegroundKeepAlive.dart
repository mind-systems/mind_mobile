import 'dart:io' show Platform;
import 'dart:ui' show Locale;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:mind_l10n/mind_l10n.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:mind/Logger.dart';

/// Wraps [FlutterForegroundTask] to hold a foreground service for the duration
/// of an active module session, preventing the OS from suspending the isolate.
///
/// Android-only. All methods are no-ops on iOS.
///
/// Constructed with [currentLanguageCode] — a closure returning the locale code
/// used to resolve notification strings. Must not read [App.shared].
class ForegroundKeepAlive {
  ForegroundKeepAlive({required String Function() currentLanguageCode})
      : _currentLanguageCode = currentLanguageCode;

  final String Function() _currentLanguageCode;

  bool _wantRunning = false;
  bool _running = false;

  /// Start the foreground service.
  ///
  /// Idempotent — safe to call when already running.
  /// Requests [Permission.activityRecognition] (required on API 34+ for
  /// health-typed FGS) and [Permission.notification] (non-fatal if denied).
  Future<void> start() async {
    if (!Platform.isAndroid) return;

    _wantRunning = true;
    if (_running) return;

    // --- runtime permissions ---
    final arStatus = await Permission.activityRecognition.request();
    if (arStatus.isDenied || arStatus.isPermanentlyDenied) {
      logPrint('ForegroundKeepAlive: ACTIVITY_RECOGNITION denied ($arStatus) — aborting start');
      return;
    }
    // POST_NOTIFICATIONS — non-fatal
    final notifStatus = await Permission.notification.status;
    if (!notifStatus.isGranted) {
      await Permission.notification.request();
    }

    // --- init ---
    final locale = Locale(_currentLanguageCode());
    final strings = lookupAppLocalizations(locale);
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'mind_keep_alive',
        channelName: 'Session',
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(eventAction: ForegroundTaskEventAction.nothing()),
    );

    // Guard against stop() arriving during the permission/init window.
    if (!_wantRunning) return;

    // --- start service ---
    final result = await FlutterForegroundTask.startService(
      serviceTypes: [ForegroundServiceTypes.health],
      notificationTitle: strings.keepAliveNotificationTitle,
      notificationText: strings.keepAliveNotificationBody,
    );
    switch (result) {
      case ServiceRequestSuccess():
        _running = true;
        logPrint('ForegroundKeepAlive: service started');
      case ServiceRequestFailure(:final error):
        logPrint('ForegroundKeepAlive: start failed — $error');
    }
  }

  /// Stop the foreground service.
  ///
  /// Idempotent — safe to call when not running.
  Future<void> stop() async {
    if (!Platform.isAndroid) return;

    _wantRunning = false;
    if (!_running) return;

    final result = await FlutterForegroundTask.stopService();
    _running = false;
    switch (result) {
      case ServiceRequestSuccess():
        logPrint('ForegroundKeepAlive: service stopped');
      case ServiceRequestFailure(:final error):
        logPrint('ForegroundKeepAlive: stop failed — $error');
    }
  }
}
