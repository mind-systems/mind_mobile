import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'IMeditationListService.dart';
import 'IMeditationListCoordinator.dart';
import 'Models/MeditationListState.dart';

final meditationListViewModelProvider =
    NotifierProvider<MeditationListViewModel, MeditationListState>(() {
      throw UnimplementedError(
        'MeditationListViewModel must be overridden via ProviderScope',
      );
    });

class MeditationListViewModel extends Notifier<MeditationListState> {
  final IMeditationListService service;
  final IMeditationListCoordinator coordinator;

  MeditationListViewModel({required this.service, required this.coordinator});

  @override
  MeditationListState build() => MeditationListState(poses: service.poses());

  void onPoseTap(String id) => coordinator.openSession(id);
}
