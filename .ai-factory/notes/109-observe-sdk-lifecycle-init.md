# observe SDK lifecycle — dependency, endpoint, LOG_DESTINATION, init, flush

**Date:** 2026-06-18
**Source:** conversation context

## Key Findings

- This is the foundation milestone of the observability integration: it stands up the `observe` SDK lifecycle without yet rewiring any log output. After it ships, the only observable change is that a `service.start` marker appears in Grafana/Loki after each app launch (the existing console logging is untouched).
- The SDK is `observe` v0.1.0 (pure Dart + `http`), added as a pinned `git:` dependency. `init(project:, service:, endpoint:)` is idempotent, never throws, validates the endpoint scheme, and emits the `service.start` marker on success.
- `endpoint` is a **full OTLP/HTTP URL** (`http://<dev-ip>:3100/otlp/v1/logs`), not a host. `localhost` is unreachable from a device/emulator, so the URL must be the developer-machine LAN IP already used by `Environment.overrideForLocal()`.
- `LOG_DESTINATION` (`file` | `grafana` | `both`) is a compile-time `String.fromEnvironment` value gating *whether* the observer sink is wired. `init()` is called only when the destination includes `grafana`.
- Do **not** wrap `runApp` in a global `runWithContext` — that would give every log of the whole session one static `trace_id`. Trace context is per-request only (Phase 36).

## Details

### Current state
- No `observe` dependency.
- `lib/Core/Environment.dart` holds `apiBaseUrl`, `grpcHost/Port/Secure`. `overrideForLocal()` (called under `kDebugMode`) points the app at the dev machine on `192.168.0.100`. There is no OTLP endpoint field.
- `lib/Core/App.dart` `initialize()` begins with `WidgetsFlutterBinding.ensureInitialized()`. `main_dev.dart` / `main_prod.dart` call `Environment.initDev/initProd()` then `App.initialize()`.
- `lib/Core/AppLifecycleService.dart` exposes `onDetach` / `onResume` streams (`GrpcClient` already listens to `onDetach`).

### The change
1. Add the dependency: `flutter pub add observe --git-url=https://github.com/mind-systems/observe-dart.git --git-ref=v0.1.0` (never hand-edit `pubspec.yaml`).
2. `Environment`: add `final String? otlpEndpoint;`. Set it in `overrideForLocal()` to `http://192.168.0.100:3100/otlp/v1/logs`. Leave `null` for cloud dev/prod builds (those default to `file`, so `init` is not called).
3. Add a single source of truth for the destination switch (in `lib/Logger.dart`, consumed by both this milestone and note 110):
   `const _logDestination = String.fromEnvironment('LOG_DESTINATION', defaultValue: kDebugMode ? 'both' : 'file');`
   plus `bool get logToConsole => _logDestination != 'grafana';` and `bool get logToObserver => _logDestination != 'file';`. `kDebugMode` is `const`, so the ternary default is a valid const expression.
4. In `App.initialize()`, as the **first statement** (before any `logPrint`), gate on `logToObserver` and a non-null endpoint:
   `if (logToObserver && Environment.instance.otlpEndpoint != null) { init(project: 'mind', service: 'mind_mobile', endpoint: Environment.instance.otlpEndpoint!, onError: kDebugMode ? (e) => debugPrint('observe: $e') : null); }`
   `init` is idempotent — a second call no-ops.
5. Drain on background **and** on detach. `detached` is delivered unreliably on mobile — iOS in particular often kills the app without it — so flushing when the app merely backgrounds (`paused`) is the real insurance against losing the buffer tail (there is no file sink to fall back on). `AppLifecycleService` currently exposes only `onResume`/`onDetach`; add an `onPause` stream backed by `AppLifecycleListener(onPause: …)` (mirror the existing `_onDetach` controller). Then `flush()` on **both** `appLifecycleService.onPause` and `onDetach`:
   `appLifecycleService.onPause.listen((_) => unawaited(flush()));`
   `appLifecycleService.onDetach.listen((_) => unawaited(flush()));`
   `flush()` keeps the SDK alive (no re-init needed on resume); reserve `shutdown()` for true teardown only. (`AppLifecycleService.dart` is also normalized in note 111 — keep the new `_onPause`'s own log line consistent with its siblings so that pass picks it up.)

### Guards
- `init` only when `LOG_DESTINATION` includes `grafana` **and** `otlpEndpoint != null`.
- `onError` routes diagnostics to `debugPrint` **only in `kDebugMode`** — silent in release.
- Do not wrap `runApp`/the app in a global zone.
- Endpoint is the full URL including `/otlp/v1/logs`, not a bare host.

### Verify
- Launch the dev flavor with `--dart-define=LOG_DESTINATION=both` (or `grafana`).
- `observe-logs since-restart mind_mobile --project mind` shows a fresh `service.start` after each launch.

## Open Questions

- Exact OTLP logs path on the local Loki backend (`/otlp/v1/logs` assumed from the SDK doc example) — confirm against the running backend before pinning the URL.
