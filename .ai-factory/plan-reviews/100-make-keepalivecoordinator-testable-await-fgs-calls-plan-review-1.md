# Plan Review: Make `KeepAliveCoordinator` testable — await FGS calls

**Plan:** `.ai-factory/plans/100-make-keepalivecoordinator-testable-await-fgs-calls.md`
**Target:** `lib/Core/Background/KeepAliveCoordinator.dart`
**Risk Level:** 🟢 Low

## Verdict

The plan is small, correct, and faithful to its source milestone (`ROADMAP.md` line 326). Every concrete instruction matches the actual code:

- The real file uses a named `void _onEvent(ModuleStateEvent event)` method (not the inline-closure form shown in the referenced test-plan note `180`). The plan correctly works against the actual method — it is more accurate than its own referenced note.
- All six `ModuleStateEvent` sealed subtypes are accounted for (`ModuleSessionStarted/Resumed/Paused/Unpaused/Ended/Abandoned`) — the switch stays exhaustive after the change.
- `ForegroundKeepAlive.start()` / `.stop()` are indeed `Future<void>` and idempotent, so awaiting them is safe.
- The `_subscription` field is nullable (`StreamSubscription<…>?`), not `late`, so the unchanged constructor guard (`if (!Platform.isAndroid) return;`) leaves it `null` without a late-init error. Plan's "keep as-is" instruction is correct.

### Technical correctness of the async listener

The plan's claim that `Stream.listen` accepts an `async` handler is correct: `Future<void> Function(ModuleStateEvent)` is assignable to `listen`'s `void Function(T)?` parameter because `Future<void>` is a subtype of `void` in Dart. The listener does not await the returned future, so production semantics are preserved as stated. No `flutter_lints` rule is triggered — `discarded_futures`/`avoid_void_async` are not part of `package:flutter_lints/flutter.yaml` (the project's only lint set), so the async callback will not produce a new analyzer warning.

## Advisory (non-blocking)

### 1. The await change alone does not make the coordinator unit-testable on the host VM

This is the most important thing for whoever writes the follow-up tests to understand. The plan's title says "make testable," but the actual blocker to host unit testing is the **constructor guard `if (!Platform.isAndroid) return;`**, which the plan explicitly preserves. On the Flutter test host (macOS/Linux), `Platform.isAndroid` is `false`, so the constructor returns early, **never creates the subscription**, and `_onEvent` is never invoked — no `start()`/`stop()` call can be observed regardless of the await change.

Note this diverges from the established project pattern for the sibling "Make X testable" milestones (`ActiveRrSource`, `BiometricBatcher`, `GrpcConnectionManager`, `AuthCodeDeeplinkHandler` — ROADMAP lines 107–113), which all achieve testability by **injecting** the untestable dependency (clock, timer factory, `Random`, callback). This milestone was deliberately narrowed by the roadmap to *only* await the futures, so the plan is faithful — but be aware the coordinator's Android subscription path remains unreachable from a plain `flutter test` until the platform check is also abstracted/injected.

Also flag for the test author: the test-plan note `180` (gotcha #1, "Practical approach") suggests `debugDefaultTargetPlatformOverride = TargetPlatform.android` to exercise the Android path. **That override affects `defaultTargetPlatform` from `flutter/foundation` only — it does NOT change `dart:io`'s `Platform.isAndroid`.** That guidance will not work as written; testing the subscription path would require either an integration test on Android or injecting platform detection. This is a note-`180` problem, not a plan defect, but it undercuts the plan's stated "testable" goal.

### 2. Marginal value of awaiting for determinism

Each event triggers exactly one FGS call, so awaiting provides no intra-event ordering benefit, and since `listen` does not await the handler, a test must still pump the microtask queue either way. The change is harmless and matches the milestone, but the practical "deterministic teardown" gain over the current fire-and-forget form is modest. No action needed — just calibrating expectations.

### 3. Parallel coordinator left untouched (out of scope)

`lib/MeditationModule/Core/MeditationKeepAliveCoordinator.dart` has the same fire-and-forget pattern (`_player.start()` / `.stop()` not awaited in a sync `_onState`). It is correctly out of scope for this milestone; noting only for future consistency.

## Positive Notes

- Scope is precisely bounded to one file and one method; no public API change, no migration, no proto/codegen impact, no DI wiring change in `App.dart`.
- The plan correctly preserves the `// ignore: unused_field` GC-prevention comment and the platform guard, avoiding accidental regressions.
- Settings (Testing: no, Logging: minimal, Docs: no) are appropriate for a behavior-preserving refactor.

PLAN_REVIEW_PASS
