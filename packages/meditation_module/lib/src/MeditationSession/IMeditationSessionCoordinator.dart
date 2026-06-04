import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class IMeditationSessionCoordinator {
  Future<void> onSessionStopped();
}

final meditationSessionCoordinatorProvider =
    Provider<IMeditationSessionCoordinator>((_) {
  throw UnimplementedError('must be overridden via ProviderScope');
});
