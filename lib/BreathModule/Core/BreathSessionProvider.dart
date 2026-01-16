import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/BreathModule/Core/BreathSessionRepository.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';

class BreathSessionNotifier extends Notifier<List<BreathSession>> {
  final BreathSessionRepository repository;

  BreathSessionNotifier({required this.repository});

  @override
  List<BreathSession> build() {
    return [];
  }

  Future<void> load(int page, int pageSize) async {
    final sessions = await repository.fetch(page, pageSize);
    state = sessions;
  }

  Future<void> save(BreathSession session) async {
    await repository.save(session);

    final index = state.indexWhere((s) => s.id == session.id);
    if (index == -1) {
      state = [...state, session];
    } else {
      state = [
        for (final s in state)
          if (s.id == session.id) session else s,
      ];
    }
  }

  Future<void> delete(String id) async {
    await repository.delete(id);
    state = state.where((s) => s.id != id).toList();
  }
}

final breathSessionNotifierProvider =
    NotifierProvider<BreathSessionNotifier, List<BreathSession>>(() {
  throw UnimplementedError(
    'BreathSessionNotifier должен быть передан в ProviderScope',
  );
});
