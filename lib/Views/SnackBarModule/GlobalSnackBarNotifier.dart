import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'Models/SnackBarEvent.dart';

class GlobalSnackBarNotifier extends Notifier<SnackBarEvent?> {
  @override
  SnackBarEvent? build() => null;

  void show(SnackBarEvent event) {
    state = event;
    Future.delayed(Duration.zero, () {
      state = null;
    });
  }
}

final globalSnackBarNotifierProvider =
    NotifierProvider<GlobalSnackBarNotifier, SnackBarEvent?>(
      () => GlobalSnackBarNotifier(),
    );
