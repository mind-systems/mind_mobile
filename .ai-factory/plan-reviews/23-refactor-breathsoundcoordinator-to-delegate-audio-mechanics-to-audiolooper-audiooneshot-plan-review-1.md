# Plan Review: Refactor `BreathSoundCoordinator` to delegate audio mechanics

**Plan:** `.ai-factory/plans/23-refactor-breathsoundcoordinator-to-delegate-audio-mechanics-to-audiolooper-audiooneshot.md`
**Spec:** `.ai-factory/notes/07-refactor-breathsoundcoordinator.md`

## Context Gates

- **ARCHITECTURE.md:** No conflicts found — the refactor strictly reduces coverage in `packages/breath_module` and uses the existing `mind_audio` boundary.
- **RULES.md:** No conflicts. The looper / oneShot dependencies are injected through the constructor (Rule 3 — constructor injection). `_catalog` is also resolved at construction time with a sane default.
- **ROADMAP.md:** Phase 13's open milestone matches this plan exactly (line 45 in `ROADMAP.md`).

All gates pass.

## Critical Issues

### 1. Race condition: listeners may fire before `_looper` has players (potential NPE)

This is the only real correctness risk in the plan, and it is not addressed.

In the **current** coordinator, `initialize(...)` is synchronous: `AudioPlayer` instances are constructed immediately, `_activeLoop` is assigned synchronously, and only **then** are `_tickSub` and `_stateListener` attached. Every subsequent call to `_fadePlayer(_activeLoop!, ...)` has a non-null target.

In the **new** design (Task 3), source construction is async because `_catalog.sourceFor(...)` awaits `rootBundle.loadString(...)` for the JSON sidecar:

```dart
final sources = await Future.wait(_phaseOrder.map((p) => _catalog.sourceFor(AudioTrack(_phaseAssets[p]!))));
unawaited(_looper.initialize(sources));
// ... listener attachment ...
```

`AudioLooper.fadeIn` / `fadeOut` (used in Task 4) bang on a nullable internal:

```dart
// packages/mind_audio/lib/src/audio_looper.dart
void fadeOut(Duration duration) => _fadePlayer(_activePlayer!, 0.0, duration);
void fadeIn(Duration duration)  => _fadePlayer(_activePlayer!, 1.0, duration);
```

`_activePlayer` is only assigned **inside** `AudioLooper.initialize` — so until the catalog `Future.wait` resolves and `_looper.initialize(sources)` runs its synchronous prelude, `_activePlayer` is `null`. If `_stateListener` is attached **before** the await on the catalog completes, any status change that arrives in that window — pause → breath, breath → rest, breath → complete — calls `_looper.fadeOut/fadeIn(...)` and throws `Null check operator used on null value`.

The plan should make the listener-attachment order explicit. Two acceptable shapes:

**Option A (preferred — preserve old ordering):** attach listeners only after `_looper.initialize(sources)` has been called (i.e. inside the async helper, after the catalog await):

```dart
void initialize(BreathSessionState initialState) {
  if (_isInitialized) return;
  _isInitialized = true;
  _currentTickSource = initialState.tickSource;
  unawaited(_initAudio(initialState));
}

Future<void> _initAudio(BreathSessionState initialState) async {
  final sources = await Future.wait(
    _phaseOrder.map((p) => _catalog.sourceFor(AudioTrack(_phaseAssets[p]!))),
  );
  unawaited(_looper.initialize(sources));            // _activePlayer is set sync inside
  unawaited(_catalog.sourceFor(AudioTrack(_tickAssets[_currentTickSource]!)).then(_oneShot.load));
  _tickSub = viewModel.tickStream.listen((_) => _onTick());
  _stateListener = viewModel.listen(_onStateChanged);
}
```

**Option B:** add a coordinator-level `bool _audioReady = false;` set after `_looper.initialize(sources)` is called, and short-circuit `_onStateChanged` on `!_audioReady` (same place as the current load-gate). Listeners can then be attached synchronously.

Either way, the plan must call this out — currently Task 3 ends with the vague clause *"Wrap the catalog/source build in an async helper if needed so `initialize` can stay `void`"* without prescribing where the listener attach lines go, and the literal sequence given ("Re-attach `_tickSub = …` and `_stateListener = …`") is ambiguous about whether those run before or after the catalog await.

This is a genuine bug risk because the session ViewModel can publish `BreathSessionStatus.pause` synchronously on `initState`-driven flows (e.g. background-restore paths landed in roadmap items "Auto-pause breath session" and "Add `suspend()`/`resume()` API").

### 2. Redundant guard in Task 4 status branch — harmless but misleading

Task 4 prescribes for the `BreathSessionStatus.breath` phase-change subcase:

> set `_currentPhase`, compute `fadeDuration`, guard `if (_currentStatus != BreathSessionStatus.breath) return;` then `_looper.crossfadeTo(...)`

But Task 4 also keeps the original structure where `_currentStatus = state.status;` is assigned **before** the `switch (state.status)`. Inside the `breath` case, `_currentStatus` is therefore already `BreathSessionStatus.breath`, so the guard can never be true. The original guard lived inside the async `_switchToPhase()` to catch races *after* an await — it doesn't translate to the synchronous `_looper.crossfadeTo(...)` site.

Drop the guard at this call site, or move the entire status branch above the assignment. Otherwise future readers will misread the intent. (No functional impact today.)

## Minor Issues

### 3. Removing the idempotency guard

Task 3 says: *"Remove the old idempotency guard (`if (_loopPlayerA != null) return;`); replace with a boolean `_isInitialized` flag if guarding is still needed, or rely on the call site"*.

The call site (`BreathSessionScreen.initState`) is the only caller and it runs exactly once per screen lifetime, so *technically* relying on the call site is safe. However:
- The class is reusable outside of `BreathSessionScreen` (it's exported via the package).
- Double-init would now create two leaking `_tickSub` and `_stateListener` registrations and double-load the catalog.

Prefer the explicit `_isInitialized` flag — it's two lines and removes a footgun. This is worth promoting from "if needed" to "always do this".

### 4. `reset()` — fade-timer cleanup ownership

Task 5 simplifies `reset()` to `_looper.stop(); _oneShot.stop();` and drops the manual `_fadeTimerA/B?.cancel()` lines. This is correct — `AudioLooper.stop()` cancels both timers internally (verified in `audio_looper.dart:74-77`). No issue, just confirming.

### 5. Debug log cleanup (Task 4)

Task 4 says: *"strip references to removed fields (`_activeLoop`, `_loopPlayerA`, `volA`/`volB`) — log only `status`, `phase`, `_currentPhase` and `_currentStatus`."* This is fine, but note that the current logs are heavy and quite useful for the next time someone debugs phase audio. Implementer should also remove the now-meaningless `_switchToPhase` log lines that are scattered across the original `_switchToPhase` body (since the method is deleted entirely — covered implicitly by Task 2, just worth a sanity reminder).

### 6. `import 'package:just_audio/just_audio.dart'` removal

Task 1 says remove the `just_audio` import. Confirm by scanning the file post-edit — `AudioPlayer`, `AudioSource`, `LoopMode`, `ConcatenatingAudioSource`, `ClippingAudioSource` are all gone after Tasks 2/3/4/5. The `mind_audio` re-exports do not re-export `just_audio` types (verified in `packages/mind_audio/lib/mind_audio.dart`), so the import is genuinely orphaned — good.

### 7. `dart:math` import

After removing `_fadePlayer`, the `pow(...)` call in `_computeFadeDuration` is still used (line 77 in the existing file), so `dart:math` must stay. Plan does not mention removing it, which is correct. Worth verifying after implementation that it isn't accidentally swept up.

### 8. Phase 3 verification — `flutter analyze` is sufficient but not complete

Task 7 runs `flutter analyze packages/breath_module`. That catches static issues but not the runtime NPE flagged in issue #1. Recommend the implementer also do a smoke test: start a session and verify that audio actually plays through inhale/exhale/hold + tick sounds. The plan settings (`Testing: no`) explicitly skip tests, so a manual smoke is the only protection.

## Positive Notes

- File path and call-site line numbers in Task 6 are accurate (verified `BreathSessionScreen.dart:66` and the untouched lines 75, 102, 113, 119, 280).
- The plan correctly identifies the atomic-ship requirement (constructor signature change breaks the call site — Task 6 depends on Tasks 1–5).
- Construction defaults (`catalog ?? AssetAudioCatalog()`) match the package's actual API.
- Tick-source change handling (Task 4) faithfully replaces `_loadTickAsset` with the same pattern used in `initialize`, preserving symmetry.
- The plan keeps the four-step `_onStateChanged` structure (load-gate → tick-source → status → phase) which is the right call — that structure has been hardened by the previous Phase 12 bug-fix milestones.

## Recommended Plan Edits Before Implementation

1. **Task 3 — make the listener-attach ordering explicit.** Replace *"if needed"* with a concrete sequence: catalog await → `_looper.initialize(sources)` → tick-source load → `_tickSub` → `_stateListener`. Either rely on this ordering or add a `_audioReady` short-circuit at the top of `_onStateChanged`.
2. **Task 3 — make `_isInitialized` mandatory** rather than optional.
3. **Task 4 — drop the `if (_currentStatus != BreathSessionStatus.breath) return;` guard** from the breath-status branch (it's always false at that point). Keep it in any phase-change-only path if the implementer chooses to defer logic there, but in the synchronous flow described it serves no purpose.

These are mechanical changes — the overall structure of the plan is sound.

---

After addressing issue #1 (the listener-attach ordering / NPE risk), this plan is ready to implement. Issues #2–#8 are polish.
