import 'package:flutter_test/flutter_test.dart';

import 'package:mind/Bci/Ports/BuildAllOrDispose.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A fake resource that records how many times it has been disposed and
/// supports configurable failure modes on both the build and dispose paths.
class _FakeResource {
  int disposeCallCount = 0;

  /// A well-behaved disposer — increments [disposeCallCount] and returns
  /// normally.
  Future<void> dispose() async {
    disposeCallCount++;
  }

  /// A disposer that throws *synchronously* before returning a Future.
  Future<void> disposeSyncThrow() {
    disposeCallCount++;
    throw StateError('_FakeResource: synchronous dispose throw');
  }

  /// A disposer that returns a rejected Future (async rejection).
  Future<void> disposeAsyncReject() async {
    disposeCallCount++;
    throw StateError('_FakeResource: async dispose rejection');
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('buildAllOrDispose', () {
    // ── Happy path ─────────────────────────────────────────────────────────

    test('happy path: all steps succeed; no disposer is invoked', () {
      final r1 = _FakeResource();
      final r2 = _FakeResource();
      final r3 = _FakeResource();

      buildAllOrDispose([
        () {
          return r1.dispose;
        },
        () {
          return r2.dispose;
        },
        () {
          return r3.dispose;
        },
      ]);

      expect(r1.disposeCallCount, 0);
      expect(r2.disposeCallCount, 0);
      expect(r3.disposeCallCount, 0);
    });

    // ── Mid-construction throw ─────────────────────────────────────────────

    test(
      'mid-construction throw (step 3 of 4): already-built resources disposed '
      'in reverse order; original error rethrown',
      () async {
        final r1 = _FakeResource();
        final r2 = _FakeResource();
        // r3 never built (throws on step 3)
        // r4 never attempted (step 4 not reached)
        final r4 = _FakeResource();

        final disposeOrder = <int>[];

        expect(
          () => buildAllOrDispose([
            () {
              return () async {
                disposeOrder.add(1);
                await r1.dispose();
              };
            },
            () {
              return () async {
                disposeOrder.add(2);
                await r2.dispose();
              };
            },
            () {
              throw StateError('build error at step 3');
            },
            () {
              return r4.dispose;
            },
          ]),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            'build error at step 3',
          )),
        );

        // Drain microtasks so the fire-and-forget disposers complete.
        await Future<void>.delayed(Duration.zero);

        expect(r1.disposeCallCount, 1, reason: 'r1 must be disposed once');
        expect(r2.disposeCallCount, 1, reason: 'r2 must be disposed once');
        expect(r4.disposeCallCount, 0, reason: 'r4 was never built — not disposed');

        // Reverse order: step 2 was disposed before step 1.
        expect(disposeOrder, [2, 1], reason: 'disposal must be in reverse build order');
      },
    );

    // ── Dispose-failure isolation: async-rejecting disposer ────────────────

    test(
      'async-rejecting disposer: remaining earlier disposers still run; '
      'original build error propagates (not the dispose error)',
      () async {
        final r1 = _FakeResource();
        final r2 = _FakeResource(); // will async-reject on dispose
        final r3 = _FakeResource(); // throws during build

        final buildError = StateError('build error at step 3');

        expect(
          () => buildAllOrDispose([
            () => r1.dispose,
            () => r2.disposeAsyncReject,
            () {
              throw buildError;
            },
          ]),
          throwsA(same(buildError)),
        );

        // Drain microtasks.
        await Future<void>.delayed(Duration.zero);

        expect(r1.disposeCallCount, 1, reason: 'r1 must still be disposed');
        expect(r2.disposeCallCount, 1, reason: 'r2 must still be disposed (even though it rejects)');
        expect(r3.disposeCallCount, 0, reason: 'r3 was never built');
      },
    );

    // ── Dispose-failure isolation: synchronous-throwing disposer ───────────

    test(
      'sync-throwing disposer: remaining earlier disposers still run; '
      'original build error propagates (not the dispose error)',
      () async {
        final r1 = _FakeResource();
        final r2 = _FakeResource(); // will throw synchronously on dispose
        final r3 = _FakeResource(); // throws during build

        final buildError = StateError('build error at step 3');

        expect(
          () => buildAllOrDispose([
            () => r1.dispose,
            () => r2.disposeSyncThrow,
            () {
              throw buildError;
            },
          ]),
          throwsA(same(buildError)),
        );

        // Drain microtasks (not strictly required for sync, but ensures
        // any fire-and-forget futures are settled).
        await Future<void>.delayed(Duration.zero);

        expect(r1.disposeCallCount, 1,
            reason: 'r1 must still be disposed — sync-throw from r2 must not '
                'abort the reverse-dispose loop');
        expect(r2.disposeCallCount, 1, reason: 'r2 dispose was attempted (and threw)');
        expect(r3.disposeCallCount, 0, reason: 'r3 was never built');
      },
    );
  });
}
