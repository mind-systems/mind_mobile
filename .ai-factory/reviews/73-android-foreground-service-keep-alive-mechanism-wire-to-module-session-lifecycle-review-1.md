# Code Review: Android foreground service keep-alive

**Scope:** `git diff HEAD` — manifest, `App.dart`, `ForegroundKeepAlive`, `KeepAliveCoordinator`, l10n, pubspec.
**Verdict:** No blocking bugs. API surface, manifest merge, and l10n codegen all verified against the resolved package version (`flutter_foreground_task 9.2.2`). A few low-severity, non-blocking observations below.

## Verification performed

- **Plugin API surface matches the code (v9.2.2):**
  - `FlutterForegroundTask.init(...)` is declared `static void init(...)` — **not** a `Future`. The implementation correctly does **not** `await` it (the plan text said "await init", but the code is right and the plan is wrong on this point — no action needed).
  - `startService({List<ForegroundServiceTypes>? serviceTypes, required String notificationTitle, required String notificationText, ...})` returns `Future<ServiceRequestResult>` — awaited and pattern-matched on `ServiceRequestSuccess()` / `ServiceRequestFailure(:final error)`. Correct; `ServiceRequestFailure` exposes `error`.
  - `AndroidNotificationOptions({required channelId, required channelName})` — both provided.
  - `ForegroundServiceTypes.health` exists; `ForegroundTaskOptions({required eventAction, ...})` — `eventAction` is the only required field (rest default, `allowWakeLock=true`), so `ForegroundTaskOptions(eventAction: ForegroundTaskEventAction.nothing())` compiles.
- **Manifest merge is correct, no `tools:replace` needed.** The plugin's own `AndroidManifest.xml` (v9.2.2) declares only the two receivers (`RebootReceiver`, `RestartReceiver`) and the `FOREGROUND_SERVICE` / `WAKE_LOCK` / `POST_NOTIFICATIONS` / `RECEIVE_BOOT_COMPLETED` permissions — it does **not** declare `ForegroundService`. So the app manually declaring `<service android:name="com.pravera.flutter_foreground_task.service.ForegroundService" android:foregroundServiceType="health" android:exported="false"/>` is required and does **not** collide with a plugin declaration. The plan's `tools:replace` concern was version-dependent and does not apply here. `foregroundServiceType="health"` matches `serviceTypes: [ForegroundServiceTypes.health]` passed to `startService`.
- **Permissions present after merge:** `FOREGROUND_SERVICE_HEALTH` + `ACTIVITY_RECOGNITION` are added by the app; `FOREGROUND_SERVICE`, `WAKE_LOCK`, `POST_NOTIFICATIONS` come transitively from the plugin manifest. `ACTIVITY_RECOGNITION` is a valid runtime qualifier for the `health` FGS type on API 34+. (`minSdk=26`: on API <29 `ACTIVITY_RECOGNITION` is install-time and `permission_handler` auto-resolves it as granted.)
- **l10n regenerated correctly:** `keepAliveNotificationTitle` / `keepAliveNotificationBody` getters exist in `app_localizations.dart` (abstract) and both `_en` / `_ru` implementations. `lookupAppLocalizations(Locale)` is the correct context-free resolver.
- **DI / lifecycle:** `ForegroundKeepAlive` takes `String Function() currentLanguageCode` (no `App.shared` access). The closure `() => appSettingsNotifier.currentState.language` is wired over the local `appSettingsNotifier` and only invoked at session start (after `ProviderScope` is built), so reading `currentState` (= Riverpod `state`) is valid at call time. `KeepAliveCoordinator` holds the `StreamSubscription`, is `Platform.isAndroid`-guarded, subscribes to the broadcast `moduleStateChannel.events` (no replay, built before any session), and is retained as an `App` field. The start→stop race is handled by the `_wantRunning` re-check after the await window. `App.dart` single-line initializers carry no trailing commas (style rule respected).

## Non-blocking observations (optional hardening)

1. **`start()` / `stop()` are fire-and-forget from `_onEvent`** (`KeepAliveCoordinator.dart:29,31,33`). `_onEvent` is synchronous and does not await the returned `Future`. If `Permission.activityRecognition.request()` or the plugin call ever rejects, it becomes an unhandled async error (zone-logged, non-fatal). Consider `.catchError`/`unawaited(...)` with logging to make intent explicit and avoid a noisy uncaught error. Low severity.

2. **In-flight concurrency window** (`ForegroundKeepAlive.dart:34-65`). `_running` is only set after `startService` completes. Two `ModuleSessionStarted` events arriving before the first `start()` finishes its awaits would both pass the `if (_running) return` gate and both call `startService`; the plugin's internal `isRunningService` guard makes the second return `ServiceRequestFailure(ServiceAlreadyStartedException)`, which is then logged as a spurious "start failed". Harmless but could log a misleading error. An in-flight boolean would close it. Low severity.

3. **Channel name not localized** (`channelName: 'Session'`, `ForegroundKeepAlive.dart:55`). The notification title/body are localized, but the channel name (visible in system notification settings) is hardcoded English. Cosmetic.

4. **Silent no-keep-alive on denied `ACTIVITY_RECOGNITION`** (`ForegroundKeepAlive.dart:39-42`). By design per the plan (the service cannot legally start without the qualifier), but the failure is log-only — a user who denies the prompt gets no background keep-alive with no surfaced indication. Acceptable for this milestone; worth a product note.

5. **`RECEIVE_BOOT_COMPLETED` now added transitively** via the plugin manifest. `autoRunOnBoot` defaults to `false`, so no service auto-starts on reboot — no behavioral surprise. Noted only for awareness of the added permission in the merged manifest.

None of the above require changes to ship correctly.

REVIEW_PASS
