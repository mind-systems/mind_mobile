import 'dart:async';

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
  MeditationListState build() {
    final state = MeditationListState(poses: service.poses());
    // Fire-and-forget: assumes build() runs once per screen open (no ref.watch here).
    // If a reactive dependency is ever added to build(), this would re-fire on every rebuild.
    unawaited(service.refresh());
    return state;
  }

  void onPoseTap(String id) => coordinator.openSession(id);
}
