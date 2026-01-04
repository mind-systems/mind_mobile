import 'package:flutter/foundation.dart';

void logPrint(Object? object) {
  final now = DateTime.now();
  final time = '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}.'
      '${(now.millisecond ~/ 10).toString().padLeft(2, '0')}';
  debugPrint('[$time] $object');
}
