# Plan Review 2: Android foreground service keep-alive (mechanism + wire to module-session lifecycle)

**Plan:** `73-android-foreground-service-keep-alive-mechanism-wire-to-module-session-lifecycle.md`
**Risk Level:** 🟢 Low — both blocking issues from review-1 are resolved, and all codebase assumptions verified against source.

## Resolution of review-1 findings

- **Critical 1 (FGS health prerequisite) — RESOLVED.** The plan now declares and runtime-requests `ACTIVITY_RECOGNITION`, which is a valid runtime prerequisite for a `health`-typed FGS on Android 14+ (alongside `BODY_SENSORS` / `HIGH_SAMPLING_RATE_SENSORS`). Task 4 aborts `start()` if it is denied, and the "Decisions" block names `specialUse` as the documented fallback. The reasoning (external BLE HR does not satisfy `BODY_SENSORS`) is correct.
- **Critical 2 (DI / localization) — RESOLVED.** `ForegroundKeepAlive` now takes `String Function() currentLanguageCode` via constructor; Task 6 wires it as `() => appSettingsNotifier.currentState.language` over the local instance, with no `App.shared` read. This satisfies the RULES.md "inject via constructor" rule.
- **Medium 3 (tools:replace) — RESOLVED.** Task 2 adds `xmlns:tools` + `tools:replace="android:foregroundServiceType"` and ties the manifest setup to the pinned version.
- **Medium 4 (API surface) — RESOLVED.** Task 4 sequences `init` before `startService`, awaits and inspects `ServiceRequestResult`, and pins the version in Task 1.
- **Medium 5 (start/stop race) — RESOLVED.** `_wantRunning` desired-state flag with a re-check after the awaits.
- **Medium 6 / POST_NOTIFICATIONS UX — acknowledged** as a non-blocking deferred note.

## Verification against codebase

- **`App.dart` wiring location** — `moduleStateChannel` at `App.dart:213`, `biometricStreamClient` at `App.dart:222`; the suggested insertion point is accurate. `App._(...)` field/constructor pattern at `App.dart:230-257` matches the described approach (add a `keepAliveCoordinator` field to keep the subscription referenced). ✔
- **`appSettingsNotifier`** is the local in `initialize()` (`App.dart:206`), supplied to the `ProviderScope` via `appSettingsProvider.overrideWith(...)` (`App.dart:267`). `currentState` getter exists (`AppSettingsNotifier.dart:43`) and `AppSettingsState.language` is a `String` (`AppSettingsState.dart:3`). The closure-invoked-at-session-start reasoning correctly sidesteps the Riverpod "read before build" hazard review-1 raised. ✔
- **Event variants** — `ModuleStateEvent` is `sealed` with exactly `ModuleSessionStarted/Paused/Unpaused/Ended/Abandoned` (`ModuleStateEvent.dart:1-14`); the branch logic matches. `moduleStateChannel.events` is a broadcast subject already consumed by `BiometricStreamClient`, so a second subscriber is safe. ✔
- **`lookupAppLocalizations(Locale)`** exists at `app_localizations.dart:875` and is exported via the package barrel. ✔
- **Permission pattern** — `NeiryBciProvider.dart:117-122` uses the `permission_handler` `[...].request()` batch pattern the plan mirrors. `permission_handler: ^11.4.0` is present. ✔
- **Manifest** — `android/app/src/main/AndroidManifest.xml` currently has no `xmlns:tools` and no FGS permissions, confirming Task 2's additions are needed. `minSdk = 26`, `targetSdk = flutter.targetSdkVersion` (`build.gradle.kts:28-29`) — so API-29 `ACTIVITY_RECOGNITION` and API-33 `POST_NOTIFICATIONS` degrade gracefully on older devices, and the Android-14 prerequisite logic applies on current targets. ✔

## Context Gates

### Architecture (`.ai-factory/ARCHITECTURE.md`) — PASS
The coordinator/wrapper pair is app-wide infrastructure driven by `ModuleStateChannel`, consistent with `biometricStreamClient` / `instructionStream` wiring in `App.dart`. The review-1 boundary smell (reaching into `App.shared`) is gone — inputs are constructor-injected.

### Rules (`.ai-factory/RULES.md`) — PASS
- "All dependencies injected via constructor" — satisfied (locale source and event stream both injected).
- "Never add module-specific state to App.dart" — not violated; keep-alive is cross-module infrastructure, like `biometricStreamClient`. The coordinator owns its own subscription rather than being wired from outside.

### Roadmap (`.ai-factory/ROADMAP.md`) — WARN (non-blocking)
The plan documents that the milestone already exists at `ROADMAP.md:247` with spec note `139-android-foreground-service-keepalive.md`, and that per the planning workflow it does not edit `ROADMAP.md`. Traceability is recorded; no action required.

## Remaining notes (non-blocking)

- **Silent degradation if `ACTIVITY_RECOGNITION` is denied.** Task 4 correctly aborts `start()` on denial — but that means keep-alive never engages on devices where the user declines the prompt, which is exactly when the isolate gets suspended. This is an inherent tradeoff of the `health` type and is already acknowledged (with the `specialUse` fallback) in the Decisions block. Worth a `logPrint` at warning level on abort so the failure is diagnosable from logs rather than invisible. The plan already specifies logging the abort, which covers this.
- **`ACTIVITY_RECOGNITION` is a Play "sensitive" permission.** Declaring it may require a Play Console data-safety / permissions justification at release time. Out of code scope, but flag it to the release owner alongside the health-app declaration already noted.
- **Task-handler isolate callback.** For pure keep-alive newer `flutter_foreground_task` majors allow omitting the `TaskHandler` callback, but the exact `startService` signature varies by major. Task 4 already defers this to "confirm against the pinned API (Task 1)" — correct posture; just make sure the pinned version's example is followed verbatim for the `@pragma('vm:entry-point')` requirement if a callback is needed.

## Recommendation

The plan is implementation-ready. Both review-1 blockers are resolved, the manifest/permission strategy is internally consistent with the chosen `health` type, the DI is clean, and every file path / API reference checks out against the current source. Remaining items are release-time product concerns, not plan defects.

PLAN_REVIEW_PASS
