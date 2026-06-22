# Android foreground service keep-alive (mechanism + wire to module-session lifecycle)

**Date:** 2026-06-22
**Source:** conversation context

## Key Findings

- The app has **no Android background-execution capability**: `android/app/src/main/AndroidManifest.xml` has no `FOREGROUND_SERVICE`/`WAKE_LOCK` permissions and no `<service>` declaration; no foreground-service package is in `pubspec.yaml`. After `app paused` the OS suspends the isolate ~1 min in (confirmed by logs: 28-min gap during an active session).
- The fix is a **foreground service held for the duration of any active activity** (breath OR meditation). It is started on `ModuleSessionStarted` and stopped on `ModuleSessionEnded`/`ModuleSessionAbandoned` via the same app-wide `ModuleStateEvent` stream that `BiometricStreamClient` already consumes — so one wiring covers both modules.

## Details

### Current state
- `android/app/src/main/AndroidManifest.xml` — only `BLUETOOTH_SCAN`/`BLUETOOTH_CONNECT`/`ACCESS_FINE_LOCATION`; no services.
- `lib/Biometrics/BiometricStreamClient.dart:55,58` — subscribes to a `Stream<ModuleStateEvent> moduleStateEvents` and switches on `ModuleSessionStarted` / `ModuleSessionEnded` / `ModuleSessionAbandoned` (`lib/Core/Grpc/ModuleStateEvent.dart`). This is the cross-module session-lifecycle stream to reuse.
- Module start/end emit points: `lib/MeditationModule/Core/MeditationModuleStateChannel.dart:38-46` and `lib/BreathModule/Core/BreathModuleStateChannel.dart:78-102` → both flow through `ModuleStateChannel._processProtoEvent` (`lib/Core/Grpc/ModuleStateChannel.dart:116-145`) which emits `ModuleSessionStarted`/`Ended`/`Abandoned`.

### Change
1. Add `flutter_foreground_task` — `flutter pub add flutter_foreground_task`.
2. `AndroidManifest.xml`: add `WAKE_LOCK`, `FOREGROUND_SERVICE`, the Android-14 typed permission **`FOREGROUND_SERVICE_HEALTH`** (decided — a breath/meditation + pulse session is squarely a health/wellness use; the type is semantically accurate and the Play review is more predictable than a free-text `specialUse` justification) and `POST_NOTIFICATIONS` (Android 13+). Declare the `flutter_foreground_task` service with `android:foregroundServiceType="health"`, plus its receiver. Play Console release step: complete the health-app declaration in the listing (one-time, no code).
3. Create `lib/Core/Background/ForegroundKeepAlive.dart` wrapping `flutter_foreground_task`: `start()` (init options + `startService` with a localized "Session in progress" notification) and `stop()` (`stopService`). Add the notification title/body ARB keys to `mind_l10n`.
4. Create `lib/Core/Background/KeepAliveCoordinator.dart` subscribing to the app-wide `ModuleStateEvent` stream (the one feeding `BiometricStreamClient`, exposed via `App.shared`): on `ModuleSessionStarted` → `ForegroundKeepAlive.start()`; on `ModuleSessionEnded` || `ModuleSessionAbandoned` → `stop()`. Guard the whole thing with `Platform.isAndroid` (iOS uses background audio — notes 138/140/142). Wire it up in `App.initialize()`.
5. Request `POST_NOTIFICATIONS` at first session start if not granted (reuse `permission_handler`).

### Guards
- iOS path is a no-op (`Platform.isAndroid`).
- Stop the service on **abandon** too, not just clean end, so a reaped session releases the wakelock.
- `foregroundServiceType="health"` must match the granted `FOREGROUND_SERVICE_HEALTH` permission or Android 14+ throws at `startForeground`.
- Don't hold the wakelock beyond session end; idempotent start/stop.
- Per `App.dart` style: no trailing commas on single-line initializer calls inside `initialize()`.

### Verify
- Start a session, lock the device; `adb shell dumpsys activity services | grep mind` shows the running FGS; logs continue past 1 minute (today they stop).

## Open Questions
- None — FGS type decided (`health`). The only release-time action is the Play Console health-app declaration.
