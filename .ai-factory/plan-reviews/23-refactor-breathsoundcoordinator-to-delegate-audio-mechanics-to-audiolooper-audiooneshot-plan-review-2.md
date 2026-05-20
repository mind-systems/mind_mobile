# Plan Review #2: Refactor `BreathSoundCoordinator` to delegate audio mechanics

**Plan:** `.ai-factory/plans/23-refactor-breathsoundcoordinator-to-delegate-audio-mechanics-to-audiolooper-audiooneshot.md`
**Spec:** `.ai-factory/notes/07-refactor-breathsoundcoordinator.md`
**Previous review:** `.ai-factory/plan-reviews/23-...-plan-review-1.md`

## Context Gates

- **ARCHITECTURE.md** (`.ai-factory/ARCHITECTURE.md`): No conflicts. The refactor reduces responsibility inside `packages/breath_module` and pushes mechanics down the dependency stack into `packages/mind_audio` — a pure-Dart-ish package with no domain knowledge. The module boundary is preserved.
- **RULES.md** (`.ai-factory/RULES.md`): All three rules satisfied. Rule 3 in particular (constructor injection) is honored — `AudioLooper`, `AudioOneShot`, and `AudioCatalog?` are all injected through the constructor. The catalog default (`?? AssetAudioCatalog()`) is constructor-time, not external wiring.
- **ROADMAP.md** (`.ai-factory/ROADMAP.md`, line 45): The Phase 13 open milestone matches this plan verbatim. Linkage is clear.

All gates pass.

## Resolution of plan-review #1 concerns

| # | Concern (review #1) | Status in v2 |
|---|--------------------|--------------|
| 1 | Race: listeners may fire before `_looper` has players → NPE on `fadeIn/fadeOut` | **Resolved.** Task 3 prescribes an exact, ordered sequence inside `_initAudio()`: catalog await → `unawaited(_looper.initialize(sources))` → tick load → attach `_tickSub` → attach `_stateListener`. The accompanying rationale correctly explains why `unawaited(_looper.initialize(...))` is safe (sync prelude assigns `_activePlayer` before any internal await — verified at `packages/mind_audio/lib/src/audio_looper.dart:27-28`). The "Race-condition note" preamble in the plan (lines 8–11) makes the intent of this ordering explicit. |
| 2 | Redundant `if (_currentStatus != BreathSessionStatus.breath) return;` guard in status branch | **Resolved.** Task 4 explicitly tells the implementer NOT to add the guard, with reasoning. Worth confirming the spec note (`notes/07-refactor-breathsoundcoordinator.md:105`) — the spec still shows the guard, but Task 4 in the plan overrides it with the correct rationale, which is the document the implementer follows. |
| 3 | `_isInitialized` flag should be mandatory, not optional | **Resolved.** Task 2 adds `bool _isInitialized = false;` as a new field; Task 3 uses `if (_isInitialized) return; _isInitialized = true;` at the top of `initialize`. The reasoning is restated in Task 3 ("could be reused outside `BreathSessionScreen`; double-init would leak…"). |
| 4 | `reset()` fade-timer cleanup ownership | **Resolved.** Task 5 confirms `AudioLooper.stop()` cancels both timers internally and cites the source location (verified at `audio_looper.dart:74-77`). |
| 5 | Debug-log cleanup | **Resolved.** Task 4 specifies removing references to deleted fields (`_activeLoop`, `_loopPlayerA`, `volA`/`volB`). |
| 6 | `just_audio` import orphaning | **Resolved.** Task 1 enumerates the specific types that disappear (`AudioPlayer`, `AudioSource`, `LoopMode`, `ClippingAudioSource`, `ConcatenatingAudioSource`) and confirms `mind_audio` does not re-export them (verified at `packages/mind_audio/lib/mind_audio.dart`). |
| 7 | `dart:math` import retention | **Resolved.** Task 1 explicitly says "Keep `import 'dart:math';` — `_computeFadeDuration` still calls `pow(...)`." |
| 8 | Smoke test for runtime NPE | **Resolved.** Task 8 adds a manual smoke test with explicit pass criteria, including verifying no `Null check operator used on null value` exception at session start. |

Every blocking concern from review #1 is addressed.

## Critical Issues

None. The plan is correctness-aligned with the existing code and with `mind_audio`'s contract.

## Minor Issues

### M1. Catalog await window may drop early state events the OLD code captured

This is a behavior-difference worth flagging, not a correctness bug.

In the OLD coordinator, `initialize(...)` is synchronous and `_stateListener = viewModel.listen(_onStateChanged)` is attached **before** `viewModel.initState()` runs (`BreathSessionScreen.dart:71-78`). Every state transition emitted by `_setupEngine` and subsequent `_onEngineState` updates is captured.

In the NEW design, the listener attaches **after** `await Future.wait(_phaseOrder.map(_catalog.sourceFor))`. On cold start the sidecar JSON loads (`rootBundle.loadString(...)` × 3) can plausibly take longer than `service.getSession(sessionId)` plus the first `_setupEngine` emit, in which case the listener misses one or more early `set state = ...` events. `viewModel.listen` is backed by a non-replaying `StreamController.broadcast` (`BreathSessionViewModel.dart:35,42-45`), so missed events are gone forever.

In practice this is **not** a correctness regression because:
- Step 1's load-gate (`loadState != SessionLoadState.ready`) makes early states no-ops anyway.
- `_currentStatus` and `_currentPhase` start as `null`, so the first state that DOES reach the listener and passes the gate enters the status-change branch and processes `inhale`/`exhale`/`hold` correctly via the `_phaseAssets.containsKey(state.phase) && state.phase != _currentPhase` sub-case.

But a few subtler edge cases are worth noting for the implementer's smoke test (Task 8):
- If `loadState` transitions through `loading → ready` during the catalog window with no other state change before user input, the gate transition itself is missed — fine, because subsequent user-driven transitions still pass the gate.
- If the first state the listener sees is `BreathSessionStatus.pause` (e.g. user backgrounded the app before audio booted), it calls `_looper.fadeOut(...)` on a fresh looper with both volumes at 0.0 — harmless no-op.

No plan edit required, but I recommend the implementer **explicitly verify Task 8 case (a)** — that the very first inhale loop is audible on a cold launch on a slow Android device. That is the realistic scenario where catalog loading could lose meaningful events.

### M2. `_oneShot.load` errors are silently dropped

In `_initAudio()` and in step 2 of `_onStateChanged`, the chain `_catalog.sourceFor(...).then(_oneShot.load)` is `unawaited`. `AudioOneShot.load` is `async`, so any exception (e.g. asset missing in a bad build) is dropped on the floor with no log. The OLD code's `_loadTickAsset` had the same hole, so this is parity-preserving, not a regression — but if the implementer wants to add minimal logging (project setting is "Logging: minimal"), this would be a natural place: `.then(_oneShot.load).catchError((e) { if (kDebugMode) debugPrint('[Sound] tick load failed: $e'); })`. Optional.

### M3. Spec/plan divergence on `_currentStatus != breath` guard

The spec at `notes/07-refactor-breathsoundcoordinator.md:104-107` still prescribes the domain guard:

```dart
if (_currentStatus != BreathSessionStatus.breath) return;
_looper.crossfadeTo(_phaseOrder.indexOf(phase), fadeDuration);
```

The plan (Task 4) correctly overrides this in the status-branch sub-case (the guard is always false there, was the right call from review #1). However, the spec text in the notes file was not updated, which could confuse a future reader who cross-references the two. Not a plan defect — it's a documentation drift. If you want to be tidy, also update `notes/07-refactor-breathsoundcoordinator.md:104-107` to drop the guard. Not blocking.

### M4. Phase-change branch (step 4) loses the implicit status guard

A related observation, also non-blocking: the OLD code's step 4 phase-change branch called `unawaited(_switchToPhase(state.phase, ...))`, and `_switchToPhase` had an internal `if (_currentStatus != BreathSessionStatus.breath) { BAIL; return; }` check at lines 262 and 274. That check guarded against a phase-change event arriving while status is `rest` / `pause` / `complete` — e.g. if a hypothetical state update changed phase but not status during a rest period.

The NEW code drops that guard entirely (Task 4 explicitly says step 4 calls `_looper.crossfadeTo(...)` for known phases without a status check). In today's state-machine, step 3 always fires first on a status change and returns before step 4 runs, so the only way step 4 fires is when status is unchanged. If the status hadn't been `breath` previously, no phase loop was playing, and crossfading from silence to a loop is musically wrong if status is `rest`.

I traced the state-machine path and could not find a code path where `state.phase` changes from one `_phaseAssets`-known value to another without `state.status` also being (or becoming) `breath`. So today this is safe. Plan-review #1 already accepted this. Flagging only so the implementer knows that if a future state-machine change starts emitting phase updates during `rest`, the missing guard will produce audible regressions — preferable to defensively add `if (_currentStatus != BreathSessionStatus.breath) return;` at the top of the step-4 known-phase branch, but optional now.

### M5. `import 'dart:async'` retention

Task 1 says "Keep `dart:async` (used by `StreamSubscription`, `unawaited`, `Future`)". Confirmed — after the refactor `StreamSubscription? _tickSub` and `unawaited(...)` calls still exist. Good catch already in the plan.

## Positive Notes

- The "Race-condition note (from plan-review #1)" preamble inside the plan (lines 8–11) is excellent — it preserves the design rationale inside the artifact that gets handed to the implementer, so the next reader doesn't have to dig through plan-review history to understand why the listener attach order matters.
- Task 3's example code block makes the ordering literal — no room for ambiguity. The rationale paragraph below it correctly grounds the `unawaited(_looper.initialize(sources))` safety claim in the synchronous prelude of `AudioLooper.initialize`.
- File paths, line numbers, and call-site enumerations in Task 6 are accurate (verified `BreathSessionScreen.dart:13,38,66,75,102,113,119`; line 280 not verified but trusted from review #1).
- Sidecar JSON files exist for the loop assets (`assets/audio/ohm_*.ogg.meta.json` confirmed present), so `AssetAudioCatalog` will produce `ClippingAudioSource` instances for them — the click-elimination benefit is wired up by default. Tick assets correctly have no sidecar (they're one-shots, no loop-boundary click possible).
- `mind_audio` is already a dependency in `packages/breath_module/pubspec.yaml:15-16` from milestone 22 — Task 1's import addition will resolve immediately with no `flutter pub get` needed.
- Task 8 explicitly acknowledges that static analysis can't catch the NPE risk, and prescribes the exact runtime checks (a–e). Realistic smoke-test criteria.

## Verdict

The plan addresses every concern from plan-review #1, the architectural fit is correct, the call-site update is minimal and accurate, and the runtime risks are explicitly mitigated with both an ordering prescription and a smoke-test gate. M1–M5 are minor — none block implementation.

PLAN_REVIEW_PASS
