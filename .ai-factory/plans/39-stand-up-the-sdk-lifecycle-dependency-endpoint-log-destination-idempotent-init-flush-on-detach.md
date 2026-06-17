# Plan: Stand up the SDK lifecycle — dependency, endpoint, LOG_DESTINATION, idempotent init, flush on detach

## Context
Foundation milestone of the observability integration: stand up the `observe` SDK lifecycle (dependency, endpoint, destination switch, idempotent `init`, lifecycle `flush`) without rewiring any existing log output. The only observable result is a `service.start` marker in Grafana/Loki after each dev launch; console logging stays untouched.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Dependency & configuration

- [x] **Task 1: Add the `observe` SDK as a pinned git dependency**
  Files: `pubspec.yaml` (via tool), `pubspec.lock`
  Run `flutter pub add observe --git-url=https://github.com/mind-systems/observe-dart.git --git-ref=v0.1.0` (use `/usr/local/bin/flutter`). Do NOT hand-edit `pubspec.yaml` — the CLI must write the `git:` ref pinned to `v0.1.0`. Verify the package resolves and that `init`/`flush`/`shutdown` are exported from `package:observe/observe.dart`.

- [x] **Task 2: Add nullable `otlpEndpoint` to `Environment`** (depends on Task 1)
  Files: `lib/Core/Environment.dart`
  Add `final String? otlpEndpoint;` field. Add it as an optional named parameter to the private `Environment._({...})` constructor (default/omit so cloud `initDev()`/`initProd()` leave it `null`). In `overrideForLocal()`, set `_instance.otlpEndpoint = 'http://192.168.0.100:3100/otlp/v1/logs';` — the full OTLP/HTTP logs URL on the dev-machine LAN IP (devices/emulators cannot reach `localhost`). Leave `otlpEndpoint` null for the cloud dev and prod paths so `init` is never called there.
  Note: `otlpEndpoint` is final but assigned in `overrideForLocal()` like the other overridden fields — keep it mutable consistent with `grpcHost`/`apiBaseUrl` (make it `String? otlpEndpoint;` non-final to match the existing override pattern, since those fields are non-final for the same reason).

- [x] **Task 3: Add the `LOG_DESTINATION` resolver to `Logger.dart`** (depends on Task 1)
  Files: `lib/Logger.dart`
  Add a single source of truth for the destination switch (consumed by this milestone and future log-sink wiring):
  `const _logDestination = String.fromEnvironment('LOG_DESTINATION', defaultValue: kDebugMode ? 'both' : 'file');`
  (`kDebugMode` is `const`, so the ternary default is a valid const expression.)
  Expose `bool get logToConsole => _logDestination != 'grafana';` and `bool get logToObserver => _logDestination != 'file';`. Do not change `logPrint` behavior in this milestone.

### Phase 2: Lifecycle wiring

- [x] **Task 4: Add an `onPause` stream to `AppLifecycleService`**
  Files: `lib/Core/AppLifecycleService.dart`
  Mirror the existing `_onDetach` plumbing: add `_pauseController` (broadcast `StreamController<void>`), expose `Stream<void> get onPause => _pauseController.stream;`, add `_onPause()` that logs `'[AppLifecycleService] app paused'` via the same `log(..., name: 'AppLifecycleService')` pattern as its siblings, and wire `onPause: _onPause` into the `AppLifecycleListener` constructor call. Close `_pauseController` in `dispose()`. Keep the new log line stylistically consistent with `_onResume`/`_onDetach`.

- [x] **Task 5: Initialize `observe` and flush on pause + detach in `App.initialize()`** (depends on Tasks 2, 3, 4)
  Files: `lib/Core/App.dart`
  Add `import 'package:observe/observe.dart';` and `import 'package:mind/Logger.dart';`.
  As the **very first statement** of `App.initialize()` — before `WidgetsFlutterBinding.ensureInitialized()` and before any `logPrint` — gate and init:
  `if (logToObserver && Environment.instance.otlpEndpoint != null) { init(project: 'mind', service: 'mind_mobile', endpoint: Environment.instance.otlpEndpoint!, onError: kDebugMode ? (e) => debugPrint('observe: $e') : null); }`
  `init` is idempotent (a second call no-ops) and never throws. Do NOT wrap `runApp` (or any part of the app) in a global zone / `runWithContext` — trace context is per-request only.
  After `appLifecycleService` is constructed (around line 149), drain the buffer on **both** background and detach:
  `appLifecycleService.onPause.listen((_) => unawaited(flush()));`
  `appLifecycleService.onDetach.listen((_) => unawaited(flush()));`
  `flush()` keeps the SDK alive (no re-init on resume); do not call `shutdown()`. `detached` is unreliable on mobile (iOS often kills without it), so the `onPause` flush is the real insurance against losing the buffer tail. Respect the App.dart style rule: single-line initializer statements, no trailing commas on initializer lines.

## Commit Plan
- **Commit 1** (after tasks 1-3): "Add observe dependency, OTLP endpoint config and LOG_DESTINATION resolver"
- **Commit 2** (after tasks 4-5): "Init observe SDK and flush logs on app pause and detach"
