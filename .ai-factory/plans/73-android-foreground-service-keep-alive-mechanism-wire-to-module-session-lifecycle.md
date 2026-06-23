# Plan: Android foreground service keep-alive (mechanism + wire to module-session lifecycle)

## Context
Hold an Android foreground service for the duration of any active module session (breath OR meditation) so the OS does not suspend the isolate after ~1 minute in the background. The service is driven by the app-wide `ModuleStateEvent` stream that already feeds `BiometricStreamClient`, so one wiring covers both modules.

## Decisions (resolved from plan-review-1)
- **FGS type = `health`, prerequisite satisfied by `ACTIVITY_RECOGNITION`.** On Android 14+ (`targetSdk = flutter.targetSdkVersion` ≥ 34) a `health`-typed foreground service additionally requires the app to hold one of `BODY_SENSORS` / `HIGH_SAMPLING_RATE_SENSORS` / `ACTIVITY_RECOGNITION` at runtime, or `startForeground` throws `SecurityException`. External BLE heart rate does **not** satisfy `BODY_SENSORS`. We declare and runtime-request `ACTIVITY_RECOGNITION` (the least-intrusive qualifier; requestable via `permission_handler`). Fallback if product rejects the extra prompt: switch the type to `specialUse` with a manifest subtype property + Play Console justification — not chosen here to keep the Play health-app path the note decided on.
- **No hidden globals.** `ForegroundKeepAlive` takes its locale source via a constructor-injected `String Function() currentLanguageCode` — it must not read `App.shared`. Resolves the RULES.md DI ERROR from the review.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Dependency & Android manifest

- [x] **Task 1: Add `flutter_foreground_task` dependency and pin the version**
  Files: `pubspec.yaml`
  Run `flutter pub add flutter_foreground_task` (use the full Flutter path `/usr/local/bin/flutter`; never hand-edit `pubspec.yaml`). **Record the resolved version** — Task 2's manifest setup and Task 4's API surface are version-dependent (service/receiver auto-merge and `startService` signature changed across majors). `permission_handler: ^11.4.0` is already present (`pubspec.yaml:84`) and is reused for `ACTIVITY_RECOGNITION` + `POST_NOTIFICATIONS`.

- [x] **Task 2: Declare permissions, service, and receiver in AndroidManifest** (depends on Task 1)
  Files: `android/app/src/main/AndroidManifest.xml`
  Add `<uses-permission>` entries:
  - `android.permission.WAKE_LOCK`
  - `android.permission.FOREGROUND_SERVICE`
  - `android.permission.FOREGROUND_SERVICE_HEALTH` (Android 14+ typed permission for `health`)
  - `android.permission.ACTIVITY_RECOGNITION` (Android 14+ **runtime prerequisite** for starting a `health`-typed FGS — without it `startForeground` throws on API 34+)
  - `android.permission.POST_NOTIFICATIONS` (Android 13+)

  Service/receiver: recent `flutter_foreground_task` versions declare the service and restart receiver in the **plugin's own manifest**, which merges into the app manifest. To set `android:foregroundServiceType="health"` on that merged `<service>` node, add `xmlns:tools="http://schemas.android.com/tools"` to the `<manifest>` element and apply `tools:replace="android:foregroundServiceType"` on the service entry. Follow the **exact pinned version's** setup docs (Task 1) — do not blindly re-declare the service/receiver, which can double-declare or break the merge. The `foregroundServiceType` must match the granted `FOREGROUND_SERVICE_HEALTH` permission. (Play Console health-app declaration is a one-time release step, not code — out of scope.)

### Phase 2: Localization & keep-alive mechanism

- [x] **Task 3: Add notification ARB keys and regenerate localizations**
  Files: `packages/mind_l10n/lib/l10n/app_en.arb`, `packages/mind_l10n/lib/l10n/app_ru.arb`
  Add two keys for the foreground-service notification — a title and a body (e.g. `keepAliveNotificationTitle` / `keepAliveNotificationBody`) conveying "Session in progress". Provide English and Russian values matching the style of neighboring entries. Regenerate `AppLocalizations` via the package's l10n codegen. The generated top-level `lookupAppLocalizations(Locale)` (exported from `packages/mind_l10n/lib/mind_l10n.dart`) resolves strings without a `BuildContext`.

- [x] **Task 4: Create `ForegroundKeepAlive` wrapper** (depends on Task 1, Task 3)
  Files: `lib/Core/Background/ForegroundKeepAlive.dart`
  Wrap `flutter_foreground_task` behind a class with `start()` and `stop()`. Constructor takes `String Function() currentLanguageCode` (no `App.shared` access). State fields: `bool _wantRunning` (desired state) and `bool _running` (actual). Behavior:
  - `start()`:
    1. Guard `Platform.isAndroid` (no-op otherwise).
    2. Set `_wantRunning = true`. If already `_running`, return (idempotent).
    3. Ensure runtime permissions via `permission_handler`, mirroring the request pattern in `lib/Bci/NeiryBciProvider.dart`: request `Permission.activityRecognition` (required prerequisite — if denied, log and abort start; the service cannot legally run) and `Permission.notification` (request if not granted; denial is non-fatal — service still runs, notification suppressed on API 33+).
    4. `await FlutterForegroundTask.init(...)` with Android notification options (channel id/name, `foregroundServiceType` health) — `init` must precede `startService`. Resolve title/body via `lookupAppLocalizations(Locale(currentLanguageCode()))`.
    5. **Re-check `_wantRunning` after the awaits** — if a `stop()` arrived during the permission/init window, do not start (handles the fast start→stop race; Critical/Medium item 5).
    6. `await FlutterForegroundTask.startService(...)`, inspect the returned `ServiceRequestResult`, log failure via `logPrint`, set `_running = true` on success.
  - `stop()`: guard `Platform.isAndroid`; set `_wantRunning = false`; `await FlutterForegroundTask.stopService()`; set `_running = false`. Idempotent (safe when not running). Do not hold the wakelock past `stop()`.
  Log start/stop and failures at minimal level via `logPrint` (`package:mind/Logger.dart`). For pure keep-alive no background task-handler isolate callback is needed — confirm against the pinned API (Task 1).

### Phase 3: Lifecycle coordinator & wiring

- [x] **Task 5: Create `KeepAliveCoordinator`** (depends on Task 4)
  Files: `lib/Core/Background/KeepAliveCoordinator.dart`
  Constructor-inject `ForegroundKeepAlive foregroundKeepAlive` and `Stream<ModuleStateEvent> moduleStateEvents` (the broadcast `moduleStateChannel.events` `PublishSubject` already consumed by `BiometricStreamClient`). Guard the whole class with `Platform.isAndroid` — only build the subscription on Android (iOS uses background audio per notes 138/140/142); on iOS construct a no-op. On events: `ModuleSessionStarted` → `foregroundKeepAlive.start()`; `ModuleSessionEnded` || `ModuleSessionAbandoned` → `foregroundKeepAlive.stop()` (stop on abandon too, so a reaped session releases the wakelock); ignore `ModuleSessionPaused` / `ModuleSessionUnpaused`. Hold the `StreamSubscription` in a field. `PublishSubject` does not replay, and the coordinator is built in `App.initialize()` before any session starts, so no start can be missed.

- [x] **Task 6: Wire `KeepAliveCoordinator` into `App.initialize()`** (depends on Task 5)
  Files: `lib/Core/App.dart`
  After `moduleStateChannel`/`biometricStreamClient` are constructed (around `App.dart:222`), instantiate:
  - `final foregroundKeepAlive = ForegroundKeepAlive(currentLanguageCode: () => appSettingsNotifier.currentState.language);` — inject the locale source as a closure over the local `appSettingsNotifier` (do not read `App.shared`). `appSettingsNotifier.currentState` is valid here because the closure is only invoked later, at session start, after `ProviderScope` is built (`App.dart:267`).
  - `final keepAliveCoordinator = KeepAliveCoordinator(foregroundKeepAlive: foregroundKeepAlive, moduleStateEvents: moduleStateChannel.events);`

  Add a `final KeepAliveCoordinator keepAliveCoordinator;` field on `App`, include it in the private `App._({...})` constructor and the `App._(...)` call (this keeps the subscription referenced / prevents GC). Follow the existing `App.dart` initializer style — no trailing commas on single-line initializer calls inside `initialize()`. No provider override is required.

## Notes / deferred (non-blocking)
- **POST_NOTIFICATIONS UX:** requesting it inside the first `start()` pops the system dialog at first session start. Acceptable (keep-alive still works if denied). A cleaner first-session experience would request it during onboarding — out of scope for this milestone.
- **Roadmap traceability:** per the planning workflow this plan does not edit `ROADMAP.md`; the milestone already lives at `ROADMAP.md:247` with spec note `.ai-factory/notes/139-android-foreground-service-keepalive.md`.

## Commit Plan
- **Commit 1** (tasks 1-2): "Add foreground service dependency and Android manifest declarations"
- **Commit 2** (tasks 3-4): "Add localized keep-alive notification and ForegroundKeepAlive wrapper"
- **Commit 3** (tasks 5-6): "Wire KeepAliveCoordinator to module-session lifecycle"
