import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'IBciDataCoordinator.dart';
import 'IBciDataService.dart';
import 'Models/BciDataState.dart';
import 'Models/BciNfbDTO.dart';
import 'Models/BciEmotionsDTO.dart';

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

  // Per-metric running maximums — initialized to 1.0 so values within the
  // SDK contract (0..1) are a no-op; values above 1.0 ratchet the ceiling up.
  double _maxDelta = 1.0;
  double _maxTheta = 1.0;
  double _maxAlpha = 1.0;
  double _maxSmr = 1.0;
  double _maxBeta = 1.0;

  double _maxAttention = 1.0;
  double _maxCognitiveLoad = 1.0;
  double _maxRelaxation = 1.0;
  double _maxCognitiveControl = 1.0;
  double _maxSelfControl = 1.0;

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
        final normalizedNfb = _normalizeNfb(state.nfb);
        final normalizedEmotions = _normalizeEmotions(state.emotions);
        this.state = BciDataState(
          heartRate: state.heartRate,
          channels: state.channels,
          batteryPercent: state.batteryPercent,
          isConnected: state.isConnected,
          nfb: normalizedNfb,
          emotions: normalizedEmotions,
        );
    }
  }

  BciNfbDTO? _normalizeNfb(BciNfbDTO? raw) {
    if (raw == null) return null;
    if (raw.delta != null) _maxDelta = math.max(_maxDelta, raw.delta!);
    if (raw.theta != null) _maxTheta = math.max(_maxTheta, raw.theta!);
    if (raw.alpha != null) _maxAlpha = math.max(_maxAlpha, raw.alpha!);
    if (raw.smr != null) _maxSmr = math.max(_maxSmr, raw.smr!);
    if (raw.beta != null) _maxBeta = math.max(_maxBeta, raw.beta!);
    return BciNfbDTO(
      delta: raw.delta == null ? null : raw.delta! / _maxDelta,
      theta: raw.theta == null ? null : raw.theta! / _maxTheta,
      alpha: raw.alpha == null ? null : raw.alpha! / _maxAlpha,
      smr: raw.smr == null ? null : raw.smr! / _maxSmr,
      beta: raw.beta == null ? null : raw.beta! / _maxBeta,
    );
  }

  BciEmotionsDTO? _normalizeEmotions(BciEmotionsDTO? raw) {
    if (raw == null) return null;
    if (raw.attention != null) _maxAttention = math.max(_maxAttention, raw.attention!);
    if (raw.cognitiveLoad != null) _maxCognitiveLoad = math.max(_maxCognitiveLoad, raw.cognitiveLoad!);
    if (raw.relaxation != null) _maxRelaxation = math.max(_maxRelaxation, raw.relaxation!);
    if (raw.cognitiveControl != null) _maxCognitiveControl = math.max(_maxCognitiveControl, raw.cognitiveControl!);
    if (raw.selfControl != null) _maxSelfControl = math.max(_maxSelfControl, raw.selfControl!);
    return BciEmotionsDTO(
      attention: raw.attention == null ? null : raw.attention! / _maxAttention,
      cognitiveLoad: raw.cognitiveLoad == null ? null : raw.cognitiveLoad! / _maxCognitiveLoad,
      relaxation: raw.relaxation == null ? null : raw.relaxation! / _maxRelaxation,
      cognitiveControl: raw.cognitiveControl == null ? null : raw.cognitiveControl! / _maxCognitiveControl,
      selfControl: raw.selfControl == null ? null : raw.selfControl! / _maxSelfControl,
    );
  }

  void onConnectPressed() => coordinator.openPairing();

  void onHeaderTap() => coordinator.openPairing();
}
