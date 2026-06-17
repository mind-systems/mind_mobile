import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breath_module/breath_module.dart'
    show
        BreathExerciseDTO,
        BreathPhase,
        BreathSessionDTO,
        BreathSessionState,
        BreathSessionStatus,
        BreathStepDTO,
        BreathViewModel,
        IBreathSessionCoordinator,
        IBreathSessionService,
        ITickService,
        TickData,
        TickSource,
        breathViewModelProvider;

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeTickService implements ITickService {
  final _controller = StreamController<TickData>.broadcast();

  @override
  Stream<TickData> get tickStream => _controller.stream;

  @override
  TickSource get source => TickSource.timer;

  @override
  Stream<TickSource> get sourceChanges => const Stream.empty();

  @override
  bool trySwitchTo(TickSource target) => false;

  void tick([int intervalMs = 1000]) => _controller.add(TickData(intervalMs));

  @override
  void dispose() => _controller.close();
}

class _FakeCoordinator implements IBreathSessionCoordinator {
  @override
  void openConstructor(String sessionId) {}
  @override
  void shareSession(String sessionId) {}
  @override
  void dismiss() {}
}

/// Override: observeSession returns const Stream.empty() to prevent the
/// live-update re-setup from firing a second _setupEngine call, which would
/// rebuild the timelineSteps list, reset the engine to paused, and offset
/// the Riverpod publication baseline — all of which would break the
/// per-tick publication and identity tests in this suite.
class _FakeSessionService implements IBreathSessionService {
  final BreathSessionDTO dto;

  _FakeSessionService(this.dto);

  @override
  Future<BreathSessionDTO> getSession(String id) async => dto;

  @override
  Future<BreathSessionDTO> starSession(String id,
          {required bool starred}) async =>
      dto;

  @override
  Stream<BreathSessionDTO> observeSession(String id) => const Stream.empty();

  @override
  Stream<void> observeSessionDeletion(String id) => const Stream.empty();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// One exercise: inhale 2 ticks + exhale 2 ticks (cycleDuration = 4, repeatCount = 1).
/// Tick behaviour after resume():
///   tick 1 → inhale, remainingTicks 2→1  (tick-only: no structural change)
///   tick 2 → inhale→exhale, remainingTicks 2  (structural: phase flip)
///   tick 3 → exhale, remainingTicks 2→1  (tick-only)
///   tick 4 → cycle ends → status→complete  (structural)
BreathSessionDTO _makeDTO() {
  return BreathSessionDTO(
    id: 'test-session',
    description: 'Test',
    isStarred: false,
    canStar: true,
    exercises: [
      BreathExerciseDTO(
        steps: [
          BreathStepDTO(phase: BreathPhase.inhale, duration: 2),
          BreathStepDTO(phase: BreathPhase.exhale, duration: 2),
        ],
        restDuration: 0,
        repeatCount: 1,
        shape: null,
      ),
    ],
  );
}

ProviderContainer _makeContainer({
  required _FakeTickService tickService,
  required _FakeSessionService service,
}) {
  final vm = BreathViewModel(
    tickService: tickService,
    service: service,
    coordinator: _FakeCoordinator(),
    sessionId: 'test-session',
  );
  return ProviderContainer(
    overrides: [breathViewModelProvider.overrideWith(() => vm)],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeTickService tickService;
  late ProviderContainer container;

  setUp(() {
    tickService = _FakeTickService();
  });

  tearDown(() {
    container.dispose();
    tickService.dispose();
  });

  // =========================================================================
  // Task 4 — Riverpod publication suppressed on tick-only updates
  //
  // Canonical ordering: read notifier → initState → pump → resume → pump →
  // attach listener (fireImmediately: false) → drive ticks.
  // =========================================================================

  group('Riverpod publication suppressed on tick-only updates', () {
    test('should not publish to Riverpod when a tick only advances remainingTicks',
        () async {
      final service = _FakeSessionService(_makeDTO());
      container = _makeContainer(tickService: tickService, service: service);
      final vm = container.read(breathViewModelProvider.notifier);

      await vm.initState();
      await pumpEventQueue();
      vm.resume();
      await pumpEventQueue();

      var count = 0;
      container.listen<BreathSessionState>(
        breathViewModelProvider,
        (_, __) => count++,
        fireImmediately: false,
      );

      // tick 1: phase stays inhale, only remainingTicks 2→1 (excluded field)
      tickService.tick();
      await pumpEventQueue();

      expect(count, 0);
    });

    test('should publish to Riverpod exactly once when the phase flips',
        () async {
      final service = _FakeSessionService(_makeDTO());
      container = _makeContainer(tickService: tickService, service: service);
      final vm = container.read(breathViewModelProvider.notifier);

      await vm.initState();
      await pumpEventQueue();
      vm.resume();
      await pumpEventQueue();

      var count = 0;
      container.listen<BreathSessionState>(
        breathViewModelProvider,
        (_, __) => count++,
        fireImmediately: false,
      );

      tickService.tick(); // tick 1: tick-only (no publication)
      await pumpEventQueue();
      tickService.tick(); // tick 2: structural — phase inhale→exhale
      await pumpEventQueue();

      expect(count, 1);
    });

    test('should publish to Riverpod when status transitions to complete',
        () async {
      final service = _FakeSessionService(_makeDTO());
      container = _makeContainer(tickService: tickService, service: service);
      final vm = container.read(breathViewModelProvider.notifier);

      await vm.initState();
      await pumpEventQueue();
      vm.resume();
      await pumpEventQueue();

      final published = <BreathSessionState>[];
      container.listen<BreathSessionState>(
        breathViewModelProvider,
        (_, next) => published.add(next),
        fireImmediately: false,
      );

      tickService.tick(); // tick 1: tick-only
      await pumpEventQueue();
      tickService.tick(); // tick 2: structural (phase flip)
      await pumpEventQueue();
      tickService.tick(); // tick 3: tick-only
      await pumpEventQueue();
      tickService.tick(); // tick 4: structural (status→complete)
      await pumpEventQueue();

      // Two structural publications: phase flip (tick 2) + complete (tick 4).
      expect(published.length, 2);
      expect(published.last.status, BreathSessionStatus.complete);
    });
  });

  // =========================================================================
  // Task 5 — Raw vm.stream fires on every update including tick-only
  //
  // Baseline established after resume() settles so init/resume emits
  // don't pollute the per-tick count.
  // =========================================================================

  group('raw vm.stream fires on every update including tick-only', () {
    test('should emit on vm.stream for every tick including tick-only updates',
        () async {
      final service = _FakeSessionService(_makeDTO());
      container = _makeContainer(tickService: tickService, service: service);
      final vm = container.read(breathViewModelProvider.notifier);

      await vm.initState();
      await pumpEventQueue();
      vm.resume();
      await pumpEventQueue();

      // Subscribe after resume settles — baseline is 0 events.
      final events = <BreathSessionState>[];
      vm.stream.listen(events.add);

      tickService.tick(); // tick 1: tick-only → still emits on raw stream
      await pumpEventQueue();
      tickService.tick(); // tick 2: structural
      await pumpEventQueue();
      tickService.tick(); // tick 3: tick-only → still emits on raw stream
      await pumpEventQueue();

      expect(events.length, 3);
    });

    test('should not emit on vm.stream while paused', () async {
      final service = _FakeSessionService(_makeDTO());
      container = _makeContainer(tickService: tickService, service: service);
      final vm = container.read(breathViewModelProvider.notifier);

      await vm.initState();
      await pumpEventQueue();
      // Do NOT call resume — engine stays in pause state.

      final events = <BreathSessionState>[];
      vm.stream.listen(events.add);

      // Ticks while paused: _onTick returns early, nothing emitted.
      tickService.tick();
      await pumpEventQueue();
      tickService.tick();
      await pumpEventQueue();

      expect(events, isEmpty);
    });
  });

  // =========================================================================
  // Task 6 — remainingTicksNotifier advances on every tick
  // =========================================================================

  group('remainingTicksNotifier advances on every tick', () {
    test('should update remainingTicksNotifier on each tick where the value changes',
        () async {
      final service = _FakeSessionService(_makeDTO());
      container = _makeContainer(tickService: tickService, service: service);
      final vm = container.read(breathViewModelProvider.notifier);

      await vm.initState();
      await pumpEventQueue();
      vm.resume();
      await pumpEventQueue();

      // Attach listener after resume settles (baseline = 0 calls).
      var notifierCallCount = 0;
      vm.remainingTicksNotifier.addListener(() => notifierCallCount++);

      // Tick values: 2→1 (tick 1), 1→2 (tick 2), 2→1 (tick 3) — all change.
      tickService.tick(); // tick 1
      await pumpEventQueue();
      tickService.tick(); // tick 2
      await pumpEventQueue();
      tickService.tick(); // tick 3
      await pumpEventQueue();

      expect(notifierCallCount, 3);
    });

    test('should keep remainingTicksNotifier value in sync with the engine remainingTicks',
        () async {
      final service = _FakeSessionService(_makeDTO());
      container = _makeContainer(tickService: tickService, service: service);
      final vm = container.read(breathViewModelProvider.notifier);

      await vm.initState();
      await pumpEventQueue();
      vm.resume();
      await pumpEventQueue();

      // Collect raw-stream events so we can compare against the engine value.
      // vm.currentState (Riverpod) is intentionally stale on tick-only ticks —
      // always compare against vm.stream, not vm.currentState.
      final streamEvents = <BreathSessionState>[];
      vm.stream.listen(streamEvents.add);
      final notifier = vm.remainingTicksNotifier;

      tickService.tick(); // tick 1: remainingTicks 2→1
      await pumpEventQueue();
      expect(notifier.value, streamEvents.last.remainingTicks);

      tickService.tick(); // tick 2: remainingTicks 1→2 (exhale phase starts)
      await pumpEventQueue();
      expect(notifier.value, streamEvents.last.remainingTicks);

      tickService.tick(); // tick 3: remainingTicks 2→1
      await pumpEventQueue();
      expect(notifier.value, streamEvents.last.remainingTicks);
    });
  });

  // =========================================================================
  // Task 7 — timelineSteps reference preserved across ticks, invalidated by restartEngine()
  //
  // Canonical ordering: read notifier → initState → pump →
  // capture vm.currentState.timelineSteps → resume → pump → drive ticks.
  // observeSession is Stream.empty() so no second _setupEngine call fires.
  // =========================================================================

  group('timelineSteps reference identity', () {
    test('should preserve the timelineSteps reference across multiple ticks',
        () async {
      final service = _FakeSessionService(_makeDTO());
      container = _makeContainer(tickService: tickService, service: service);
      final vm = container.read(breathViewModelProvider.notifier);

      await vm.initState();
      await pumpEventQueue();

      // Capture before resume: _setupEngine has run exactly once.
      final captured = vm.currentState.timelineSteps;

      vm.resume();
      await pumpEventQueue();

      // Mix of tick-only (1, 3) and structural (2) — reference must survive all.
      tickService.tick(); // tick 1: tick-only (Riverpod suppressed)
      await pumpEventQueue();
      expect(identical(vm.currentState.timelineSteps, captured), isTrue);

      tickService.tick(); // tick 2: structural (phase flip, Riverpod updates)
      await pumpEventQueue();
      expect(identical(vm.currentState.timelineSteps, captured), isTrue);

      tickService.tick(); // tick 3: tick-only
      await pumpEventQueue();
      expect(identical(vm.currentState.timelineSteps, captured), isTrue);
    });

    test('should rebuild the timelineSteps list on restartEngine', () async {
      final service = _FakeSessionService(_makeDTO());
      container = _makeContainer(tickService: tickService, service: service);
      final vm = container.read(breathViewModelProvider.notifier);

      await vm.initState();
      await pumpEventQueue();

      final captured = vm.currentState.timelineSteps;

      vm.resume();
      await pumpEventQueue();

      // restartEngine → _setupEngine builds a brand-new list.
      vm.restartEngine();
      await pumpEventQueue();

      expect(identical(vm.currentState.timelineSteps, captured), isFalse);
    });
  });
}
