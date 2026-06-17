# Plan Review: Wrap gRPC call lifecycle in `runWithContext` for phone-side correlation

**Plan:** `43-wrap-grpc-call-lifecycle-in-runwithcontext-for-phone-side-correlation.md`
**Files Reviewed:** plan + `lib/Core/Grpc/GrpcLoggingInterceptor.dart`, `lib/Logger.dart`, observe package (`api.dart`, `propagation.dart`, `span.dart`, `trace_context.dart`), `lib/Core/App.dart`, note 112
**Risk Level:** 🟢 Low

## Verdict

The plan is technically correct and well-grounded in the actual codebase and the `observe` API. The core mechanism it relies on is valid, the file paths and API usage are accurate, and the verification gate (Task 4) shows the right scientific caution. No blocking issues found.

## Context Gates

- **Architecture (`ARCHITECTURE.md`):** No conflict. The interceptor is pure infrastructure wired once in `App.initialize` (`lib/Core/App.dart:157`); the change does not cross the domain/module/DTO boundaries the architecture governs. — OK
- **Rules (`RULES.md`):** No `zone`/`logPrint`/`trace`/`grpc`-specific rules present. — OK
- **Roadmap (`ROADMAP.md`):** This is the "note 113" upgrade explicitly forecast by note 112 (one-sided → two-sided correlation). Linkage is clear. — OK
- **skill-context (`aif-review/SKILL.md`):** Empty/absent — no project overrides to apply. — OK

## Correctness Analysis (the load-bearing assumption)

The plan's central bet is: *if `response.then(onError: …)` is registered inside the `runWithContext` body, the error continuation inherits the zone, so `logPrint` stamps `traceId`.* This holds:

- `runWithContext` → `runZoned(body, zoneValues: {_contextKey: ctx})` (`trace_context.dart:88`). The forked zone Z is active for the synchronous body execution.
- `unawaited(response.then(…))` runs as a statement *inside* the body, so `.then` captures `Zone.current == Z` at registration time. Dart invokes the registered `onError` callback in Z, so `getActiveContext()` returns `ctx` → `logPrint` → `observeSink` → `log()` (`api.dart:199`) stamps `traceId`/`spanId`. ✔
- Return-type flow: `runWithContext<T>` returns the body's value; body returns `ResponseFuture<R>` (unary) / `ResponseStream<R>` (streaming), matching each method's declared return type. ✔
- `inject(MapCarrier(carrier))` reads the active context (`propagation.dart:76`), so calling it inside the single lifecycle zone (instead of note 112's transient inner `runWithContext`) is correct — no nested zone needed. ✔
- No context leakage into app code: the app awaits the returned future from *its own* zone (outside Z), so `getActiveContext()` in app code is unaffected. ✔
- `runZoned` is called with only `zoneValues` (no `onError`/`zoneSpecification`), so it does not install an error-handling zone — uncaught async errors propagate normally, preserving existing behavior. ✔ (The plan correctly does not add an `onError` to the zone.)

## Other checks

- **Auth-metadata regression risk** (note 112 open question): unchanged. The merge stays `options.mergedWith(CallOptions(metadata: carrier))`, identical to today, and the auth interceptor is outermost (`interceptors: [grpcAuthInterceptor, GrpcLoggingInterceptor()]`, `App.dart:157`) so it runs outside the logging zone. No metadata replacement. ✔
- **Imports:** `package:observe/observe.dart` and `dart:async` (`unawaited`) both already present and still needed after Task 3. ✔
- **Dead-helper removal (Task 3):** `_withTraceparent` has exactly two call sites (the two intercept methods); both are rewritten in Tasks 1–2, so removal leaves no dangling references. ✔
- **observe `init`:** Called in `App.initialize` (`App.dart:138`) gated on `logToObserver` + `otlpEndpoint`. The verification gate depends on this being live — already satisfied. ✔
- **Task 4 `LOG_DESTINATION=both`:** This is a compile-time `String.fromEnvironment` (`Logger.dart:4`), set via `--dart-define`, not a runtime env var. In debug builds the default is already `both`. Minor wording nuance only — not a defect.

## Optional / Non-blocking suggestions

1. **Consider reusing the `withSpan` helper.** The observe package already exposes `withSpan(body, {span})` (`span.dart:101`) which does exactly "mint span + `runWithContext(TraceContext(...), body)`". Tasks 1–2 manually inline `startSpan()` + `TraceContext` + `runWithContext`. Since `inject` reads the active context (no need to reference `span` fields outside the body), the body could simply be wrapped in `withSpan(() { …build carrier, inject, invoke, attach, return response; })`. This removes the hand-rolled `TraceContext` construction and keeps the "one zone per call" goal. Equivalent behavior either way — purely a readability call.
2. **Optional explicit type arg** on `runWithContext<ResponseFuture<R>>(…)` / `<ResponseStream<R>>(…)` if inference on the multi-statement closure ever looks ambiguous to a reader. Not required — inference is correct as-is.

## Positive Notes

- Task 4's explicit fallback (revert to note 112 if continuation-inheritance proves unreliable, never add new logging to force correlation) is exactly right — it treats the zone-inheritance assumption as a hypothesis to be proven by a live failure, not by code review.
- The "zero new log lines" guard is preserved verbatim and reiterated per task, consistent with note 112's contract.
- Scope is correctly limited to gRPC (HTTP/Dio is dead code, per note 112) and the change stays entirely within already-wired infrastructure.

PLAN_REVIEW_PASS
