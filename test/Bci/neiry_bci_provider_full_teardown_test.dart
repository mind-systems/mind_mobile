// B2 · Characterization: full teardown chain (L1 + classifier-disposal ordering)
//
// Pins the full unexpected-drop teardown chain in NeiryBciProvider:
// - A throwing cancel/classifier-dispose/device-disconnect/device-dispose anywhere
//   in the chain still reaches the locator recreate (L1 invariant).
// - The canonical teardown unit never splits or reorders.
//
// No production-code assertions; all assertions reference observable counts,
// order labels, and wait-ordering so the suite stays green through C1.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:mind/Bci/NeiryBciProvider.dart';
import 'package:mind/Bci/Models/BciChannelQuality.dart';
import 'package:mind/Bci/Models/BciDeviceInfo.dart';
import 'package:mind/Bci/Models/BciEmotionsData.dart';
import 'package:mind/Bci/Models/BciLinkStatus.dart';
import 'package:mind/Bci/Models/BciNfbData.dart';
import 'package:mind/Bci/Ports/ClassifierSet.dart';
import 'package:mind/Bci/Ports/DevicePort.dart';
import 'package:mind/Bci/Ports/LocatorPort.dart';
import 'package:mind/Biometrics/Models/CardioData.dart';
import 'package:mind/Biometrics/Models/MotionData.dart';
import 'package:mind/Biometrics/Models/RrInterval.dart';

// ── TeardownOrder ─────────────────────────────────────────────────────────────

/// Shared recorder threaded through all fakes.
/// Each fake appends its step label at the moment the relevant call executes.
class TeardownOrder {
  final List<String> steps = [];
}

// ── ThrowOnCancelStream / _ControllableCancelSubscription ────────────────────

/// Wraps a broadcast stream and returns a subscription whose cancel() can:
/// - append a label to [orderSteps] (if non-null)
/// - throw a StateError after the inner cancel (if [shouldThrow] returns true)
class ThrowOnCancelStream<T> extends Stream<T> {
  final Stream<T> _inner;
  final List<String>? _orderSteps;
  final String _label;
  final bool Function() _shouldThrow;

  ThrowOnCancelStream(
    this._inner, {
    required List<String>? orderSteps,
    required String label,
    required bool Function() shouldThrow,
  })  : _orderSteps = orderSteps,
        _label = label,
        _shouldThrow = shouldThrow;

  @override
  bool get isBroadcast => _inner.isBroadcast;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _ControllableCancelSubscription<T>(
      _inner.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      ),
      _orderSteps,
      _label,
      _shouldThrow,
    );
  }
}

class _ControllableCancelSubscription<T> implements StreamSubscription<T> {
  final StreamSubscription<T> _inner;
  final List<String>? _orderSteps;
  final String _label;
  final bool Function() _shouldThrow;

  _ControllableCancelSubscription(
    this._inner,
    this._orderSteps,
    this._label,
    this._shouldThrow,
  );

  @override
  Future<void> cancel() async {
    if (_orderSteps != null && _label.isNotEmpty) {
      _orderSteps.add(_label);
    }
    await _inner.cancel();
    if (_shouldThrow()) {
      throw StateError('ThrowOnCancelStream: cancel error [$_label]');
    }
  }

  @override
  void onData(void Function(T data)? handleData) => _inner.onData(handleData);

  @override
  void onError(Function? handleError) => _inner.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => _inner.onDone(handleDone);

  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);

  @override
  void resume() => _inner.resume();

  @override
  bool get isPaused => _inner.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture<E>(futureValue);
}

// ── GatedFakeDevicePort ───────────────────────────────────────────────────────

/// Controllable DevicePort for full-teardown characterization.
///
/// - Completers gate timing of each async call (default pre-completed).
/// - throwOn* flags make the call throw after the gate resolves and the step
///   is appended — so the label is always recorded even when the call throws.
/// - connectionStateStream is wrapped in ThrowOnCancelStream so cancel() can
///   record 'cancelFanIn' and optionally throw.
class GatedFakeDevicePort implements DevicePort {
  final _connectionController = StreamController<BciLinkStatus>.broadcast();
  final _resistanceController =
      StreamController<List<BciChannelQuality>>.broadcast();
  final _batteryController = StreamController<int>.broadcast();

  final TeardownOrder _order;

  /// The classifier set owned by this device instance.
  late final FakeClassifierSet classifierSet;

  int connectCallCount = 0;
  int startCallCount = 0;
  int stopStreamCallCount = 0;
  int disconnectCallCount = 0;
  int disposeCallCount = 0;
  bool _isStarted = false;

  bool throwOnConnectionCancel = false;
  bool throwOnDisconnect = false;
  bool throwOnDispose = false;

  Completer<void> stopStreamCompleter = Completer()..complete();
  Completer<void> disconnectCompleter = Completer()..complete();
  Completer<void> disposeCompleter = Completer()..complete();

  GatedFakeDevicePort(this._order) {
    classifierSet = FakeClassifierSet(_order);
  }

  @override
  bool get isStarted => _isStarted;

  @override
  Stream<BciLinkStatus> get connectionStateStream => ThrowOnCancelStream(
        _connectionController.stream,
        orderSteps: _order.steps,
        label: 'cancelFanIn',
        shouldThrow: () => throwOnConnectionCancel,
      );

  @override
  Stream<List<BciChannelQuality>> get resistanceStream =>
      _resistanceController.stream;

  @override
  Stream<int> get batteryStream => _batteryController.stream;

  @override
  Future<void> connect() async {
    connectCallCount++;
  }

  @override
  Future<void> start() async {
    startCallCount++;
    _isStarted = true;
  }

  @override
  Future<void> stopStream() async {
    stopStreamCallCount++;
    _isStarted = false;
    await stopStreamCompleter.future;
    _order.steps.add('stopStream');
  }

  @override
  Future<void> disconnect() async {
    disconnectCallCount++;
    await disconnectCompleter.future;
    _order.steps.add('deviceDisconnect');
    if (throwOnDisconnect) {
      throw StateError('GatedFakeDevicePort: disconnect error');
    }
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    await disposeCompleter.future;
    _order.steps.add('deviceDispose');
    if (throwOnDispose) {
      throw StateError('GatedFakeDevicePort: dispose error');
    }
    _connectionController.close();
    _resistanceController.close();
    _batteryController.close();
  }

  void emitConnection(BciLinkStatus status) =>
      _connectionController.add(status);

  /// Force-close stream controllers (for test teardown when dispose threw or
  /// was skipped due to a throw in disconnect/cancel).
  void closeControllers() {
    if (!_connectionController.isClosed) _connectionController.close();
    if (!_resistanceController.isClosed) _resistanceController.close();
    if (!_batteryController.isClosed) _batteryController.close();
  }

  @override
  ClassifierSet buildClassifierSet() => classifierSet;
}

// ── FakeClassifierSet ─────────────────────────────────────────────────────────

/// A3-variant ClassifierSet with:
/// - bool throwOnDispose + disposeCallCount (A3 contract)
/// - bool throwOnNfbCancel (nfbStateStream wrapped in ThrowOnCancelStream)
/// - closeControllers() (for cleanup when dispose threw before closing)
/// - TeardownOrder recording: dispose() appends 'classifierDispose'
class FakeClassifierSet implements ClassifierSet {
  final _nfbStateController = StreamController<BciNfbData>.broadcast();
  final _nfbErrorController = StreamController<String>.broadcast();
  final _cardioStateController = StreamController<CardioData>.broadcast();
  final _rrController = StreamController<RrInterval>.broadcast();
  final _emotionsStateController = StreamController<BciEmotionsData>.broadcast();
  final _emotionsErrorController = StreamController<String>.broadcast();
  final _motionController = StreamController<MotionData>.broadcast();

  final TeardownOrder _order;
  int disposeCallCount = 0;
  bool throwOnDispose = false;
  bool throwOnNfbCancel = false;

  FakeClassifierSet(this._order);

  @override
  Stream<BciNfbData> get nfbStateStream => ThrowOnCancelStream(
        _nfbStateController.stream,
        orderSteps: null,
        label: '',
        shouldThrow: () => throwOnNfbCancel,
      );

  @override
  Stream<String> get nfbErrorStream => _nfbErrorController.stream;

  @override
  Stream<CardioData> get cardioStateStream => _cardioStateController.stream;

  @override
  Stream<RrInterval> get rrStream => _rrController.stream;

  @override
  Stream<BciEmotionsData> get emotionsStateStream =>
      _emotionsStateController.stream;

  @override
  Stream<String> get emotionsErrorStream => _emotionsErrorController.stream;

  @override
  Stream<MotionData> get motionStream => _motionController.stream;

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    _order.steps.add('classifierDispose');
    if (throwOnDispose) {
      throw StateError('FakeClassifierSet: dispose error');
    }
    _nfbStateController.close();
    _nfbErrorController.close();
    _cardioStateController.close();
    _rrController.close();
    _emotionsStateController.close();
    _emotionsErrorController.close();
    _motionController.close();
  }

  /// Force-close all broadcast controllers (for cleanup when dispose threw
  /// before it could close them).
  void closeControllers() {
    if (!_nfbStateController.isClosed) _nfbStateController.close();
    if (!_nfbErrorController.isClosed) _nfbErrorController.close();
    if (!_cardioStateController.isClosed) _cardioStateController.close();
    if (!_rrController.isClosed) _rrController.close();
    if (!_emotionsStateController.isClosed) _emotionsStateController.close();
    if (!_emotionsErrorController.isClosed) _emotionsErrorController.close();
    if (!_motionController.isClosed) _motionController.close();
  }
}

// ── RecordingLocatorPort ──────────────────────────────────────────────────────

/// LocatorPort that records every call, vends fresh GatedFakeDevicePorts,
/// and appends 'locatorDispose' to the shared TeardownOrder on dispose().
///
/// double-dispose throws StateError (mirrors the real adapter contract).
class RecordingLocatorPort implements LocatorPort {
  final TeardownOrder _order;

  RecordingLocatorPort(this._order);

  int requestDevicesCallCount = 0;
  int createDeviceCallCount = 0;
  int disposeCount = 0;

  /// Replaceable Completer — hold open to block dispose().
  Completer<void> disposeCompleter = Completer()..complete();

  /// Replaceable Completer — hold open to block createDevice().
  Completer<void> createDeviceCompleter = Completer()..complete();

  final _devicesController = StreamController<List<BciDeviceInfo>>();

  GatedFakeDevicePort? lastCreatedDevice;

  @override
  Stream<List<BciDeviceInfo>> requestDevices({
    BciScanDeviceType type = BciScanDeviceType.headband,
    int searchTime = 5,
  }) {
    requestDevicesCallCount++;
    return _devicesController.stream;
  }

  @override
  Future<DevicePort> createDevice(String serial) async {
    createDeviceCallCount++;
    await createDeviceCompleter.future;
    final device = GatedFakeDevicePort(_order);
    lastCreatedDevice = device;
    return device;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    if (disposeCount > 1) {
      throw StateError('RecordingLocatorPort: double-dispose');
    }
    await disposeCompleter.future;
    _order.steps.add('locatorDispose');
    if (!_devicesController.isClosed) _devicesController.close();
  }

  void emitDevices(List<BciDeviceInfo> devices) =>
      _devicesController.add(devices);
}

// ── RecordingLocatorRegistry ──────────────────────────────────────────────────

/// Tracks every RecordingLocatorPort vended by locatorFactory.
///
/// When a replacement locator is created (instances is non-empty), appends
/// 'locatorCreate' to the shared TeardownOrder.
class RecordingLocatorRegistry {
  final List<RecordingLocatorPort> instances = [];
  bool _orphanDetected = false;
  final TeardownOrder order;

  late final LocatorPort Function() locatorFactory;

  RecordingLocatorRegistry(this.order) {
    locatorFactory = () {
      if (instances.isNotEmpty && instances.last.disposeCount == 0) {
        _orphanDetected = true;
      }
      // L0 is vended while instances is empty; 'locatorCreate' marks replacements.
      if (instances.isNotEmpty) {
        order.steps.add('locatorCreate');
      }
      final port = RecordingLocatorPort(order);
      instances.add(port);
      return port;
    };
  }

  int get createdCount => instances.length;

  int get liveCount => instances.where((p) => p.disposeCount == 0).length;

  void assertNoOrphan() {
    expect(
      _orphanDetected,
      isFalse,
      reason: 'A locator was replaced without first being disposed',
    );
    for (int i = 0; i < instances.length - 1; i++) {
      expect(
        instances[i].disposeCount,
        greaterThan(0),
        reason: 'Locator at index $i was never disposed before replacement',
      );
    }
  }
}

// ── _DropSetup ────────────────────────────────────────────────────────────────

class _DropSetup {
  final NeiryBciProvider provider;
  final RecordingLocatorRegistry registry;
  final RecordingLocatorPort l0;
  final GatedFakeDevicePort device;
  final FakeClassifierSet classifierSet;
  final TeardownOrder order;

  _DropSetup({
    required this.provider,
    required this.registry,
    required this.l0,
    required this.device,
    required this.classifierSet,
    required this.order,
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Builds a NeiryBciProvider, drives connect() to success, then emits an
/// unexpected drop — leaving the teardown Completers open (test controls timing).
///
/// After this returns:
/// - _teardownComplete microtask is scheduled and in-flight
/// - device.stopStreamCompleter / disconnectCompleter / disposeCompleter are
///   fresh unsettled Completers
/// - l0.disposeCompleter is a fresh unsettled Completer
Future<_DropSetup> _connectThenDrop({String serial = 'TEST-001'}) async {
  final order = TeardownOrder();
  final registry = RecordingLocatorRegistry(order);
  final provider = NeiryBciProvider(
    locatorFactory: registry.locatorFactory,
  );

  final l0 = registry.instances.first;

  await provider.connect(serial);
  final device = l0.lastCreatedDevice!;

  // Replace Completers with fresh (unsettled) ones so the teardown microtask
  // blocks and the test controls when each step proceeds.
  device.stopStreamCompleter = Completer();
  device.disconnectCompleter = Completer();
  device.disposeCompleter = Completer();
  l0.disposeCompleter = Completer();

  device.emitConnection(BciLinkStatus.down);
  // Let the listener run so _teardownComplete is assigned.
  await Future<void>.delayed(Duration.zero);

  return _DropSetup(
    provider: provider,
    registry: registry,
    l0: l0,
    device: device,
    classifierSet: device.classifierSet,
    order: order,
  );
}

/// Completes all held teardown gates in the canonical sequence and waits for
/// teardown to finish (mirrors B1's _completeTeardown).
Future<void> _completeTeardown(_DropSetup s) async {
  s.device.stopStreamCompleter.complete();
  await Future<void>.delayed(Duration.zero);
  s.device.disconnectCompleter.complete();
  await Future<void>.delayed(Duration.zero);
  s.device.disposeCompleter.complete();
  await Future<void>.delayed(Duration.zero);
  s.l0.disposeCompleter.complete();
  await Future<void>.delayed(Duration.zero);
}

/// Variant of _connectThenDrop where all gates are pre-completed — the full
/// teardown chain runs to completion on the first event-loop pump after the
/// drop. Used by ordering probes.
Future<_DropSetup> _connectThenDropRunToCompletion(
    {String serial = 'TEST-001'}) async {
  final order = TeardownOrder();
  final registry = RecordingLocatorRegistry(order);
  final provider = NeiryBciProvider(
    locatorFactory: registry.locatorFactory,
  );

  final l0 = registry.instances.first;

  await provider.connect(serial);
  final device = l0.lastCreatedDevice!;

  // All Completers are pre-completed from construction — no gating needed.
  device.emitConnection(BciLinkStatus.down);

  // All teardown microtasks drain before the timer fires.
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero); // safety margin

  return _DropSetup(
    provider: provider,
    registry: registry,
    l0: l0,
    device: device,
    classifierSet: device.classifierSet,
    order: order,
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Phase 2: L1 — thrown teardown still reaches recreate ──────────────────

  group('Phase 2 — L1 thrown teardown still recreates', () {
    test(
      'throwing classifier dispose: swallowed by gate; '
      'device disconnect/dispose still run; recreate reached',
      () async {
        final s = await _connectThenDrop();
        s.classifierSet.throwOnDispose = true;

        await _completeTeardown(s);

        // L1 invariant: L0 disposed, fresh L1 created, no orphan.
        expect(s.registry.createdCount, 2,
            reason: 'L0 + L1 created; recreate reached despite throwing dispose');
        expect(s.l0.disposeCount, 1, reason: 'L0 disposed exactly once');
        expect(s.registry.liveCount, 1, reason: 'only L1 is live');
        s.registry.assertNoOrphan();

        // throwOnDispose = true means dispose() threw before closing classifier
        // controllers — close them manually to avoid open-controller flakiness.
        s.classifierSet.closeControllers();

        s.provider.dispose();
        await Future<void>.delayed(Duration.zero);
      },
    );

    test(
      'throwing device disconnect: swallowed by gate; dispose() skipped; '
      'recreate reached',
      () async {
        final s = await _connectThenDrop();
        s.device.throwOnDisconnect = true;

        await _completeTeardown(s);

        expect(s.registry.createdCount, 2,
            reason: 'recreate reached despite throwing disconnect');
        expect(s.l0.disposeCount, 1);
        expect(s.registry.liveCount, 1);
        s.registry.assertNoOrphan();

        // disconnect() threw → dispose() was skipped (same try-block) →
        // device controllers were never closed.
        s.device.closeControllers();

        s.provider.dispose();
        await Future<void>.delayed(Duration.zero);
      },
    );

    test(
      'throwing device dispose: swallowed by gate; recreate reached',
      () async {
        final s = await _connectThenDrop();
        s.device.throwOnDispose = true;

        await _completeTeardown(s);

        expect(s.registry.createdCount, 2,
            reason: 'recreate reached despite throwing device dispose');
        expect(s.l0.disposeCount, 1);
        expect(s.registry.liveCount, 1);
        s.registry.assertNoOrphan();

        // dispose() threw before closing device controllers.
        s.device.closeControllers();

        s.provider.dispose();
        await Future<void>.delayed(Duration.zero);
      },
    );

    test(
      'throwing connection-sub cancel: propagates to finally; '
      'recreate still reached; throwing cancel is logged and swallowed, '
      'no unhandled async error',
      () async {
        // Zone binding: connect() must run in the same zone as the test body so
        // the stream listener is registered in that zone. The teardown microtask
        // runs in the listener-time zone; the broadened catchError now catches the
        // throw and logs it — no unhandled zone rejection is produced.
        final asyncErrors = <Object>[];

        final order = TeardownOrder();
        final registry = RecordingLocatorRegistry(order);
        final provider = NeiryBciProvider(
          locatorFactory: registry.locatorFactory,
        );
        final l0 = registry.instances.first;

        await runZonedGuarded(
          () async {
            // connect() inside the zone — listener is registered here.
            await provider.connect('TEST-001');

            final device = l0.lastCreatedDevice!;
            device.throwOnConnectionCancel = true;

            // Gate only the steps that the throwing-cancel path actually awaits:
            // stopStream (runs before the throw) and locatorDispose (runs in finally).
            device.stopStreamCompleter = Completer();
            l0.disposeCompleter = Completer();

            device.emitConnection(BciLinkStatus.down);
            await Future<void>.delayed(Duration.zero); // microtask starts

            // Release stopStream → microtask proceeds → connectionSub.cancel() throws.
            device.stopStreamCompleter.complete();
            await Future<void>.delayed(Duration.zero); // cancel throws → finally runs

            // Release locator dispose → _resetLocatorSession() completes.
            l0.disposeCompleter.complete();
            await Future<void>.delayed(Duration.zero); // locatorDispose + locatorCreate
            await Future<void>.delayed(Duration.zero); // microtask future rejects
            await Future<void>.delayed(Duration.zero); // rejection → zone handler
          },
          (error, stack) => asyncErrors.add(error),
        );

        // L1 invariant: recreate reached despite the throwing cancel.
        expect(registry.createdCount, 2,
            reason: 'locator recreated despite throwing connection-sub cancel');
        expect(l0.disposeCount, 1, reason: 'L0 disposed exactly once');
        expect(registry.liveCount, 1, reason: 'only L1 is live');
        registry.assertNoOrphan();

        // The injected StateError is now caught by the broadened catchError,
        // logged via logPrint, and swallowed — no unhandled async error reaches the zone.
        expect(asyncErrors, isEmpty,
            reason: 'throwing cancel is now logged and swallowed, not surfaced as an unhandled async error');

        // cancel() threw after the inner cancel, so _connectionSub is cancelled.
        // But the remaining 9 fan-in subs and classifierSet were never
        // cancelled/disposed — their controllers are still open.
        final originalDevice = l0.lastCreatedDevice;
        originalDevice?.closeControllers();
        originalDevice?.classifierSet.closeControllers();

        provider.dispose();
        await Future<void>.delayed(Duration.zero);
      },
    );
  });

  // ── Phase 3: classifier-disposal ordering ─────────────────────────────────

  group('Phase 3 — classifier-disposal ordering', () {
    test(
      'pure drop: canonical teardown unit is complete and in order',
      () async {
        final s = await _connectThenDropRunToCompletion();

        // Canonical unit: all 7 steps in exact order.
        expect(
          s.order.steps,
          equals([
            'stopStream',
            'cancelFanIn',
            'classifierDispose',
            'deviceDisconnect',
            'deviceDispose',
            'locatorDispose',
            'locatorCreate',
          ]),
          reason: 'teardown unit must be complete and in canonical order',
        );

        expect(s.registry.createdCount, 2);
        expect(s.l0.disposeCount, 1);
        expect(s.registry.liveCount, 1);
        s.registry.assertNoOrphan();

        s.provider.dispose();
        await Future<void>.delayed(Duration.zero);
      },
    );

    test(
      'drop + concurrent disconnect: drop teardown sub-sequence is contiguous '
      'and correctly ordered; no orphan at any point',
      () async {
        final s = await _connectThenDrop();

        // Start disconnect() while teardown is in-flight.
        // disconnect() awaits _teardownComplete, so it queues behind the drop.
        final disconnectFuture = s.provider.disconnect();
        await Future<void>.delayed(Duration.zero);

        // Complete the drop teardown gates in canonical order.
        await _completeTeardown(s);

        // disconnect() proceeds after _teardownComplete resolves.
        await disconnectFuture;

        // Assert the canonical drop sub-sequence appears as a contiguous,
        // correctly-ordered block at the start of the step list.
        const dropSeq = [
          'stopStream',
          'cancelFanIn',
          'classifierDispose',
          'deviceDisconnect',
          'deviceDispose',
          'locatorDispose',
          'locatorCreate',
        ];

        final steps = s.order.steps;

        bool foundContiguous = false;
        for (int i = 0; i <= steps.length - dropSeq.length; i++) {
          if (steps.sublist(i, i + dropSeq.length).join(',') ==
              dropSeq.join(',')) {
            foundContiguous = true;
            break;
          }
        }
        expect(
          foundContiguous,
          isTrue,
          reason: 'drop teardown sub-sequence must appear as a contiguous, '
              'ordered unit; got: $steps',
        );

        // Churn caveat: disconnect() calls _resetLocatorSession() again →
        // liveCount ≤ 1, no orphan (no two live locators at any point).
        expect(s.registry.liveCount, lessThanOrEqualTo(1));
        s.registry.assertNoOrphan();

        s.provider.dispose();
        await Future<void>.delayed(Duration.zero);
      },
    );
  });
}
