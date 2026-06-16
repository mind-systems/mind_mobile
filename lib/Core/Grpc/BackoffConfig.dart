import 'dart:async';
import 'dart:math';

typedef TimerFactory = Timer Function(Duration duration, void Function() callback);

class BackoffConfig {
  final Duration initialDelay;
  final Duration maxDelay;
  final Random random;

  BackoffConfig({
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    Random? random,
  }) : random = random ?? Random();
}
