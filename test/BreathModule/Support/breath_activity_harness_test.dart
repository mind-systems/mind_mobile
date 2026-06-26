import 'package:flutter_test/flutter_test.dart';
import 'package:breath_module/breath_module.dart' show BreathLifecycle, BreathPhase;
import 'BreathActivityHarness.dart';

void main() {
  late BreathActivityHarness harness;

  setUp(() async {
    harness = BreathActivityHarness();
    await harness.init();
  });

  tearDown(() => harness.dispose());

  group('BreathActivityHarness smoke', () {
    test(
      'resume → tick × 3 → complete drives all three output channels',
      () async {
        // ── Drive ──────────────────────────────────────────────────────────

        harness.resume();
        await pumpEventQueue();

        for (var i = 0; i < 3; i++) {
          harness.tick();
          await pumpEventQueue();
        }

        harness.complete();
        await pumpEventQueue();

        // ── Output channel 1: state sequence ──────────────────────────────
        //
        // After resume() the session enters breath status. After complete()
        // it reaches complete status. Both must appear in the recorded sequence.

        expect(
          harness.states.any((s) => s.lifecycle == BreathLifecycle.running && s.phase != BreathPhase.rest),
          isTrue,
          reason: 'state sequence should contain at least one breath status',
        );
        expect(
          harness.states.last.lifecycle,
          BreathLifecycle.completed,
          reason: 'final state must be complete',
        );

        // ── Output channel 2: channel call-log ────────────────────────────
        //
        // resume() → breath causes BreathModuleStateChannel to call
        // channel.start(). complete() → complete causes channel.end().

        expect(
          harness.channel.startCalls,
          isNotEmpty,
          reason: 'channel.start must have been called after resume',
        );
        expect(
          harness.channel.endCount,
          1,
          reason: 'channel.end must be called exactly once after complete',
        );

        // ── Output channel 3: isLive placeholder ──────────────────────────
        //
        // Placeholder is wired in [[05-breath-derive-lifecycle-islive]].
        // Verify it is readable without throwing.

        expect(harness.isLive, isFalse);
      },
    );
  });
}
