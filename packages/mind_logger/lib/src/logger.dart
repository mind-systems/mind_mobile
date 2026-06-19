import 'package:flutter/foundation.dart';
import 'package:observe/observe.dart';

const _logDestination = String.fromEnvironment('LOG_DESTINATION', defaultValue: kDebugMode ? 'both' : 'file');

bool get logToConsole => _logDestination != 'grafana';
bool get logToObserver => _logDestination != 'file';

void logPrint(Object? object) {
  if (logToConsole) {
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${(now.millisecond ~/ 10).toString().padLeft(2, '0')}';
    debugPrint('[$time] $object');
  }
  if (logToObserver) observeSink(object?.toString() ?? '');
}
