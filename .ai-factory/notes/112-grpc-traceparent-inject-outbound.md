# gRPC outbound traceparent injection (mint per request)

**Date:** 2026-06-18
**Source:** conversation context

## Key Findings

- This is the **floor** of cross-service correlation and the user's stated honest fallback: mint a fresh trace per outgoing gRPC call and inject `traceparent` into the call metadata, so mind_api stamps its own logs with the same `trace_id`. **No new log lines, no call-site changes** — the work lives entirely inside the already-wired `GrpcLoggingInterceptor` (infrastructure, configured once in `App.initialize`).
- After this milestone, correlation is one-sided: mind_api logs carry the request's `trace_id`, but the phone's existing error log does not yet (that is note 113, the runWithContext upgrade).
- HTTP/Dio is **out of scope** — `HttpClient` is dead code (never instantiated). Only gRPC carries real traffic.

## Details

### Current state
`lib/Core/Grpc/GrpcLoggingInterceptor.dart` implements `interceptUnary` / `interceptStreaming`, calls `invoker(method, request, options)`, and attaches an error-only `.then` handler. Outgoing calls carry no trace context. The interceptor is wired in `App.initialize`:
`interceptors: [grpcAuthInterceptor, GrpcLoggingInterceptor()]`.

### The change
- Per intercepted call, mint a root span via `startSpan()` (no active context at the transport boundary → fresh `traceId`/`spanId`, `traceFlags = 1`).
- Produce the `traceparent` value by running `inject` against a `MapCarrier` inside a transient `runWithContext` for that span:
  ```dart
  final span = startSpan();
  final carrier = <String, String>{};
  runWithContext(
    TraceContext(traceId: span.traceId, spanId: span.spanId, traceFlags: span.traceFlags),
    () => inject(MapCarrier(carrier)),
  );
  final traced = options.mergedWith(CallOptions(metadata: carrier)); // {'traceparent': '00-...'}
  final response = invoker(method, request, traced);
  ```
- Keep the existing error `.then` handler exactly as-is (it will be brought into the trace zone in note 113; here it stays outside).
- Imports: `package:observe/observe.dart` (`startSpan`, `runWithContext`, `TraceContext`, `inject`, `MapCarrier`).

### Guards
- **Zero new log lines.** The interceptor's only log is the pre-existing error log; do not add a "request started/finished" line.
- Mint per call (`startSpan` with no active context → root). Do not reuse one trace across requests.
- gRPC metadata keys must be lowercase; the SDK already writes lowercase `traceparent`.
- Do not wrap the call lifecycle in the context yet (that is note 113) — here the context exists only long enough to build the header. **Note:** when note 113 lands, this transient `runWithContext` collapses into 113's single lifecycle zone (`inject` will read the active context there) — do not leave two zone wraps.
- Skip HTTP/Dio (dead code).

### Verify
- Trigger any gRPC call with `LOG_DESTINATION=both`; confirm via `observe-logs` that mind_api's logs for that call carry a `trace_id`, and that the inbound metadata contained `traceparent`.

## Open Questions

- Confirm the grpc-dart `CallOptions.mergedWith(CallOptions(metadata: …))` merge semantics preserve the auth interceptor's metadata (order of interceptors: auth runs alongside; metadata should union, not replace).
