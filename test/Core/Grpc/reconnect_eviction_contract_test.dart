// Reconnect / eviction / close-classification & reconcile RED scenarios.
//
// See Support/reconnect_concurrency_harness.dart for the full INV-*/SC-*
// catalogue (plan 22). This file pins the eviction/close-classification and
// reconnect/reconcile half of that catalogue — greened by note 20.
//
// Pumping style: fakeAsync + async.flushMicrotasks() after every
// responseCtrl.add(...) / connection-state push — never Future.delayed
// (mirrors test/Biometrics/biometric_stream_id_routing_test.dart:116-123).

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Core/Grpc/ModuleState.dart';
import 'package:mind/Core/Grpc/generated/module_state.pb.dart' as proto;

import 'Support/reconnect_concurrency_harness.dart';

void main() {
  // ── Task 2: close-classification & latch ──────────────────────────────────

  group('reconnect/eviction contract — close classification (note 20)', () {
    test(
      // INV-1 / SC-4 — RED now: current onDone always schedules a reconnect
      // (ModuleStateChannel.dart:126-131) regardless of a preceding
      // CONNECTION_SUPERSEDED session_error, so this fails today.
      'INV-1/SC-4: SUPERSEDED session_error then close must NOT schedule a reconnect',
      () {
        fakeAsync((async) {
          final f = wireConcurrent();
          connectAndFlush(f, async);

          f.service.latestCall!.responseCtrl.add(supersededErrorFrame());
          async.flushMicrotasks();
          f.service.latestCall!.responseCtrl.close();
          async.flushMicrotasks();

          expect(f.connManager.scheduleReconnectCount, 0,
              reason: 'a SUPERSEDED close must yield, not reconnect — '
                  'current onDone schedules unconditionally (RED now)');

          f.channel.dispose();
        });
      },
    );

    test(
      // INV-1 / SC-5 — GREEN-now guard: pins the reconnect-on-bare-close
      // half so the note-20 rewrite cannot over-yield a plain drop.
      'INV-1/SC-5: bare close with no preceding code schedules exactly one reconnect',
      () {
        fakeAsync((async) {
          final f = wireConcurrent();
          connectAndFlush(f, async);

          f.service.latestCall!.responseCtrl.close();
          async.flushMicrotasks();

          expect(f.connManager.disconnectCount, 1);
          expect(f.connManager.scheduleReconnectCount, 1);

          f.channel.dispose();
        });
      },
    );

    test(
      // INV-1 (onError) — GREEN-now guard: a transport-level stream error
      // must still reconnect.
      'INV-1: a transport onError schedules a reconnect',
      () {
        fakeAsync((async) {
          final f = wireConcurrent();
          connectAndFlush(f, async);

          f.service.latestCall!.responseCtrl.addError(Exception('transport drop'));
          async.flushMicrotasks();

          expect(f.connManager.disconnectCount, 1);
          expect(f.connManager.scheduleReconnectCount, 1);

          f.channel.dispose();
        });
      },
    );

    test(
      // INV-2 / SC-6 — RED now: current code reopens unconditionally on
      // `connected` (ModuleStateChannel.dart:75-76) — the yield latch does
      // not exist yet, so app-resume after SUPERSEDED re-opens a stream.
      'INV-2/SC-6: app-resume after SUPERSEDED+close must NOT re-open the session',
      () {
        fakeAsync((async) {
          final f = wireConcurrent();
          connectAndFlush(f, async);

          f.service.latestCall!.responseCtrl.add(supersededErrorFrame());
          async.flushMicrotasks();
          f.service.latestCall!.responseCtrl.close();
          async.flushMicrotasks();

          final callBaseline = f.service.calls.length;
          final reconnectBaseline = f.connManager.scheduleReconnectCount;

          // Simulate app-resume: connection manager reconnects.
          f.connManager.pushConnected();
          async.flushMicrotasks();

          expect(f.service.calls.length - callBaseline, 0,
              reason: 'a yielded session must not re-take on app-resume — '
                  'current code opens a fresh trackActivity call '
                  'unconditionally on connected (RED now)');
          expect(f.connManager.scheduleReconnectCount, reconnectBaseline);

          f.channel.dispose();
        });
      },
    );
  });

  // ── Task 3: reconcile & takeover ──────────────────────────────────────────

  group('reconnect/eviction contract — reconcile & takeover (note 20)', () {
    test(
      // INV-4 — RED now: the registry is never cleared on close/reopen
      // (ModuleStateChannel._closeSessionStream:136-141), so a stale
      // pre-reconnect rootId silently survives a reconnect that carries no
      // ROOT frame (server memory lost, only per-child RESUMED arrives).
      'INV-4: rootId must not survive a reconnect until a fresh ROOT frame lands',
      () {
        fakeAsync((async) {
          final f = wireConcurrent();
          connectAndFlush(f, async);

          f.service.latestCall!.responseCtrl.add(rootFrame('root-1'));
          async.flushMicrotasks();
          expect(f.channel.rootId, 'root-1');

          // Reconnect: close then reopen.
          f.service.latestCall!.responseCtrl.close();
          async.flushMicrotasks();
          f.connManager.pushConnected();
          async.flushMicrotasks();

          // Server memory lost — only a per-child RESUMED frame arrives,
          // no ROOT re-open frame.
          f.service.latestCall!.responseCtrl
              .add(childResumedFrame(proto.ActivityType.BREATH, 'breath-1', isPaused: false));
          async.flushMicrotasks();

          expect(f.channel.rootId, isNull,
              reason: 'rootId must not be derived from the child fan-out nor '
                  'silently persist the pre-reconnect root — current code '
                  'never clears the registry on close/reopen (RED now)');

          // The subsequent ROOT re-open frame lands — rootId is restored.
          f.service.latestCall!.responseCtrl.add(rootFrame('root-2'));
          async.flushMicrotasks();
          expect(f.channel.rootId, 'root-2');

          f.channel.dispose();
        });
      },
    );

    test(
      // INV-5 / SC-3 — RED now: no settling-window eviction exists today,
      // so a cached child that never re-arrives after reconnect is not
      // dropped from the registry.
      'INV-5/SC-3: a cached child with no RESUMED frame within the settling window is treated as gone',
      () {
        fakeAsync((async) {
          final f = wireConcurrent();
          connectAndFlush(f, async);

          f.service.latestCall!.responseCtrl.add(childActiveFrame(proto.ActivityType.BREATH, 'breath-1'));
          async.flushMicrotasks();
          f.service.latestCall!.responseCtrl.add(childActiveFrame(proto.ActivityType.MEDITATION, 'med-1'));
          async.flushMicrotasks();
          expect(f.channel.childOfType(ActivityType.breath), isNotNull);
          expect(f.channel.childOfType(ActivityType.meditation), isNotNull);

          // Reconnect.
          f.service.latestCall!.responseCtrl.close();
          async.flushMicrotasks();
          f.connManager.pushConnected();
          async.flushMicrotasks();

          // Only breath re-arrives within the settling window.
          f.service.latestCall!.responseCtrl
              .add(childResumedFrame(proto.ActivityType.BREATH, 'breath-1', isPaused: false));
          async.flushMicrotasks();

          // Let the 3s settling window elapse.
          async.elapse(const Duration(seconds: 3));
          async.flushMicrotasks();

          expect(f.channel.childOfType(ActivityType.breath), isNotNull,
              reason: 'the arrived child must survive the settling window');
          expect(f.channel.childOfType(ActivityType.meditation), isNull,
              reason: 'a cached child silent through the settling window '
                  'must be treated as gone — no such eviction exists today '
                  '(RED now)');

          f.channel.dispose();
        });
      },
    );

    test(
      // INV-6 — RED now: a root-level ABANDONED only removes the root's own
      // registry entry (ModuleStateChannel._handleRootFrame /
      // SessionRegistry.removeTerminal), it does not cascade-clear the
      // root's children — so a stale child survives the reset that a
      // freshly-minted root is meant to repopulate cleanly.
      'INV-6: an {abandoned} root reset must not leave stale children once a fresh root repopulates the registry',
      () {
        fakeAsync((async) {
          final f = wireConcurrent();
          connectAndFlush(f, async);

          f.service.latestCall!.responseCtrl.add(rootFrame('root-1'));
          async.flushMicrotasks();
          f.service.latestCall!.responseCtrl.add(childActiveFrame(proto.ActivityType.BREATH, 'breath-1'));
          async.flushMicrotasks();

          // Root-level {abandoned} — the whole session tree is evicted.
          f.service.latestCall!.responseCtrl.add(proto.StateResponse(
            sessionState: proto.StateEvent(
              status: proto.ActivityStatus.ABANDONED,
              moduleSessionId: 'root-1',
              activityType: proto.ActivityType.ROOT,
            ),
          ));
          async.flushMicrotasks();

          // A freshly-minted root repopulates the registry.
          f.service.latestCall!.responseCtrl.add(rootFrame('root-2'));
          async.flushMicrotasks();

          expect(f.channel.rootId, 'root-2');
          expect(f.channel.childOfType(ActivityType.breath), isNull,
              reason: 'reset-then-adopt must not double-populate — the old '
                  'breath-1 child must not survive the root-level abandon; '
                  'today only the root\'s own entry is removed (RED now)');

          f.channel.dispose();
        });
      },
    );

    test(
      // INV-7 — GREEN-now guard: RESUMED already reads event.isPaused into
      // the registry entry (ModuleStateChannel.dart:152-159 /
      // _upsertRegistryEntry:205-214), covered at
      // module_state_channel_test.dart:1190-1218. Pinned here so the
      // note-20 reconcile rewrite cannot regress paused-adoption.
      'INV-7: a child RESUMED frame with is_paused=true adopts isPaused=true',
      () {
        fakeAsync((async) {
          final f = wireConcurrent();
          connectAndFlush(f, async);

          f.service.latestCall!.responseCtrl
              .add(childResumedFrame(proto.ActivityType.BREATH, 'breath-1', isPaused: true));
          async.flushMicrotasks();

          expect(f.channel.childOfType(ActivityType.breath)?.isPaused, isTrue);

          f.channel.dispose();
        });
      },
    );

    test(
      // INV-3 — skip: the one invariant needing a not-yet-existing public
      // seam. Note 20 adds `ModuleStateChannel.takeOverHere()`; when it
      // lands, remove the skip and replace the dynamic call below with a
      // direct static call.
      'INV-3: takeOverHere() clears the yield latch and reopens to a clean root frame with no child frames',
      () {
        fakeAsync((async) {
          final f = wireConcurrent();
          connectAndFlush(f, async);

          f.service.latestCall!.responseCtrl.add(rootFrame('root-1'));
          async.flushMicrotasks();
          f.service.latestCall!.responseCtrl.add(childActiveFrame(proto.ActivityType.BREATH, 'breath-1'));
          async.flushMicrotasks();

          f.service.latestCall!.responseCtrl.add(supersededErrorFrame());
          async.flushMicrotasks();
          f.service.latestCall!.responseCtrl.close();
          async.flushMicrotasks();

          final callBaseline = f.service.calls.length;

          // Not yet a real API — dynamic dispatch so this file still
          // compiles ahead of note 20 adding the method.
          (f.channel as dynamic).takeOverHere();
          async.flushMicrotasks();

          expect(f.service.calls.length, callBaseline + 1);
          f.service.latestCall!.responseCtrl.add(rootFrame('root-3'));
          async.flushMicrotasks();

          expect(f.channel.currentState.status, ModuleStateStatus.idle,
              reason: 'the takeover receives a clean root frame — no legacy '
                  'single-state child frame follows it');
          expect(f.channel.childOfType(ActivityType.breath), isNull,
              reason: 'the takeover must not replay child frames');

          f.channel.dispose();
        });
      },
      skip: 'needs note 20\'s takeOverHere() seam (INV-3) — not yet public',
    );
  });
}
