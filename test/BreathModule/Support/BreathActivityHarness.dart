import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:breath_module/breath_module.dart'
    show BreathViewModel, BreathSessionState, BreathSessionDTO, breathViewModelProvider;
import 'package:mind/BreathModule/Core/BreathModuleStateChannel.dart';
import '../Fakes/BreathActivityFakes.dart';

/// Test-only assembler that replicates the exact wiring of
/// `BreathModule.buildSession()` with fakes — no `App.shared`, no Widget.
///
/// ## Two-phase setup
///
///   final harness = BreathActivityHarness();   // synchronous
///   await harness.init();                       // async — calls vm.initState()
///
/// ## Three output channels
///
/// 1. [states] — recorded `BreathSessionState` sequence.
/// 2. [channel] / [instructionStream] — call-log of `FakeModuleStateChannel`
///    and `FakeInstructionStream` (startCalls, pauseCount, endCount, …).
/// 3. [isLive] — placeholder for the future `isLive` lifecycle signal
///    ([[05-breath-derive-lifecycle-islive]]). Always returns `false` until
///    that milestone wires real logic here.
///
/// ## Input surface
///
/// `tick([intervalMs])`, `resume()`, `pause()`, `complete()`, `restartEngine()`.
///
/// ## Disposal
///
/// Call `dispose()` in tearDown. This calls `container.dispose()`, which
/// triggers `BreathViewModel.build()`'s `ref.onDispose`, cancelling
/// subscriptions, disposing the state machine and tick service, and closing
/// the state controller.
class BreathActivityHarness {
  // ── Fakes ────────────────────────────────────────────────────────────────

  late final FakeTickService _tickService;
  late final FakeModuleStateChannel _fakeChannel;
  late final FakeInstructionStream _fakeInstructionStream;

  // ── Internals ────────────────────────────────────────────────────────────

  late final BreathViewModel _vm;
  late final ProviderContainer _container;

  // ── Output channels ──────────────────────────────────────────────────────

  /// Recorded `BreathSessionState` sequence. Populated from `vm.stream`
  /// starting before `initState()` so the initial `SessionLoadState.ready`
  /// emission (fired inside `_setupEngine`) is never missed.
  final List<BreathSessionState> states = [];

  /// Call-log of the `FakeModuleStateChannel` injected into
  /// `BreathModuleStateChannel`. Exposes startCalls, pauseCount,
  /// unpauseCount, endCount, stopCount.
  FakeModuleStateChannel get channel => _fakeChannel;

  /// Call-log of the `FakeInstructionStream` injected into
  /// `BreathModuleStateChannel`. Exposes sendSampleCalls and phaseTickCalls.
  FakeInstructionStream get instructionStream => _fakeInstructionStream;

  /// Placeholder for the future `isLive` lifecycle signal.
  /// [[05-breath-derive-lifecycle-islive]] — wired to real logic in that milestone.
  bool get isLive => false;

  // ── Constructor ──────────────────────────────────────────────────────────

  /// Creates the harness with an optional [session] DTO.
  ///
  /// [session] defaults to `makeSession([makeExercise()])` — one exercise,
  /// inhale=2 ticks + exhale=2 ticks.
  ///
  /// [sessionId] is the session ID string injected into `BreathViewModel`
  /// and `BreathModuleStateChannel`.
  BreathActivityHarness({
    BreathSessionDTO? session,
    String sessionId = 'test-session',
  }) {
    final dto = session ?? makeSession([makeExercise()]);

    // ── Build fakes ────────────────────────────────────────────────────────

    _tickService = FakeTickService();
    _fakeChannel = FakeModuleStateChannel();
    _fakeInstructionStream = FakeInstructionStream();

    final sessionService = FakeBreathSessionService(dto);
    final coordinator = FakeBreathSessionCoordinator();

    // ── Wire BreathViewModel (same shape as BreathModule.buildSession) ──────

    _vm = BreathViewModel(
      tickService: _tickService,
      service: sessionService,
      coordinator: coordinator,
      sessionId: sessionId,
    );

    // ── Wire BreathModuleStateChannel ──────────────────────────────────────
    //
    // Subscribes to vm.stream in its constructor. Must be constructed before
    // attachModuleChannel() so the onDispose / onReset callbacks are ready.

    final moduleChannel = BreathModuleStateChannel(
      channel: _fakeChannel,
      stateStream: _vm.stream,
      instructionStream: _fakeInstructionStream,
      sessionId: sessionId,
    );

    _vm.attachModuleChannel(
      onDispose: moduleChannel.dispose,
      onReset: moduleChannel.reset,
    );

    // ── ProviderContainer ──────────────────────────────────────────────────

    _container = ProviderContainer(
      overrides: [breathViewModelProvider.overrideWith(() => _vm)],
    );

    // Trigger build() — sets up ref.onDispose hooks before initState().
    _container.read(breathViewModelProvider.notifier);

    // ── Subscribe to vm.stream BEFORE initState() ──────────────────────────
    //
    // vm.stream is a broadcast controller (BreathSessionViewModel.dart:57)
    // that does not replay. The initial SessionLoadState.ready emission fires
    // inside initState() → _setupEngine(), so a late subscription would miss it.
    _vm.stream.listen(states.add);
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Calls `vm.initState()`. Await this after construction before driving ticks.
  Future<void> init() => _vm.initState();

  /// Disposes the `ProviderContainer`, triggering `ref.onDispose` in
  /// `BreathViewModel.build()` — cancels subscriptions, disposes the state
  /// machine and tick service, and closes the state controller.
  void dispose() => _container.dispose();

  // ── Input surface ─────────────────────────────────────────────────────────

  /// Emits a single tick with [intervalMs] as the measured delta.
  void tick([int intervalMs = 1000]) => _tickService.tick(intervalMs);

  /// Resumes the breathing state machine (pause → breath).
  void resume() => _vm.resume();

  /// Pauses the breathing state machine (breath/rest → pause).
  void pause() => _vm.pause();

  /// Immediately completes the session (any status → complete).
  void complete() => _vm.complete();

  /// Restarts the state machine engine (calls `_setupEngine` again).
  void restartEngine() => _vm.restartEngine();
}
