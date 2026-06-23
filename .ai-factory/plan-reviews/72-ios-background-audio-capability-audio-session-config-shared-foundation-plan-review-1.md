# Plan Review: iOS background-audio capability + audio-session config (shared foundation)

**Plan:** `72-ios-background-audio-capability-audio-session-config-shared-foundation.md`
**Files Reviewed:** 4 plan tasks against the live codebase
**Risk Level:** 🟢 Low

## Verification against the codebase

Every assumption in the plan was checked against the actual files:

- **`packages/mind_audio/pubspec.yaml`** — confirmed `just_audio: ^0.10.5` present, no `audio_session` direct dependency. Task 1 is correct. (`audio_session` is already a transitive dep of `just_audio`, but declaring it directly is the right move so `mind_audio` can `import` it without a `depend_on_referenced_packages` lint — matches the project's documented pattern for `meta` in ROADMAP line 115.)
- **`packages/mind_audio/lib/mind_audio.dart`** — confirmed the four existing `export 'src/...'` lines; adding `export 'src/audio_session_config.dart';` alongside them (Task 2) is consistent with the file's structure.
- **`packages/mind_audio/lib/src/`** — confirmed `audio_looper.dart` exists; Task 2's "do not touch `audio_looper.dart`" guard is meaningful and correct.
- **`lib/Core/App.dart`** — confirmed `WidgetsFlutterBinding.ensureInitialized();` at line 142, immediately after the observe-init line. Task 3's placement ("after `ensureInitialized()`, before any player/audio code") is accurate; no player is constructed in `initialize()` (players are created later by `AudioLooper.initialize` at session start), so configuring the global session first is correct ordering.
- **`lib/Core/App.dart` header** — the STYLE RULE banner (single-line initializers, no trailing commas) is real and Task 3 correctly calls it out.
- **`ios/Runner/Info.plist`** — confirmed no `UIBackgroundModes` key exists today; the root `<dict>` has `UI*` keys (`UIApplicationSceneManifest`, `UILaunchStoryboardName`, etc.). Task 4's placement guidance is valid.
- **Cross-references** — notes 138/139/140/142 and ROADMAP Phase 51 (line 245) all describe this exact milestone with the same `playback + mixWithOthers` policy. The plan is internally and externally consistent with the roadmap.

## Context Gates

- **ARCHITECTURE.md** — present. No boundary violation: the config helper lives in `mind_audio` (the package that owns audio), and the app consumes it via the existing `mind_audio: { path: ... }` dependency. Correct layering. **PASS**
- **RULES.md** — `WARN` (non-blocking). RULES says *"Never add module-specific state, streams, or triggers to App.dart — App.dart is infrastructure only."* `configureAudioSession()` is a one-shot global call with no state, stream, or trigger, and the iOS audio session is genuinely app-wide infrastructure (like the DB/gRPC client), so it fits the "infrastructure only" intent rather than violating it. Flagging only so the implementer keeps it a bare one-line call and does not let it grow module-specific logic.
- **ROADMAP.md** — `PASS`. Directly implements the first unchecked item of Phase 51 (line 245); linkage is explicit.

## Critical Issues

None. The plan is implementable as written.

## Minor Notes (non-blocking)

1. **Android-side config is intentionally omitted.** The proposed `AudioSessionConfiguration` sets only the two iOS `avAudioSession*` fields and leaves Android fields (`androidAudioAttributes`, `androidAudioFocusGainType`, `androidWillPauseWhenDucked`) unset. This is fine for this milestone — Android keep-alive is handled by the foreground service (note 139), and the plan correctly states the call is "harmless on Android." No change needed; noting it so it is a conscious decision rather than an oversight.
2. **`const` constructor.** The snippet uses `const AudioSessionConfiguration(...)`. `AudioSessionConfiguration` and the enum option values are const-constructible in the `audio_session` package, so this compiles — good. The implementer should keep the version unpinned (Task 1) so the resolver picks the `audio_session` release co-tested with `just_audio 0.10.5`.
3. **Tooling reminder (implementation detail, not a plan defect).** Project memory notes Flutter lives at `/usr/local/bin/flutter`; `flutter pub add audio_session` (Task 1) must be run from inside `packages/mind_audio/` so it lands in the package pubspec, not the root app.
4. **Verification is manual-only and device-gated.** "Settings: Testing: no" plus a physical-iOS-device verification path is appropriate here — background audio cannot be validated on the simulator and there is no pure-logic unit to assert. Reasonable for a foundation milestone with no user-visible behavior change.

## Positive Notes

- Strong "why-not" guardrails: explicitly rejecting `AudioSessionConfiguration.music()` (interrupts other audio) and the `ambient` category (stops in background), with the reasoning inline. This prevents the most likely wrong implementation.
- Dependency placement reasoning is sound — `audio_session` belongs in `mind_audio` because the helper that uses it lives there, and the app already transitively consumes it via the path dependency.
- Task ordering and dependencies (`Task 2 → 1`, `Task 3 → 2`, `Task 4` independent) are correct and minimal.
- The plan correctly scopes this as foundation-only and sets expectations that nothing is user-visible yet (breath still self-pauses per note 140; meditation has no audio per note 142), avoiding a false "feature delivered" impression.

PLAN_REVIEW_PASS
