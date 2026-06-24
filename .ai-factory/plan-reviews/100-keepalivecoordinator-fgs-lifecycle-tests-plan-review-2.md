# Plan Review 2 — KeepAliveCoordinator FGS lifecycle tests

**Plan:** `.ai-factory/plans/100-keepalivecoordinator-fgs-lifecycle-tests.md`
**Risk Level:** 🟢 Low

## Scope

Test plan adding `test/Core/Background/keepalive_coordinator_test.dart`, plus two small,
flagged production seam changes to make the coordinator testable.

## Verification against the codebase

Every concrete claim in the plan was checked against source. All hold:

- **`_onEvent` already awaits** — `KeepAliveCoordinator.dart:29/31/33` use `await _foregroundKeepAlive.start()/stop()`. The "Test Infra prerequisite already done" precondition is accurate (ROADMAP.md:326 marks it `[x]`).
- **Platform guard** — `KeepAliveCoordinator.dart:18` is exactly `if (!Platform.isAndroid) return;`, reading `dart:io`'s `Platform` (import line 2). Gap A is real.
- **Gap A correction is right** — `debugDefaultTargetPlatformOverride` overrides `defaultTargetPlatform` (foundation), not `dart:io Platform.isAndroid`. Note 180 explicitly recommends the override ("This is the canonical approach…"); the plan correctly flags that suggestion as wrong for this code path. Good catch.
- **Static-default constraint is correct** — `bool Function() isAndroid = _platformIsAndroid` with a `static` helper is required; a closure or instance tear-off is non-constant and trips `non_constant_default_value`. This mirrors the established seam convention in the codebase (`DateTime Function() clock = DateTime.now` in `ModuleInstructionStream.dart:54`, `BiometricStreamClient.dart:65`, `ActiveRrSource.dart:30`). Convention-aligned.
- **Production call site unchanged** — `App.dart:230` constructs with only `foregroundKeepAlive` + `moduleStateEvents`; the defaulted `isAndroid` param keeps it untouched. Confirmed.
- **Gap B is real** — `KeepAliveCoordinator` has no `dispose()`; `_subscription` carries the `// ignore: unused_field` (line 23). Sibling `MeditationKeepAliveCoordinator.dart:33` exposes `dispose()`. The proposed `void dispose() => _subscription?.cancel();` correctly uses `?.` because `_subscription` is nullable here (assigned only in the Android branch), unlike the sibling's `late final` non-nullable field.
- **Removing the stale ignore is correct** — once `dispose()` reads `_subscription`, the field is genuinely used; the ignore would become `unnecessary_ignore`.
- **Event subtypes** — all six match `ModuleStateEvent.dart`: `ModuleSessionStarted`, `ModuleSessionEnded`, `ModuleSessionAbandoned`, `ModuleSessionResumed`, `ModuleSessionPaused`, `ModuleSessionUnpaused`. The plan's constructor signatures (`{moduleSessionId}` on Started/Resumed, no-arg on the rest) are accurate.
- **Fake construction** — `ForegroundKeepAlive({required String Function() currentLanguageCode})` matches `super(currentLanguageCode: () => 'en')`. Overriding `start()`/`stop()` without `super` avoids the `FlutterForegroundTask` + `permission_handler` + `lookupAppLocalizations` calls (all in the real bodies, `ForegroundKeepAlive.dart:31-96`). The "pure-Dart, no test binding" claim is correct.
- **Async drain reasoning is sound** — the fake's `start()`/`stop()` record synchronously before any suspension, so a single microtask drain after each `.add()` deterministically settles `calls`. Draining after *each* add (as the infra section instructs) keeps the ordering assertions in Task 3 reliable, since broadcast delivery is in-order and each handler records before awaiting.
- **Milestone coverage** — the five tasks cover every case named in ROADMAP_TESTS.md:35 (Started→start, Ended→stop, Abandoned→stop, re-arm, dispose, unrelated no-op, non-Android guard).

## Context Gates

- **Architecture (ARCHITECTURE.md):** WARN — none. The seam adds no Flutter/Riverpod imports to the Core coordinator; the `dispose()` addition mirrors the sibling coordinator.
- **Rules (RULES.md):** PASS. Rule "all dependencies injected via constructor" (line 9) is honored by the `isAndroid` seam. Rule on stateless Module Services (line 7) does not apply — `KeepAliveCoordinator` is a Core coordinator, not a package `IXxxService`.
- **Roadmap:** PASS. Milestone tracked at ROADMAP_TESTS.md:35; Test Infra prerequisite (ROADMAP.md:326) confirmed complete. This is `test` work, no roadmap linkage gap.

## Notes (non-blocking)

- The plan requires production-source edits inside a "test plan." This is unavoidable (the code is untestable as-is) and the plan flags it explicitly with a fallback (Task 1 only) if SUT changes are disallowed. Acceptable and well-handled.
- `dispose()` will be dead in production (nothing calls it; the coordinator lives for the app lifetime). The plan pre-empts a future verifier flagging this by stating the intent. Good.

## Positive Notes

- Source-grounded with exact line citations that all verify.
- Proactively corrects an incorrect upstream spec suggestion (note 180's platform override) rather than copying it.
- Seam design matches existing codebase conventions precisely.
- Correctly anticipates two analyzer pitfalls (`non_constant_default_value`, `unnecessary_ignore`) before they bite the implementer.

PLAN_REVIEW_PASS
