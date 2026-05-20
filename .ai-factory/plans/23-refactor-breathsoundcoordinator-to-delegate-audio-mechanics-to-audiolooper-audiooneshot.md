# Plan: Refactor `BreathSoundCoordinator` to delegate audio mechanics to `AudioLooper` + `AudioOneShot`

## Context

`BreathSoundCoordinator` currently owns two `AudioPlayer` instances, fade timers, the ping-pong crossfade state machine, and the tick one-shot player. The `mind_audio` package now provides `AudioLooper` (ping-pong crossfade) and `AudioOneShot` (pre-buffered tick), which already encapsulate this mechanics. This milestone strips the mechanics out of the coordinator and delegates them, leaving only domain orchestration (phase/status/tick-source change handling, fade-duration computation, suspend gating). The constructor signature change breaks the call site in `BreathSessionScreen.dart`, so both files must change atomically. Full spec: `.ai-factory/notes/07-refactor-breathsoundcoordinator.md`.

### Race-condition note (from plan-review #1)

In the existing coordinator, `initialize(...)` is synchronous: `AudioPlayer` instances and `_activeLoop` are assigned before listeners attach, so every `_fadePlayer(_activeLoop!, ...)` call has a non-null target. In the new design, source construction is **async** because `AssetAudioCatalog.sourceFor(...)` awaits `rootBundle.loadString(...)` for the JSON sidecar. `AudioLooper.fadeIn` / `fadeOut` bang on `_activePlayer!`, which is only assigned synchronously inside `AudioLooper.initialize(...)`. If `_stateListener` is attached before that runs, any incoming `pause` / `breath` / `rest` / `complete` event will throw `Null check operator used on null value`.

Mitigation in this plan: **attach `_tickSub` and `_stateListener` only after `_looper.initialize(sources)` has been called**, inside an async helper. The synchronous `initialize(BreathSessionState)` only stores state and kicks off the helper.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Coordinator refactor

- [x] **Task 1: Replace imports and constructor in `BreathSoundCoordinator`**
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Add `import 'package:mind_audio/mind_audio.dart';`. Remove `import 'package:just_audio/just_audio.dart';` — after Tasks 2/3/4/5 no `just_audio` types (`AudioPlayer`, `AudioSource`, `LoopMode`, `ClippingAudioSource`, `ConcatenatingAudioSource`) remain in the file, and `mind_audio` does not re-export them. Keep `import 'dart:math';` — `_computeFadeDuration` still calls `pow(...)`. Keep `dart:async` (used by `StreamSubscription`, `unawaited`, `Future`). Replace the constructor with the spec-defined signature: `required this.viewModel`, `required AudioLooper looper`, `required AudioOneShot oneShot`, optional `AudioCatalog? catalog`. Initialize three new `final` fields: `_looper = looper`, `_oneShot = oneShot`, `_catalog = catalog ?? AssetAudioCatalog()`.

- [x] **Task 2: Remove the old audio fields and helper methods from `BreathSoundCoordinator`**
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Delete fields: `_loopPlayerA`, `_loopPlayerB`, `_activeLoop`, `_inactiveLoop`, `_fadeTimerA`, `_fadeTimerB`, `_switchGen`, `_tickPlayer`, `_loadFuture`. Delete methods: `_switchToPhase` (and all its `if (kDebugMode) debugPrint(...)` lines), `_fadePlayer`, `_cancelFadeFor`, `_loadTickAsset`. Keep: `viewModel`, `_phaseOrder`, `_phaseAssets`, `_tickAssets`, `_kFadeCoeff`, `_kMinFadeMs`, `_kMaxFadeMs`, `_computeFadeDuration`, `_currentPhase`, `_currentStatus`, `_isSuspended`, `_currentTickSource`, `_stateListener`, `_tickSub`, `_ts` helper. Add a new `bool _isInitialized = false;` field — used by Task 3.

- [x] **Task 3: Rewrite `initialize(BreathSessionState initialState)` with explicit ordering**
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  `initialize` becomes a thin sync wrapper that idempotency-guards on `_isInitialized` and delegates to a private async helper. **Listeners must not be attached until after `_looper.initialize(sources)` has been called synchronously**, because `AudioLooper.fadeIn/fadeOut` dereference `_activePlayer!` which is only assigned inside `AudioLooper.initialize`. Use this exact shape:

  ```dart
  void initialize(BreathSessionState initialState) {
    if (_isInitialized) return;
    _isInitialized = true;
    _currentTickSource = initialState.tickSource;
    if (kDebugMode) debugPrint('${_ts()} [Sound] initialize start');
    unawaited(_initAudio());
  }

  Future<void> _initAudio() async {
    final sources = await Future.wait(
      _phaseOrder.map((p) => _catalog.sourceFor(AudioTrack(_phaseAssets[p]!))),
    );
    unawaited(_looper.initialize(sources));
    unawaited(
      _catalog
        .sourceFor(AudioTrack(_tickAssets[_currentTickSource]!))
        .then(_oneShot.load),
    );
    _tickSub = viewModel.tickStream.listen((_) => _onTick());
    _stateListener = viewModel.listen(_onStateChanged);
    if (kDebugMode) debugPrint('${_ts()} [Sound] initialize ready — listeners attached');
  }
  ```

  Rationale: `AudioLooper.initialize` is itself `async`, but its **synchronous prelude** (the part before the first `await`) constructs both `AudioPlayer`s and assigns `_activePlayer`/`_inactivePlayer` before returning the future. Calling it without awaiting is therefore safe — `_activePlayer` is non-null by the time the next statement runs. The `Future.wait` over catalog sources must remain awaited because `_looper.initialize` needs the resolved `List<AudioSource>`. The `_isInitialized` flag is mandatory (not optional): the class is exported by the package and could be reused outside `BreathSessionScreen`; double-init would leak duplicate `_tickSub` / `_stateListener` registrations.

- [x] **Task 4: Rewrite `_onStateChanged` status branch and phase branch**
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Keep the four-step structure (load gate, tick-source change, status change, phase change). In the status branch (after `_currentStatus = state.status;`):
  - `BreathSessionStatus.pause` → `_looper.fadeOut(const Duration(milliseconds: 200));`
  - `BreathSessionStatus.breath` with `_phaseAssets.containsKey(state.phase) && state.phase != _currentPhase` → set `_currentPhase`, compute `fadeDuration`, call `_looper.crossfadeTo(_phaseOrder.indexOf(state.phase), fadeDuration);`. **Do not add an `if (_currentStatus != BreathSessionStatus.breath) return;` guard here** — `_currentStatus` was just assigned to `state.status` (= `breath`), so the guard is always false and would mislead future readers. The original guard belonged inside the async `_switchToPhase` to catch post-await races; the synchronous `_looper.crossfadeTo` site does not need it (the looper's own `_switchGen` already handles in-flight cancellation).
  - `BreathSessionStatus.breath` else branch → `_looper.fadeIn(const Duration(milliseconds: 200));`
  - `BreathSessionStatus.complete` / `rest` → `_looper.fadeOut(const Duration(milliseconds: 500));`

  In the tick-source-change branch (step 2) replace `unawaited(_loadTickAsset(_currentTickSource))` with `unawaited(_catalog.sourceFor(AudioTrack(_tickAssets[_currentTickSource]!)).then(_oneShot.load));`.

  In the phase-change branch (step 4), for known phases compute `fadeDuration` and call `_looper.crossfadeTo(_phaseOrder.indexOf(state.phase), fadeDuration);`; for unknown phases call `_looper.fadeOut(const Duration(milliseconds: 500));`.

  Keep the `if (kDebugMode) debugPrint(...)` lines but strip references to removed fields (`_activeLoop`, `_loopPlayerA`, `volA`/`volB`) — log only `status`, `phase`, `_currentPhase` and `_currentStatus`.

- [x] **Task 5: Rewrite `_onTick`, `suspend`, `resume`, `reset`, `dispose`**
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  `_onTick`: keep the `_isSuspended` and `allowTick` gating; replace `unawaited(player.seek(...).then((_) => player.play()))` with `_oneShot.play();`. `suspend`: keep `_isSuspended = true;` and replace tick-player stop with `_oneShot.stop();`. `resume`: unchanged (`_isSuspended = false;`). `reset`: replace player loops with `_looper.stop(); _oneShot.stop();` and keep `_currentPhase = null; _currentStatus = null;`. Drop the manual `_fadeTimerA/B?.cancel()` lines — `AudioLooper.stop()` cancels both timers internally (verified in `packages/mind_audio/lib/src/audio_looper.dart:74-77`). `dispose`: replace player disposes with `_looper.dispose(); _oneShot.dispose();` while keeping `_tickSub?.cancel(); _tickSub = null;` and `_stateListener?.call(); _stateListener = null;`.

### Phase 2: Call site update

- [x] **Task 6: Update `BreathSessionScreen` construction site** (depends on Tasks 1–5)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  Add `import 'package:mind_audio/mind_audio.dart';` near the existing imports. Replace line 66 `_soundCoordinator = BreathSoundCoordinator(viewModel: viewModel);` with:
  ```dart
  _soundCoordinator = BreathSoundCoordinator(
    viewModel: viewModel,
    looper: AudioLooper(),
    oneShot: AudioOneShot(),
  );
  ```
  Leave lines 75 (`_soundCoordinator.initialize(initialState)`), 102, 113, 119, and 280 — all other `_soundCoordinator` calls (`initialize`, `dispose`, `suspend`, `resume`, `reset`) — untouched.

### Phase 3: Verification

- [x] **Task 7: Compile-check the package** (depends on Task 6)
  Files: none
  Run `/usr/local/bin/flutter analyze packages/breath_module` and confirm no errors. Resolve any stragglers from removed fields (e.g. dangling references in debug logs, accidentally swept-up `dart:math` import).

- [ ] **Task 8: Manual smoke test** (depends on Task 7)
  Files: none
  Static analysis cannot catch the runtime NPE risk flagged in plan-review #1, and project settings disable automated tests for this milestone. Run the app (`/usr/local/bin/flutter run --flavor dev -t lib/main_dev.dart`), start a breath session, and verify: (a) inhale / exhale / hold loops audibly crossfade, (b) tick sounds fire during rest/pause, (c) pause → resume restores audio, (d) session completion fades to silence cleanly, (e) no `Null check operator used on null value` exception is logged at session start.
