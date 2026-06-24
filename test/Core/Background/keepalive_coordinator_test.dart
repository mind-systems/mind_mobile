import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:mind/Core/Background/ForegroundKeepAlive.dart';
import 'package:mind/Core/Background/KeepAliveCoordinator.dart';
import 'package:mind/Core/Grpc/ModuleStateEvent.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Fake
// ──────────────────────────────────────────────────────────────────────────────

class _FakeForegroundKeepAlive extends ForegroundKeepAlive {
  _FakeForegroundKeepAlive() : super(currentLanguageCode: () => 'en');
  final List<String> calls = []; // 'start' / 'stop' in invocation order

  @override
  Future<void> start() async => calls.add('start');

  @override
  Future<void> stop() async => calls.add('stop');
}

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────────

typedef _Fixture = ({
  KeepAliveCoordinator coordinator,
  _FakeForegroundKeepAlive fgs,
  StreamController<ModuleStateEvent> ctrl,
});

_Fixture _make({bool isAndroid = true}) {
  final fgs = _FakeForegroundKeepAlive();
  final ctrl = StreamController<ModuleStateEvent>.broadcast();
  final coordinator = KeepAliveCoordinator(
    foregroundKeepAlive: fgs,
    moduleStateEvents: ctrl.stream,
    isAndroid: () => isAndroid,
  );
  return (coordinator: coordinator, fgs: fgs, ctrl: ctrl);
}

Future<void> _emit(_Fixture f, ModuleStateEvent event) async {
  f.ctrl.add(event);
  await Future<void>.microtask(() {});
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

void main() {
  group('KeepAliveCoordinator — non-Android guard', () {
    late _Fixture f;

    setUp(() => f = _make(isAndroid: false));
    tearDown(() async => f.ctrl.close());

    test('should construct without error when not on Android', () {
      expect(f.coordinator, isNotNull);
    });

    test(
      'should never call start() or stop() when events are emitted on a non-Android host',
      () async {
        await _emit(f, ModuleSessionStarted());
        await _emit(f, ModuleSessionEnded());
        await _emit(f, ModuleSessionAbandoned());

        expect(f.fgs.calls, isEmpty);
      },
    );
  });

  group('KeepAliveCoordinator — session lifecycle → FGS start/stop', () {
    late _Fixture f;

    setUp(() => f = _make());
    tearDown(() async {
      f.coordinator.dispose();
      await f.ctrl.close();
    });

    test(
      'should call start() exactly once when ModuleSessionStarted is emitted',
      () async {
        await _emit(f, ModuleSessionStarted());

        expect(f.fgs.calls, ['start']);
      },
    );

    test(
      'should call stop() exactly once when ModuleSessionEnded is emitted',
      () async {
        await _emit(f, ModuleSessionEnded());

        expect(f.fgs.calls, ['stop']);
      },
    );

    test(
      'should call stop() exactly once when ModuleSessionAbandoned is emitted',
      () async {
        await _emit(f, ModuleSessionAbandoned());

        expect(f.fgs.calls, ['stop']);
      },
    );

    test(
      'should not call stop() when only ModuleSessionStarted is emitted',
      () async {
        await _emit(f, ModuleSessionStarted());

        expect(f.fgs.calls, isNot(contains('stop')));
      },
    );
  });

  group('KeepAliveCoordinator — re-arm and ordering', () {
    late _Fixture f;

    setUp(() => f = _make());
    tearDown(() async {
      f.coordinator.dispose();
      await f.ctrl.close();
    });

    test(
      'should call start() again on a second ModuleSessionStarted after ModuleSessionEnded',
      () async {
        await _emit(f, ModuleSessionStarted());
        await _emit(f, ModuleSessionEnded());
        await _emit(f, ModuleSessionStarted());

        expect(f.fgs.calls, ['start', 'stop', 'start']);
      },
    );

    test(
      'should call start() twice for two consecutive ModuleSessionStarted without dedup',
      () async {
        await _emit(f, ModuleSessionStarted());
        await _emit(f, ModuleSessionStarted());

        expect(f.fgs.calls, ['start', 'start']);
      },
    );

    test(
      'should record only start then stop when Paused/Unpaused are interleaved',
      () async {
        await _emit(f, ModuleSessionStarted());
        await _emit(f, ModuleSessionPaused());
        await _emit(f, ModuleSessionUnpaused());
        await _emit(f, ModuleSessionEnded());

        expect(f.fgs.calls, ['start', 'stop']);
      },
    );
  });

  group('KeepAliveCoordinator — non-lifecycle events are no-ops', () {
    late _Fixture f;

    setUp(() => f = _make());
    tearDown(() async {
      f.coordinator.dispose();
      await f.ctrl.close();
    });

    test(
      'should not call start() or stop() when ModuleSessionResumed is emitted',
      () async {
        await _emit(f, ModuleSessionResumed());

        expect(f.fgs.calls, isEmpty);
      },
    );

    test(
      'should not call start() or stop() when ModuleSessionPaused is emitted',
      () async {
        await _emit(f, ModuleSessionPaused());

        expect(f.fgs.calls, isEmpty);
      },
    );

    test(
      'should not call start() or stop() when ModuleSessionUnpaused is emitted',
      () async {
        await _emit(f, ModuleSessionUnpaused());

        expect(f.fgs.calls, isEmpty);
      },
    );
  });

  group('KeepAliveCoordinator — dispose stops routing', () {
    late _Fixture f;

    setUp(() => f = _make());
    tearDown(() async => f.ctrl.close());

    test(
      'should not route events after dispose()',
      () async {
        f.coordinator.dispose();
        await _emit(f, ModuleSessionStarted());

        expect(f.fgs.calls, isEmpty);
      },
    );

    test(
      'should cancel the subscription on dispose() without throwing',
      () {
        expect(() => f.coordinator.dispose(), returnsNormally);
      },
    );

    test(
      'should not throw when the events stream is closed',
      () async {
        expect(() async => f.ctrl.close(), returnsNormally);
        await Future<void>.microtask(() {});
      },
    );
  });
}
