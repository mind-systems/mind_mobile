import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mind/BreathModule/Models/BreathSession.dart';

class BreathSessionNotifier extends Notifier<List<BreathSession>> {

  @override
  List<BreathSession> build() {
    return [];
  }

  Future<void> save(BreathSession session) async {
    print('save: $session');
  }

  Future<void> delete(String id) async {
    print('delete: $id');
  }
}

final breathSessionNotifierProvider = NotifierProvider<BreathSessionNotifier, List<BreathSession>>(() {
  throw UnimplementedError('BreathSessionNotifier должен быть передан в ProviderScope');
});
