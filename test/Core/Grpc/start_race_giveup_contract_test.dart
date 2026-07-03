// Give-up-surface golden-master tests (note 27) — additive coverage for the
// three silently-failing give-up surfaces of task 26 (type-scoped adapter
// reset, carried-path budget enforcement, `SessionStartFailed` emission +
// snackbar wire). These tests must be GREEN on the current committed tree
// (commit `93f3e92`) — they lock the give-up behaviour before note 28's
// pending-start state lift refactors the internals under this pinned
// contract. No production code change accompanies this file.
//
// Pumping style + shared harness mirror start_race_contract_test.dart:
// fakeAsync + async.flushMicrotasks() after every frame push / async.elapse,
// wireConcurrent() from Support/reconnect_concurrency_harness.dart (not
// modified here), f.channel.dispose() at the end of every test.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Core/Grpc/ModuleStateChannel.dart';
import 'package:mind/Core/Grpc/ModuleStateEvent.dart';
import 'package:mind/Core/Grpc/generated/module_state.pb.dart' as proto;

import 'Support/reconnect_concurrency_harness.dart';

Iterable<proto.StateRequest> _starts(TrackActivityCall call) => call.sentRequests
    .where((r) => r.whichCommand() == proto.StateRequest_Command.activityStart);

/// Subscribes to [channel]'s events and collects every `SessionStartFailed`
/// as it fires — a local golden-master helper (does not touch the shared
/// harness).
List<SessionStartFailed> _collectFailures(ModuleStateChannel channel) {
  final failures = <SessionStartFailed>[];
  channel.events.listen((event) {
    if (event is SessionStartFailed) failures.add(event);
  });
  return failures;
}

void main() {
  // ── Surface 1: type-scoped adapter reset ──────────────────────────────────

  group('give-up surface — type-scoped adapter reset (note 27)', () {
    test(
      // Locks the `event.type == ActivityType.breath` filter in
      // BreathModuleStateChannel — a meditation give-up must not clear a
      // live breath session's moduleSessionId mid-practice.
      'meditation give-up must not reset a live breath session',
      () {
        fakeAsync((async) {
          final f = wireConcurrent();
          connectAndFlush(f, async);

          f.breathStateCtrl.add(runningBreathState());
          async.flushMicrotasks();
          f.service.latestCall!.responseCtrl.add(childActiveFrame(proto.ActivityType.BREATH, 'breath-1'));
          async.flushMicrotasks();
          expect(f.breathAdapter.moduleSessionId, 'breath-1');

          f.meditationStateCtrl.add(activeMeditationState());
          async.flushMicrotasks();

          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();

          expect(f.breathAdapter.moduleSessionId, 'breath-1',
              reason: "meditation's give-up must not clear the live breath "
                  'session — the event.type filter in '
                  'BreathModuleStateChannel must reject a meditation '
                  'SessionStartFailed');

          f.channel.dispose();
        });
      },
    );

    test(
      // Symmetric case: locks the `event.type == ActivityType.meditation`
      // filter in MeditationModuleStateChannel.
      'breath give-up must not reset a live meditation session (symmetric)',
      () {
        fakeAsync((async) {
          final f = wireConcurrent();
          connectAndFlush(f, async);

          f.meditationStateCtrl.add(activeMeditationState());
          async.flushMicrotasks();
          f.service.latestCall!.responseCtrl.add(childActiveFrame(proto.ActivityType.MEDITATION, 'med-1'));
          async.flushMicrotasks();
          expect(f.meditationAdapter.moduleSessionId, 'med-1');

          f.breathStateCtrl.add(runningBreathState());
          async.flushMicrotasks();

          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();

          expect(f.meditationAdapter.moduleSessionId, 'med-1',
              reason: "breath's give-up must not clear the live meditation "
                  'session — the event.type filter in '
                  'MeditationModuleStateChannel must reject a breath '
                  'SessionStartFailed');

          f.channel.dispose();
        });
      },
    );
  });

  // ── Surface 2: carried-path budget enforcement ────────────────────────────

  group('give-up surface — carried-path budget (note 27)', () {
    test(
      // Pins the INV-12 overshoot that review 2 caught reactively: a carried
      // pending whose 3-attempt budget is already spent must give up via
      // `_giveUp` when a settling window re-resolves it, never send a 4th
      // wire request.
      '3-attempt-spent carried pending gives up on settling-window resolve, no 4th send',
      () {
        fakeAsync((async) {
          final f = wireConcurrent();
          connectAndFlush(f, async);
          final failures = _collectFailures(f.channel);

          f.breathStateCtrl.add(runningBreathState());
          async.flushMicrotasks();

          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();

          disconnectAndFlush(f, async);
          f.connManager.pushConnected();
          async.flushMicrotasks();

          async.elapse(const Duration(seconds: 3));
          async.flushMicrotasks();

          final totalStarts =
              f.service.calls.fold<int>(0, (sum, call) => sum + _starts(call).length);
          expect(totalStarts, lessThanOrEqualTo(3),
              reason: 'the spent budget must not overshoot INV-12s 3-attempt '
                  'ceiling with a 4th send when the settling window '
                  're-resolves the carried pending');
          expect(failures.where((sf) => sf.type == ActivityType.breath).length, 1,
              reason: 'the carried budget must give up via _resolveSettling '
                  '-> _giveUp, not a re-send — exactly one SessionStartFailed '
                  'for breath');

          f.channel.dispose();
        });
      },
    );
  });

  // ── Surface 3: SessionStartFailed emission + snackbar wire ────────────────

  group('give-up surface — SessionStartFailed emission + snackbar wire (note 27)', () {
    test(
      // INV-12's existing test only bounds wire count <= 3 and never asserts
      // the give-up event or the snackbar wire — this closes that gap by
      // reproducing the exact App.dart:323 transform
      // (`channel.events.where((e) => e is SessionStartFailed).map((_) {})`)
      // that feeds GlobalListeners.sessionStartFailedStream.
      'give-up emits SessionStartFailed(breath) and reaches the snackbar-wire transform',
      () {
        fakeAsync((async) {
          final f = wireConcurrent();
          connectAndFlush(f, async);

          final failures = _collectFailures(f.channel);
          final snackbarEvents = <void>[];
          f.channel.events.where((e) => e is SessionStartFailed).map((_) {}).listen(snackbarEvents.add);

          f.breathStateCtrl.add(runningBreathState());
          async.flushMicrotasks();

          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();

          expect(failures, hasLength(1));
          expect(failures.single.type, ActivityType.breath);
          expect(snackbarEvents, hasLength(1),
              reason: 'the exact App.dart:323 transform feeding '
                  'GlobalListeners.sessionStartFailedStream must fire once '
                  'give-up emits SessionStartFailed');

          f.channel.dispose();
        });
      },
    );
  });
}
