// C1 · Unit tests for SerialCommandQueue and provider-level no-recreate-on-dispose.
//
// Covers the three Verify points from the spec (note 157):
//   1. Serialization — B does not start while A is gated; order after release is
//      A-start → A-end → B-start.
//   2. Poison-pill tail-drop — close() while A is running; B's body never runs
//      and its future completes with StateError; enqueue after close also errors.
//   3. Provider-level no-recreate-on-dispose — dispose() while a drop-teardown is
//      mid-queue does not create an orphaned locator beyond what already existed.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:mind/Bci/NeiryBciProvider.dart';
import 'package:mind/Bci/SerialCommandQueue.dart';
import 'package:mind/Bci/Models/BciChannelQuality.dart';
import 'package:mind/Bci/Models/BciDeviceInfo.dart';
import 'package:mind/Bci/Models/BciEmotionsData.dart';
import 'package:mind/Bci/Models/BciLinkStatus.dart';
import 'package:mind/Bci/Models/BciNfbData.dart';
import 'package:mind/Bci/Ports/ClassifierFactory.dart';
import 'package:mind/Bci/Ports/ClassifierSet.dart';
import 'package:mind/Bci/Ports/DevicePort.dart';
import 'package:mind/Bci/Ports/LocatorPort.dart';
import 'package:mind/Biometrics/Models/CardioData.dart';
import 'package:mind/Biometrics/Models/MotionData.dart';
import 'package:mind/Biometrics/Models/RrInterval.dart';

// ── Queue-only tests ──────────────────────────────────────────────────────────

void main() {
  // ── Serialization ─────────────────────────────────────────────────────────

  group('SerialCommandQueue — serialization', () {
    test(
      'B has not started while A is gated; full order is A-start → A-end → B-start',
      () async {
        final queue = SerialCommandQueue();
        final log = <String>[];
        final gate = Completer<void>();

        queue.enqueue(() async {
          log.add('A-start');
          await gate.future;
          log.add('A-end');
        });

        queue.enqueue(() async {
          log.add('B-start');
        });

        // Let the event loop run — A starts (enqueued on a resolved _tail).
        await Future<void>.delayed(Duration.zero);

        expect(log, equals(['A-start']),
            reason: 'B must not start while A is gated');

        // Release A's gate.
        gate.complete();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero); // B runs after A's slot resolves

        expect(log, equals(['A-start', 'A-end', 'B-start']),
            reason: 'full order must be A-start → A-end → B-start');
      },
    );
  });

  // ── Poison-pill tail-drop ─────────────────────────────────────────────────

  group('SerialCommandQueue — poison-pill tail-drop', () {
    test(
      'close() while A is running: B body never runs, B future → StateError; '
      'enqueue after close also → StateError',
      () async {
        final queue = SerialCommandQueue();
        final log = <String>[];
        final gate = Completer<void>();

        // Enqueue A — gates on the completer.
        final futureA = queue.enqueue(() async {
          log.add('A-body');
          await gate.future;
        });

        // Let A start.
        await Future<void>.delayed(Duration.zero);
        expect(log, equals(['A-body']));

        // Close the queue while A is running.
        queue.close();
        expect(queue.isClosed, isTrue);

        // Enqueue B — queue is already closed; body must never run.
        final futureB = queue.enqueue(() async {
          log.add('B-body'); // must NOT be appended
        });

        // B's future should immediately error since the queue was closed at
        // enqueue time.
        await expectLater(futureB, throwsA(isA<StateError>()));

        // Enqueue C after close — also immediate StateError, also never runs.
        final futureC = queue.enqueue(() async {
          log.add('C-body');
        });
        await expectLater(futureC, throwsA(isA<StateError>()));

        // Release A's gate — A completes normally.
        gate.complete();
        await futureA;

        // B and C bodies were never called.
        expect(log, equals(['A-body']),
            reason: 'B and C bodies must never run after close');
      },
    );

    test(
      'command enqueued before close but not yet started is dropped '
      'when close() is called after enqueue',
      () async {
        final queue = SerialCommandQueue();
        final log = <String>[];
        final gate = Completer<void>();

        // Enqueue A and let it actually start — await one event-loop turn so
        // A's callback enters execution and suspends at gate.future. This ensures
        // A's slot saw _closed == false and is genuinely "in-flight", not just
        // queued — so A's discarded future completes successfully (no zone error).
        queue.enqueue(() async {
          await gate.future;
        });
        await Future<void>.delayed(Duration.zero); // A is now in-flight at the gate

        // B is enqueued while A is in-flight (queue is still open).
        final futureB = queue.enqueue(() async {
          log.add('B-body');
        });

        // Close the queue — B's slot will find _closed == true when A finishes.
        queue.close();

        // Register error handler SYNCHRONOUSLY — before releasing the gate — so
        // the handler is in place when B's slot fires and calls completeError.
        // (.then is synchronous; no await between here and gate.complete().)
        Object? bError;
        final bDone = Completer<void>();
        futureB.then(
          (_) => bDone.complete(),
          onError: (Object e) {
            bError = e;
            bDone.complete();
          },
        );

        // Release A's gate — A finishes, B's slot runs, finds closed → B dropped.
        gate.complete();
        await bDone.future;

        // B's future completed with StateError (poison-pill tail-drop).
        expect(bError, isA<StateError>(),
            reason: 'B future must complete with StateError');

        // B's body was never called.
        expect(log, isEmpty, reason: 'B body must not run after close');
      },
    );
  });

  // ── Post-dispose calibration safety ──────────────────────────────────────

  group('NeiryBciProvider — post-dispose calibration safety', () {
    test(
      'startQuickCalibration() after dispose() yields QueueClosedException, '
      'not Bad state: Cannot add event after closing',
      () async {
        final registry = _RecordingLocatorRegistry();
        final fakeSet = _FakeClassifierSet();
        final provider = NeiryBciProvider(
          locatorFactory: registry.locatorFactory,
          classifierFactory: _FakeClassifierFactory(fakeSet),
        );

        // dispose() synchronously sets _disposed=true and closes the queue in
        // _doDispose() before the first await.
        provider.dispose();
        // Let _doDispose() run to completion (closes controllers, locator).
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Pre-fix: this would crash with 'Bad state: Cannot add event after
        // closing' because the body ran directly against closed controllers.
        // Post-fix: the queue is closed → enqueue() returns QueueClosedException
        // immediately; no add to any controller is attempted.
        Object? caught;
        try {
          await provider.startQuickCalibration();
        } on QueueClosedException catch (e) {
          caught = e;
        }
        expect(caught, isA<QueueClosedException>(),
            reason: 'must reject with QueueClosedException, not crash with '
                'add-after-close');
      },
    );

    test(
      'startCalibration() after dispose() yields QueueClosedException, '
      'not Bad state: Cannot add event after closing',
      () async {
        final registry = _RecordingLocatorRegistry();
        final fakeSet = _FakeClassifierSet();
        final provider = NeiryBciProvider(
          locatorFactory: registry.locatorFactory,
          classifierFactory: _FakeClassifierFactory(fakeSet),
        );

        provider.dispose();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        Object? caught;
        try {
          await provider.startCalibration();
        } on QueueClosedException catch (e) {
          caught = e;
        }
        expect(caught, isA<QueueClosedException>(),
            reason: 'must reject with QueueClosedException, not crash with '
                'add-after-close');
      },
    );
  });

  // ── Provider-level no-recreate-on-dispose ─────────────────────────────────

  group('NeiryBciProvider — no orphaned locator recreate on dispose', () {
    test(
      'dispose() while drop-teardown is mid-queue: _resetLocatorSession never '
      'creates a new locator; only the original L0 is disposed',
      () async {
        final registry = _RecordingLocatorRegistry();
        final fakeSet = _FakeClassifierSet();
        final provider = NeiryBciProvider(
          locatorFactory: registry.locatorFactory,
          classifierFactory: _FakeClassifierFactory(fakeSet),
        );
        final l0 = registry.instances.first;

        // Connect succeeds — device is started.
        await provider.connect('TEST-001');
        final device = l0.lastCreatedDevice!;

        // Gate only stopStream — other device completers and l0.disposeCompleter
        // stay pre-completed so teardown can finish freely once the gate opens.
        device.stopStreamCompleter = Completer();

        // Emit drop — _teardownAfterUnexpectedDrop enqueues the teardown command;
        // it starts immediately and blocks at device.stopStream.
        device.emitConnection(BciLinkStatus.down);
        await Future<void>.delayed(Duration.zero); // teardown starts, hits gate

        // Call dispose while teardown is in-flight.
        provider.dispose(); // unawaited internally
        await Future<void>.delayed(Duration.zero); // _doDispose sets _disposed = true

        // Release the stopStream gate — teardown's finally calls
        // _resetLocatorSession(), which exits early because _disposed == true.
        device.stopStreamCompleter.complete();

        // Let teardown and _doDispose run to completion.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Only L0 was ever created — no orphaned L1 was recreated.
        expect(registry.createdCount, 1,
            reason: 'dispose must not create an orphaned replacement locator');
        expect(l0.disposeCount, 1,
            reason: 'L0 disposed exactly once by _doDispose terminal teardown');
        registry.assertNoOrphan();
      },
    );
  });
}

// ── Minimal fakes for provider-level test ─────────────────────────────────────

class _GatedFakeDevicePort implements DevicePort {
  final _connectionController = StreamController<BciLinkStatus>.broadcast();
  final _resistanceController =
      StreamController<List<BciChannelQuality>>.broadcast();
  final _batteryController = StreamController<int>.broadcast();

  bool _isStarted = false;

  Completer<void> stopStreamCompleter = Completer()..complete();
  Completer<void> disconnectCompleter = Completer()..complete();
  Completer<void> disposeCompleter = Completer()..complete();

  @override
  bool get isStarted => _isStarted;

  @override
  Stream<BciLinkStatus> get connectionStateStream =>
      _connectionController.stream;

  @override
  Stream<List<BciChannelQuality>> get resistanceStream =>
      _resistanceController.stream;

  @override
  Stream<int> get batteryStream => _batteryController.stream;

  @override
  Future<void> connect() async {}

  @override
  Future<void> start() async { _isStarted = true; }

  @override
  Future<void> stopStream() async {
    _isStarted = false;
    await stopStreamCompleter.future;
  }

  @override
  Future<void> disconnect() async {
    await disconnectCompleter.future;
  }

  @override
  Future<void> dispose() async {
    await disposeCompleter.future;
    _connectionController.close();
    _resistanceController.close();
    _batteryController.close();
  }

  void emitConnection(BciLinkStatus status) =>
      _connectionController.add(status);

  void closeControllers() {
    if (!_connectionController.isClosed) _connectionController.close();
    if (!_resistanceController.isClosed) _resistanceController.close();
    if (!_batteryController.isClosed) _batteryController.close();
  }
}

class _RecordingLocatorPort implements LocatorPort {
  int createDeviceCallCount = 0;
  int disposeCount = 0;

  Completer<void> disposeCompleter = Completer()..complete();

  final _devicesController = StreamController<List<BciDeviceInfo>>();
  _GatedFakeDevicePort? lastCreatedDevice;

  @override
  Stream<List<BciDeviceInfo>> requestDevices({
    BciScanDeviceType type = BciScanDeviceType.headband,
    int searchTime = 5,
  }) {
    return _devicesController.stream;
  }

  @override
  Future<DevicePort> createDevice(String serial) async {
    createDeviceCallCount++;
    final device = _GatedFakeDevicePort();
    lastCreatedDevice = device;
    return device;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    if (disposeCount > 1) {
      throw StateError('_RecordingLocatorPort: double-dispose');
    }
    await disposeCompleter.future;
    if (!_devicesController.isClosed) _devicesController.close();
  }
}

class _RecordingLocatorRegistry {
  final List<_RecordingLocatorPort> instances = [];
  bool _orphanDetected = false;

  late final LocatorPort Function() locatorFactory;

  _RecordingLocatorRegistry() {
    locatorFactory = () {
      if (instances.isNotEmpty && instances.last.disposeCount == 0) {
        _orphanDetected = true;
      }
      final port = _RecordingLocatorPort();
      instances.add(port);
      return port;
    };
  }

  int get createdCount => instances.length;

  int get liveCount =>
      instances.where((p) => p.disposeCount == 0).length;

  void assertNoOrphan() {
    expect(_orphanDetected, isFalse,
        reason: 'A locator was replaced without first being disposed (orphan)');
    for (int i = 0; i < instances.length - 1; i++) {
      expect(instances[i].disposeCount, greaterThan(0),
          reason: 'Locator at index $i was never disposed before replacement');
    }
  }
}

class _FakeClassifierSet implements ClassifierSet {
  final _nfbController = StreamController<BciNfbData>.broadcast();
  final _nfbErrorController = StreamController<String>.broadcast();
  final _cardioController = StreamController<CardioData>.broadcast();
  final _rrController = StreamController<RrInterval>.broadcast();
  final _emotionsController = StreamController<BciEmotionsData>.broadcast();
  final _emotionsErrorController = StreamController<String>.broadcast();
  final _motionController = StreamController<MotionData>.broadcast();

  @override
  Stream<BciNfbData> get nfbStateStream => _nfbController.stream;
  @override
  Stream<String> get nfbErrorStream => _nfbErrorController.stream;
  @override
  Stream<CardioData> get cardioStateStream => _cardioController.stream;
  @override
  Stream<RrInterval> get rrStream => _rrController.stream;
  @override
  Stream<BciEmotionsData> get emotionsStateStream => _emotionsController.stream;
  @override
  Stream<String> get emotionsErrorStream => _emotionsErrorController.stream;
  @override
  Stream<MotionData> get motionStream => _motionController.stream;

  @override
  Future<void> dispose() async {
    _nfbController.close();
    _nfbErrorController.close();
    _cardioController.close();
    _rrController.close();
    _emotionsController.close();
    _emotionsErrorController.close();
    _motionController.close();
  }
}

class _FakeClassifierFactory implements ClassifierFactory {
  final _FakeClassifierSet classifierSet;
  _FakeClassifierFactory(this.classifierSet);

  @override
  ClassifierSet build(DevicePort device) => classifierSet;
}
