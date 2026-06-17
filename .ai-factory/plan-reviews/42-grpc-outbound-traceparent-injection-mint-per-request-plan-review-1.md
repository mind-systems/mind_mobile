# Plan Review: gRPC outbound `traceparent` injection (mint per request)

**Plan:** `.ai-factory/plans/42-grpc-outbound-traceparent-injection-mint-per-request.md`
**Risk Level:** 🟢 Low

## Summary

The plan is small, surgical, and **accurate**. Every API claim it makes was verified against
the resolved package source and the target file. The change lives entirely inside the
already-wired `GrpcLoggingInterceptor`, requires no call-site changes, no migrations, and no
new dependencies (`observe` is already a direct dependency and already imported by
`lib/Logger.dart`). I found no blocking issues.

## Verification performed

All claims in the plan were cross-checked against source, not memory:

- **`observe` package API** (`~/.pub-cache/git/observe-dart-69fd6cc...`, ref `v0.1.0`):
  - `startSpan({String? name})` — confirmed: with no active context returns a **root** span
    (`newTraceId()`, `newSpanId()`, `traceFlags: 1`). `lib/src/context/span.dart:66-81`.
  - `Span` exposes `traceId` / `spanId` / `traceFlags`. `lib/src/context/span.dart:14-50`.
  - `TraceContext({required traceId, required spanId, required traceFlags})`.
    `lib/src/context/trace_context.dart:22-27`.
  - `runWithContext<T>(TraceContext, T Function())` — wraps `runZoned` with a zone value;
    **runs `body` synchronously** and returns its value. `lib/src/context/trace_context.dart:88-89`.
  - `inject(Carrier)` — reads the active zone context, writes lowercase key `traceparent` =
    `00-<traceId>-<spanId>-<2-hex flags>`; writes nothing if no active context.
    `lib/src/context/propagation.dart:76-82`.
  - `MapCarrier(Map<String,String>)` — `Carrier` backed by the map, writes directly into it.
    `lib/src/context/propagation.dart:33-46`.
  - All five symbols are re-exported from the barrel `package:observe/observe.dart`. ✔
  - Package name is `observe`, so the import `package:observe/observe.dart` is correct. ✔

- **Target file** `lib/Core/Grpc/GrpcLoggingInterceptor.dart`: matches the plan's description —
  `interceptUnary` / `interceptStreaming` call `invoker(...)` and attach an error-only `.then` /
  `.trailers.then`. The two `invoker(...)` lines the plan edits exist verbatim (lines 14, 28). ✔

- **Wiring**: `App.dart:157` — `interceptors: [grpcAuthInterceptor, GrpcLoggingInterceptor()]`. ✔
  All 13 service clients in `GrpcClient.dart` share the same `_interceptors` list, and no other
  `ClientChannel` / `ServiceClient` is constructed with a different interceptor set anywhere in
  `lib/`. So injecting in this one interceptor covers **all** gRPC traffic — the plan's scope claim
  holds.

- **`CallOptions.mergedWith` semantics** (grpc 5.1.0, `lib/src/client/call.dart:87-105`):
  confirmed it **unions** `metadata` (`Map.of(metadata)..addAll(other.metadata)`) and
  **concatenates** `metadataProviders` (`List.of(...)..addAll(...)`). The auth interceptor adds
  `authorization` via a **provider** (`GrpcAuthInterceptor.dart:39,54`), and this plan adds a
  **static metadata** entry — different fields, so they coexist with zero collision regardless of
  interceptor order. The plan's "union, not replacement" claim is correct. ✔
  - Additional confirmation: `ClientCall.onConnectionReady` (`call.dart:264-281`) seeds the
    metadata map from `options.metadata` (carrying `traceparent`) and *then* runs providers over
    it, so the auth provider sees and preserves the traceparent key. ✔
  - `_sanitizeMetadata` (`call.dart:244-254`) lowercases/trims keys; `traceparent` is already
    lowercase and not in `_reservedHeaders`, so it survives untouched. ✔

## Context Gates

- **Architecture** (`.ai-factory/ARCHITECTURE.md`): WARN — none. The change respects the existing
  `lib/Core/Grpc/` infrastructure boundary; no domain/module layering is touched.
- **Rules** (`.ai-factory/RULES.md`): WARN — none. The only logged rule concerns stateless Module
  Services / derived streams, which is unrelated to this interceptor change.
- **Roadmap** (`.ai-factory/ROADMAP.md`): aligned. The plan maps 1:1 to Phase 36, milestone
  *"gRPC outbound `traceparent` injection (mint per request)"* (line 125), spec note 112. The
  follow-up note-113 deferral (lifecycle `runWithContext`) is correctly called out as out of scope
  and the plan even notes that this transient zone collapses into 113's lifecycle zone later. Good
  linkage.

## Critical Issues

None.

## Minor Observations (non-blocking)

1. **`skill-context/aif-review/SKILL.md` is absent** (the `skill-context/` dir is empty), so no
   project-specific review overrides apply. Noted for completeness, not a plan defect.

2. **Verify step depends on observe being initialized + reachable.** The plan's Verify relies on
   `observe-logs` showing mind_api's `trace_id`. That is purely a backend-side check and does not
   depend on the phone's `observe` SDK `init` (the gRPC metadata is sent regardless of whether
   `init` ran). This is fine — just flagging that the phone-side correlation (its own error log
   carrying the trace_id) is explicitly note 113, not this milestone, so don't expect the phone
   error log to show the trace yet. The plan already states this.

3. **`startSpan()` inheriting an ambient trace.** The helper assumes "no active context at the
   transport boundary → root span." That holds today (nothing in `lib/` establishes a
   `runWithContext` zone around gRPC calls). If a future change wraps calls in a context, the span
   would *inherit* the trace instead of minting a fresh one — which is actually the desired
   correlation behavior, so no defensive code is needed. Worth keeping in mind when note 113 lands
   (the plan/spec already flag avoiding double zone-wraps).

4. **Name-collision check passed.** `inject`, `startSpan`, `runWithContext`, `TraceContext`,
   `MapCarrier` do not collide with any symbol exported by `package:grpc/grpc.dart` or
   `package:mind/Logger.dart`, so the bare `import 'package:observe/observe.dart';` is safe.

## Positive Notes

- The helper is written against the real API (verified field-for-field), including the subtle
  requirement that `inject` only writes when called *inside* a `runWithContext` zone — the plan
  gets this exactly right by wrapping the `inject` call in `runWithContext`.
- Correct insistence on **zero new log lines** and **mint-per-call** (root span), matching the
  spec's guards.
- Scope discipline: HTTP/Dio correctly excluded (dead code), both unary and streaming paths
  covered, error handlers left untouched and outside the zone.

PLAN_REVIEW_PASS
