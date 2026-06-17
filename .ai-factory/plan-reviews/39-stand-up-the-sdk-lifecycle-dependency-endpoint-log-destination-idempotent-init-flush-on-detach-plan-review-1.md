# Plan Review: Stand up the SDK lifecycle (observe init/flush)

**Plan:** `39-stand-up-the-sdk-lifecycle-...md`
**Files reviewed:** Environment.dart, Logger.dart, AppLifecycleService.dart, App.dart, main_dev.dart, main_prod.dart, ROADMAP.md, RULES.md, note 109 (spec)
**Risk Level:** 🟢 Low

## Verdict

The plan is accurate against the codebase and faithfully implements the authoritative spec
(`.ai-factory/notes/109-observe-sdk-lifecycle-init.md`). File paths, line references, and API
shapes all check out. It even **corrects a bug in the spec** (see below). The remaining items are
verification points and minor clarity nits, none blocking.

## Context Gates

- **Architecture (`ARCHITECTURE.md`)** — WARN (informational): The flush listeners
  (`appLifecycleService.onPause.listen(...)`) subscribe to a stream from *outside* the owning
  class in `App.initialize()`. The existing convention (e.g. `GrpcClient(... detachStream: appLifecycleService.onDetach ...)`, App.dart:151) injects the stream into a class that owns its
  subscription. Here the listener drives a bare top-level `flush()` function with no owning class,
  so external subscription is the pragmatic choice — wrapping it in a class would be
  over-engineering. Acceptable, but worth a conscious nod. The two subscriptions are never stored
  or cancelled; this is fine because `appLifecycleService` is a process-lifetime singleton (same as
  `connectionManager`), so there is no leak.
- **Rules (`RULES.md`)** — PASS. "Never add module-specific state to App.dart — infrastructure
  only." Logging/observability init is infrastructure, not a module concern, so it belongs in
  App.dart. No violation.
- **Roadmap (`ROADMAP.md`)** — PASS. Plan maps 1:1 to the milestone at ROADMAP line 115 under the
  observability epic (line 113). Linkage is explicit.

## Critical Issues

None.

## Findings (non-blocking)

1. **Spec bug correctly caught — keep it.** Note 109 and the task header both say add
   `final String? otlpEndpoint;`, but `overrideForLocal()` assigns `_instance.otlpEndpoint = ...`
   outside the constructor, which a `final` field forbids. Task 2's *Note* correctly resolves this
   to a non-final field, consistent with the existing non-final `grpcHost`/`apiBaseUrl`. ✅ The plan
   is right; the spec was wrong. **Recommendation:** state "non-final" in the task's first line to
   avoid an implementer adding `final` top-down before reaching the Note.

2. **Constructor param for `otlpEndpoint` is unnecessary (harmless).** A non-final
   `String? otlpEndpoint;` with no initializer already defaults to `null`; no `initDev()`/`initProd()`
   call site passes it. Adding it as an optional named constructor param (as Task 2 suggests) works
   but is dead surface. Either is fine — flagging only so the implementer isn't confused if they
   skip the param.

3. **`service.start` marker depends on `init()` auto-emitting it.** The Context promises "a
   `service.start` marker in Grafana/Loki" as the sole observable result, but no task emits it
   explicitly. This is *correct* per note 109 ("`init()` ... emits the `service.start` marker on
   success") — the SDK does it. Listed here only so verification expects the marker from `init()`,
   not from any app-side log line.

4. **OTLP endpoint path is unconfirmed (verify before relying on the marker).** Note 109's own
   Open Question flags `/otlp/v1/logs` as *assumed* from the SDK doc and says "confirm against the
   running backend before pinning the URL." The plan hardcodes
   `http://192.168.0.100:3100/otlp/v1/logs` without surfacing this. If the local Loki OTLP path
   differs, the marker silently won't appear (gated by `kDebugMode` onError → easy to miss).
   **Recommendation:** confirm the path against the running backend during Task 2 / verification.

5. **`init` placed before `WidgetsFlutterBinding.ensureInitialized()` — verify SDK needs no
   bindings.** The plan correctly relies on note 109's claim that `observe` is "pure Dart + `http`"
   so it is safe pre-binding. `http` and `debugPrint` do not require Flutter bindings, so this holds.
   No change needed; noted as the one assumption to confirm when the dep resolves (Task 1 already
   asks to verify exports).

6. **Generic unprefixed imports `init` / `flush`.** Importing `init`/`flush`/`shutdown` bare into
   App.dart reads slightly ambiguously next to `App.initialize()`. Not a defect (no collision with
   any existing symbol), but `import 'package:observe/observe.dart' as observe;` would improve
   readability. Optional.

## Positive Notes

- API shapes verified: `AppLifecycleListener` does expose an `onPause` callback, so Task 4's mirror
  of the `_onDetach` plumbing is valid.
- `kDebugMode` is genuinely `const` (`!kReleaseMode`), so the `String.fromEnvironment` const default
  ternary in Task 3 compiles. Claim is correct.
- Double-gating is sound: in release dev/prod, `kDebugMode` is false → `overrideForLocal()` is
  skipped → `otlpEndpoint` stays null, *and* `LOG_DESTINATION` defaults to `file` → `logToObserver`
  false. Either gate alone prevents `init` in cloud builds.
- The plan improves on the spec's `onError: kDebugMode ? debugPrint : null` (which would not
  typecheck — `debugPrint` takes `String?`) by wrapping it as `(e) => debugPrint('observe: $e')`.
- `unawaited` is already imported (`dart:async`, App.dart:5); commit messages follow the no-prefix
  sentence-case convention.

PLAN_REVIEW_PASS
