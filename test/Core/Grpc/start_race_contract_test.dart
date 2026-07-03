// Start-race RED scenarios — single-practice (Task 4) and concurrent
// breath+meditation (Task 5).
//
// See Support/reconnect_concurrency_harness.dart for the full INV-*/SC-*
// catalogue (plan 22). This file pins the start-race half of that catalogue
// — greened by note 19.
//
// Pumping style: fakeAsync + async.flushMicrotasks() after every
// responseCtrl.add(...) / connection-state push — never Future.delayed
// (mirrors test/Biometrics/biometric_stream_id_routing_test.dart:116-123).
//
// Task 5 guard: assert purely on the wire (sentRequests) — never on
// per-type pending fields, which do not exist as a public seam today.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mind/Core/Grpc/ModuleState.dart';
import 'package:mind/Core/Grpc/generated/module_state.pb.dart' as proto;

import 'Support/reconnect_concurrency_harness.dart';

Iterable<proto.StateRequest> _starts(TrackActivityCall call) => call.sentRequests
    .where((r) => r.whichCommand() == proto.StateRequest_Command.activityStart);

void main() {
  // ── Task 4: single-practice start-race ────────────────────────────────────

  group('start-race contract — single practice (note 19)', () {
    test(
      // INV-8 / INV-9 / SC-2 — RED now: no retry mechanism exists today, so
      // the unconfirmed start is never resent after the 5s confirm timeout.
      'INV-8/INV-9/SC-2: an unconfirmed start retries after 5s with the same client_activity_id',
      () {
        fakeAsync((async) {
          final f = wireConcurrent();
          connectAndFlush(f, async);

          f.breathStateCtrl.add(runningBreathState());
          async.flushMicrotasks();

          final firstStarts = _starts(f.service.latestCall!).toList();
          expect(firstStarts, hasLength(1));
          final firstId = firstStarts.first.activityStart.clientActivityId;

          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();

          final startsAfterTimeout = _starts(f.service.latestCall!).toList();
          expect(startsAfterTimeout.length, greaterThanOrEqualTo(2),
              reason: 'an unconfirmed start must retry after the 5s confirm '
                  'timeout — no retry exists today (RED now)');
          expect(startsAfterTimeout[1].activityStart.clientActivityId, firstId,
              reason: 'the retry must reuse the same client_activity_id, '
                  'never regenerate');

          f.channel.dispose();
        });
      },
    );

    test(
      // INV-8 (post-confirm) — GREEN-now guard: the confirming frame already
      // flips _isPendingStart false today; pins that the note-19 retry does
      // not fire once confirmed.
      'INV-8: no retry once the start has been confirmed by an ACTIVE frame',
      () {
        fakeAsync((async) {
          final f = wireConcurrent();
          connectAndFlush(f, async);

          f.breathStateCtrl.add(runningBreathState());
          async.flushMicrotasks();
          f.service.latestCall!.responseCtrl.add(childActiveFrame(proto.ActivityType.BREATH, 'breath-1'));
          async.flushMicrotasks();

          final countAfterConfirm = f.service.latestCall!.sentRequests.length;
          async.elapse(const Duration(seconds: 10));
          async.flushMicrotasks();

          expect(f.service.latestCall!.sentRequests.length, countAfterConfirm);

          f.channel.dispose();
        });
      },
    );

    test(
      // INV-12 — GREEN-now guard: no retry mechanism exists today, so "no
      // further activityStart after retries exhaust" already holds
      // vacuously (only the initial attempt is ever sent). Pins the ceiling
      // (<=3 total attempts) so note 19's retry loop cannot overshoot it.
      'INV-12: total start attempts never exceed 3 (1 initial + 2 retries) across repeated 5s windows',
      () {
        fakeAsync((async) {
          final f = wireConcurrent();
          connectAndFlush(f, async);

          f.breathStateCtrl.add(runningBreathState());
          async.flushMicrotasks();

          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();

          expect(_starts(f.service.latestCall!).length, lessThanOrEqualTo(3));

          f.channel.dispose();
        });
      },
    );

    test(
      // INV-10 / SC-7 (same-type adopt) — GREEN-now guard: today start()
      // early-returns once currentState.status == active
      // (ModuleStateChannel.dart:237) — pins no-duplicate-on-adopt.
      'INV-10/SC-7: same-type adopt after app-restart sends no fresh start',
      () {
        fakeAsync((async) {
          final f = wireConcurrent();
          connectAndFlush(f, async);

          // App-restart: the old breath child RESUMED lands before any
          // local start attempt.
          f.service.latestCall!.responseCtrl
              .add(childResumedFrame(proto.ActivityType.BREATH, 'breath-1', isPaused: false));
          async.flushMicrotasks();
          expect(f.channel.currentState.status, ModuleStateStatus.active);

          f.breathStateCtrl.add(runningBreathState());
          async.flushMicrotasks();

          expect(_starts(f.service.latestCall!), isEmpty,
              reason: 'adopting an already-live same-type child must not '
                  'send a fresh start');

          f.channel.dispose();
        });
      },
    );

    test(
      // INV-10 (cross-type suppression) — RED now: the shared single-state
      // guard at ModuleStateChannel.dart:237 wrongly suppresses breath's
      // start because currentState.status == active (from meditation),
      // even though breath itself has never started. Goes GREEN under
      // note 19's per-type adopt/pending.
      'INV-10: a live meditation child must not suppress a fresh breath start',
      () {
        fakeAsync((async) {
          final f = wireConcurrent();
          connectAndFlush(f, async);

          f.service.latestCall!.responseCtrl.add(childActiveFrame(proto.ActivityType.MEDITATION, 'med-1'));
          async.flushMicrotasks();
          expect(f.channel.currentState.status, ModuleStateStatus.active);

          f.breathStateCtrl.add(runningBreathState());
          async.flushMicrotasks();

          expect(_starts(f.service.latestCall!), isNotEmpty,
              reason: "breath's start must reach the wire — a live child of "
                  'a different type must not suppress a start of an '
                  'un-started type (RED now)');

          f.channel.dispose();
        });
      },
    );
  });

  // ── Task 5: concurrent breath+meditation start-race & settling window ────

  group('start-race contract — concurrent breath+meditation & settling window (note 19)', () {
    test(
      // SC-1 / INV-8 — RED now: only breath's start is sent; meditation's is
      // dropped because the shared _isPendingStart / single-state guard is
      // already set by breath's in-flight start.
      'SC-1/INV-8: concurrent breath+meditation starts both reach the wire',
      () {
        fakeAsync((async) {
          final f = wireConcurrent();
          connectAndFlush(f, async);

          f.breathStateCtrl.add(runningBreathState());
          async.flushMicrotasks();
          f.meditationStateCtrl.add(activeMeditationState());
          async.flushMicrotasks();

          expect(_starts(f.service.latestCall!).length, 2,
              reason: 'both breath and meditation starts must reach the '
                  'wire when tapped concurrently while both are un-started '
                  '— today the second is dropped by the shared '
                  '_isPendingStart guard (RED now)');

          f.channel.dispose();
        });
      },
    );

    test(
      // INV-11 / SC-3 — RED now: no settling-window defer exists today, so
      // the re-armed adapter's start reaches the wire immediately instead
      // of waiting for reconcile to resolve adopt-vs-new.
      'INV-11/SC-3: a start within the settling window is deferred, then adopts the resumed same-type child with no duplicate',
      () {
        fakeAsync((async) {
          final f = wireConcurrent();
          connectAndFlush(f, async);

          // Establish + confirm a live breath child.
          f.breathStateCtrl.add(runningBreathState());
          async.flushMicrotasks();
          f.service.latestCall!.responseCtrl.add(childActiveFrame(proto.ActivityType.BREATH, 'breath-1'));
          async.flushMicrotasks();

          // The connection drops; a reset frame lands before the close so
          // the legacy single-state is idle by the time the app-restart
          // taps start below — isolates the settling-window defer gap from
          // the (separately pinned, INV-4-flavoured) stale-active-state
          // artefact of a bare reconnect.
          f.service.latestCall!.responseCtrl.add(globalResetFrame());
          async.flushMicrotasks();
          f.service.latestCall!.responseCtrl.close();
          async.flushMicrotasks();
          f.connManager.pushConnected();
          async.flushMicrotasks();
          final reopenedCall = f.service.latestCall!;

          // App-restart: the adapter re-arms and taps start again for the
          // same type, while the old breath-1 child is about to resume
          // server-side.
          f.breathAdapter.reset();
          f.breathStateCtrl.add(runningBreathState());
          async.flushMicrotasks();

          expect(_starts(reopenedCall), isEmpty,
              reason: 'the start must be deferred until the settling '
                  'window closes so reconcile can decide adopt-vs-new — no '
                  'defer mechanism exists today, so the start goes out '
                  'immediately instead (RED now)');

          // The old breath-1 child resumes within the window.
          reopenedCall.responseCtrl
              .add(childResumedFrame(proto.ActivityType.BREATH, 'breath-1', isPaused: false));
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 3));
          async.flushMicrotasks();

          expect(_starts(reopenedCall).length, lessThanOrEqualTo(1),
              reason: 'the resumed child must be adopted — at most the one '
                  'start already on the wire, no duplicate once the window '
                  'resolves');

          f.channel.dispose();
        });
      },
    );

    test(
      // INV-11 (symmetric — no resume) — RED now: deferral must release,
      // not drop, once the settling window elapses with no RESUMED frame
      // for that type. Today there is no deferral at all, so the start is
      // sent immediately rather than being held until the window closes.
      'INV-11: a deferred start is released (not dropped) once the settling window elapses with no resume',
      () {
        fakeAsync((async) {
          final f = wireConcurrent();
          connectAndFlush(f, async);

          f.breathStateCtrl.add(runningBreathState());
          async.flushMicrotasks();
          f.service.latestCall!.responseCtrl.add(childActiveFrame(proto.ActivityType.BREATH, 'breath-1'));
          async.flushMicrotasks();

          f.service.latestCall!.responseCtrl.add(globalResetFrame());
          async.flushMicrotasks();
          f.service.latestCall!.responseCtrl.close();
          async.flushMicrotasks();
          f.connManager.pushConnected();
          async.flushMicrotasks();
          final reopenedCall = f.service.latestCall!;

          f.breathAdapter.reset();
          f.breathStateCtrl.add(runningBreathState());
          async.flushMicrotasks();

          // Deferred — not on the wire yet, immediately after the tap.
          expect(_starts(reopenedCall), isEmpty,
              reason: 'the start must be held pending until the settling '
                  'window closes — today it is sent immediately instead '
                  '(RED now)');

          // No RESUMED frame ever arrives for breath — the settling window
          // elapses with nothing to adopt.
          async.elapse(const Duration(seconds: 3));
          async.flushMicrotasks();

          expect(_starts(reopenedCall), isNotEmpty,
              reason: 'deferral must release, not drop — with no resume, '
                  'the start must be sent once the window elapses');

          f.channel.dispose();
        });
      },
    );
  });
}
