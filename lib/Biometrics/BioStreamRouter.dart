import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'BioSample.dart';
import 'IHeartRateSource.dart';
import 'IRrIntervalSource.dart';
import 'IEegBandsSource.dart';
import 'IEmotionsSource.dart';
import 'IMotionSource.dart';

/// Merge point between per-capability biometric sources and the downstream
/// [BiometricBatcher].
///
/// Each capability has its own registration list. A source is appended on every
/// [register*] call — no dedup, no re-registration check — because each
/// [BioSample] already carries a `source` tag that the server uses to
/// distinguish origins (e.g. Neiry vs a future Garmin HR source emitting in
/// parallel).
///
/// The merged broadcast stream is built lazily on the first read of [samples]
/// and cached. Any subsequent [register*] call invalidates the cache so the
/// next read rebuilds the merge with the updated source list.
///
/// **Invariant:** register every source *before* the first subscriber reads
/// [samples]. Once cached, already-subscribed consumers stay bound to the old
/// merge and will not pick up newly added sources. `App.initialize()` honors
/// this naturally — all [register*] calls happen before [BiometricBatcher] is
/// constructed and subscribes.
class BioStreamRouter {
  final List<IHeartRateSource> _heartRates = [];
  final List<IRrIntervalSource> _rrIntervals = [];
  final List<IEegBandsSource> _eegBands = [];
  final List<IEmotionsSource> _emotions = [];
  final List<IMotionSource> _motions = [];

  Stream<BioSample>? _merged;

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  /// Registers [source] as a heart-rate provider and invalidates the cache.
  void registerHeartRateSource(IHeartRateSource source) {
    _heartRates.add(source);
    _merged = null;
  }

  /// Registers [source] as an RR-interval provider and invalidates the cache.
  void registerRrIntervalSource(IRrIntervalSource source) {
    _rrIntervals.add(source);
    _merged = null;
  }

  /// Registers [source] as an EEG-bands provider and invalidates the cache.
  void registerEegBandsSource(IEegBandsSource source) {
    _eegBands.add(source);
    _merged = null;
  }

  /// Registers [source] as an emotions provider and invalidates the cache.
  void registerEmotionsSource(IEmotionsSource source) {
    _emotions.add(source);
    _merged = null;
  }

  /// Registers [source] as a motion provider and invalidates the cache.
  void registerMotionSource(IMotionSource source) {
    _motions.add(source);
    _merged = null;
  }

  // ---------------------------------------------------------------------------
  // Output
  // ---------------------------------------------------------------------------

  /// A broadcast stream of all [BioSample]s from every registered source.
  ///
  /// Built lazily on first read. Capabilities with no registered sources
  /// contribute nothing to the merge. Multiple sources for the same capability
  /// (e.g. two HR providers) are merged in parallel — the server is responsible
  /// for any comparison, averaging, or artifact-rejection policy.
  ///
  /// See class-level dartdoc for the register-before-subscribe invariant.
  Stream<BioSample> get samples {
    if (_merged != null) return _merged!;

    final streams = <Stream<BioSample>>[
      for (final s in _heartRates) s.cardioStream.map(BioSample.fromCardio),
      for (final s in _rrIntervals) s.rrStream.map(BioSample.fromRr),
      for (final s in _eegBands) s.nfbStream.map(BioSample.fromNfb),
      for (final s in _emotions) s.emotionsStream.map(BioSample.fromEmotions),
      for (final s in _motions) s.motionStream.map(BioSample.fromMotion),
    ];

    _merged = Rx.merge(streams).asBroadcastStream();
    return _merged!;
  }
}
