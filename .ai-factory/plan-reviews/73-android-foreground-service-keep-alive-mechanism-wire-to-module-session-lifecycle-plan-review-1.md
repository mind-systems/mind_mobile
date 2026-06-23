# Plan Review: Android foreground service keep-alive (mechanism + wire to module-session lifecycle)

**Plan:** `73-android-foreground-service-keep-alive-mechanism-wire-to-module-session-lifecycle.md`
**Risk Level:** 🟡 Medium — the core wiring is sound and matches the codebase, but the chosen `health` foreground-service type has an unhandled Android 14+ permission prerequisite, and the localization access path violates the project DI rule.

## What the plan gets right

- **Event model is accurate.** `ModuleStateChannel` exposes `events` as a broadcast `PublishSubject` (`lib/Core/Grpc/ModuleStateChannel.dart:22,25`), and `ModuleStateEvent` has exactly the variants the plan branches on — `ModuleSessionStarted`, `ModuleSessionEnded`, `ModuleSessionAbandoned`, `ModuleSessionPaused`, `ModuleSessionUnpaused` (`lib/Core/Grpc/ModuleStateEvent.dart`). Adding a second subscriber alongside `BiometricStreamClient` is safe (broadcast subject).
- **No missed-start risk.** `KeepAliveCoordinator` is constructed in `App.initialize()` before any session can start, and `PublishSubject` does not replay — so subscribing at init is the correct ordering.
- **Wiring location is right.** `BiometricStreamClient` is already built from `moduleStateChannel.events` at `lib/Core/App.dart:222`, immediately after `moduleStateChannel`. Instantiating the keep-alive there mirrors existing infrastructure wiring.
- **Dependencies confirmed.** `permission_handler: ^11.4.0` is present (`pubspec.yaml:84`); `lookupAppLocalizations(Locale)` exists and is exported via the package barrel (`packages/mind_l10n/lib/mind_l10n.dart` → `l10n/app_localizations.dart:875`).
- **Manifest target is correct.** Permissions/service belong in `android/app/src/main/AndroidManifest.xml`; flavor manifests (`dev`/`prod`/`debug`/`profile`) only add intent-filters and merge into main. `minSdk = 26` (`android/app/build.gradle.kts:28`), so the API-33/34 permissions degrade gracefully on older devices.

## Context Gates

### Architecture (`.ai-factory/ARCHITECTURE.md`) — WARN
The coordinator/wrapper pair is cross-module infrastructure (drives off the app-wide `ModuleStateChannel`), consistent with how `biometricStreamClient` and `instructionStream` are wired in `App.dart`. That part aligns. The boundary smell is `ForegroundKeepAlive.start()` reaching into the `App.shared` singleton for the language (see Critical Issue 2) — infrastructure classes elsewhere take their inputs via constructor.

### Rules (`.ai-factory/RULES.md`) — ERROR
> "All dependencies must be injected via constructor. … if a class needs a stream or dependency, pass it in the constructor."

Task 4 has `ForegroundKeepAlive.start()` read `App.shared.appSettingsNotifier...language` — a hidden global dependency, not constructor-injected. This violates the rule. (The "no module state in App.dart" rule is **not** violated — keep-alive is infrastructure, like `biometricStreamClient`.)

### Roadmap (`.ai-factory/ROADMAP.md`) — WARN
This is a `feat` with no corresponding milestone entry in `ROADMAP.md`. Add a roadmap line linking this work for traceability (the project's convention records each phase/task with its spec note).

## Critical Issues

### 1. `FOREGROUND_SERVICE_HEALTH` has an unmet runtime prerequisite (Android 14+) — blocking
Task 2 picks `foregroundServiceType="health"` + `FOREGROUND_SERVICE_HEALTH`. On Android 14 (API 34+, and `targetSdk = flutter.targetSdkVersion` is almost certainly ≥34), starting a `health`-typed foreground service additionally requires the app to **hold one of** `BODY_SENSORS`, `HIGH_SAMPLING_RATE_SENSORS`, or `ACTIVITY_RECOGNITION`. The manifest declares none of these today (only `BLUETOOTH_SCAN`/`BLUETOOTH_CONNECT`/`ACCESS_FINE_LOCATION≤30`). Without a prerequisite permission, `startForeground` throws `SecurityException` and the service never starts — the keep-alive silently fails exactly on the OS versions that suspend the isolate.

Note: heart rate arrives from an **external BLE device**, which does *not* satisfy `BODY_SENSORS` (that gates on-device sensors). So "we read pulse" does not auto-qualify.

Resolve one of:
- Add and request a qualifying permission (e.g. `ACTIVITY_RECOGNITION`, runtime-requested via `permission_handler`), **or**
- Choose a type whose prerequisite the app already meets. Given breath sessions play continuous audio (`mind_audio` / `BreathSoundCoordinator`) and iOS already relies on background audio, `mediaPlayback` is a candidate — but it requires an active `MediaSession` in a playing state on Android 14, which meditation (often silent) may not have. `specialUse` is the fallback but needs a Play Console justification.

Whichever is chosen, the plan must state the type's runtime prerequisite and how it is satisfied.

### 2. Localization access violates DI and is fragile against Riverpod lifecycle — should fix
Task 4 resolves strings via `lookupAppLocalizations(Locale(App.shared.appSettingsNotifier...language))`. Two problems:
- **DI rule (ERROR above):** reaching into `App.shared` is a hidden global dependency.
- **Riverpod lifecycle:** `AppSettingsNotifier extends Notifier<AppSettingsState>` (`lib/Core/AppSettings/AppSettingsNotifier.dart`). Its `state`/`currentState` are only valid after the provider has been built inside the `ProviderScope` (it is supplied via `appSettingsProvider.overrideWith(() => appSettingsNotifier)` at `App.dart:267`). Reading `.currentState` on the raw instance works in practice only because `MaterialApp` reads the provider for `locale` at startup (`App.dart:295`) — but it is an undocumented ordering dependency on Riverpod internals and will throw `StateError` if ever read before first provider access.

Recommend injecting the language/locale source into `ForegroundKeepAlive` via constructor — e.g. a `String Function() currentLanguageCode` (or a `Locale Function()`), wired in `App.dart` from `appSettingsNotifier.currentState.language`. Keeps the wrapper pure and rule-compliant.

## Medium / Should-address

### 3. Manifest `tools:replace` for `foregroundServiceType` is unmentioned
The current `main/AndroidManifest.xml` has **no** `xmlns:tools` namespace. Recent `flutter_foreground_task` versions declare the service (and restart receiver) in the plugin's own manifest, which then merges into yours. To set `android:foregroundServiceType` on that merged service node you typically must add `xmlns:tools="http://schemas.android.com/tools"` to `<manifest>` and `tools:replace="android:foregroundServiceType"` on the service. The plan's "declare the service and its receiver per plugin docs" is version-dependent and may double-declare or fail the merge. Action: pin the version from `flutter pub add`, then follow that exact version's setup (the receiver is auto-merged in newer versions; manual re-declaration can conflict).

### 4. `flutter_foreground_task` API specifics under-specified
`FlutterForegroundTask.init(...)` (Android notification options/channel) must be called before `startService`, and `startService(...)` is **async** returning a `ServiceRequestResult` that should be awaited/checked. For pure keep-alive no background task-handler isolate callback is required, but confirm against the pinned API surface (it changes across major versions). Make the `start()` flow `await` init + start and log failures.

### 5. Async race between `start()` and a fast `stop()`
`start()` awaits permission + init before `FlutterForegroundTask.startService`. A very short session (start → end within that await window) could run `stop()` first, leaving the service running after the session ended. A single "already running" boolean does not cover this. Track desired state (e.g. a `bool _wantRunning`) and re-check it after the awaits before actually starting, so a `stop()` that arrived mid-`start()` wins.

### 6. POST_NOTIFICATIONS requested mid-session-start (UX note)
Requesting `Permission.notification` inside `start()` pops the system dialog the first time a session begins. If denied, the foreground service still runs but the notification is suppressed on API 33+ — keep-alive still functions. Acceptable, but worth noting; consider requesting earlier (e.g. onboarding) for a cleaner first session.

## Minor / Confirmations
- `KeepAliveCoordinator` guarding the whole class with `Platform.isAndroid` and only building the subscription on Android is correct; instantiating a no-op on iOS in `App.dart` is fine. Hold the `StreamSubscription` in a field (the plan does).
- Adding `keepAliveCoordinator` as an `App` field keeps it referenced (prevents GC of the subscription) — correct.
- Stopping on both `ModuleSessionEnded` and `ModuleSessionAbandoned` is right; `ABANDONED` is a distinct terminal status emitted by `_processProtoEvent` (`ModuleStateChannel.dart:136-138`).

## Recommendation
Address Critical Issues 1 and 2 before implementation, and fold in Medium items 3–5. The lifecycle wiring and event model are correct; the risk is concentrated in the Android FGS-type prerequisite and the localization/DI access path.
