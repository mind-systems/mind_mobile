import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'IBciDataCoordinator.dart';
import 'IBciDataService.dart';
import 'Models/BciDataState.dart';

final bciDataViewModelProvider =
    NotifierProvider<BciDataViewModel, BciDataState>(() {
  throw UnimplementedError(
    'BciDataViewModel must be overridden via ProviderScope',
  );
});

class BciDataViewModel extends Notifier<BciDataState> {
  final IBciDataService service;
  final IBciDataCoordinator coordinator;

  StreamSubscription<BciDataEvent>? _eventsSubscription;

  BciDataViewModel({
    required this.service,
    required this.coordinator,
  });

  @override
  BciDataState build() {
    ref.onDispose(() {
      _eventsSubscription?.cancel();
      _eventsSubscription = null;
    });
    _eventsSubscription = service.events.listen(_onServiceEvent);
    return BciDataState.initial();
  }

  void _onServiceEvent(BciDataEvent event) {
    switch (event) {
      case BciDataStateUpdated(:final state):
        this.state = state;
    }
  }
}
