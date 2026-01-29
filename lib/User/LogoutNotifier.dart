import 'package:flutter_riverpod/flutter_riverpod.dart';

class LogoutNotifier extends Notifier<void> {
  @override
  void build() {}

  void triggerLogout() {
    ref.notifyListeners();
  }
}

final logoutNotifierProvider = NotifierProvider<LogoutNotifier, void>(() {
  throw UnimplementedError('LogoutNotifier должен быть передан в ProviderScope');
});
