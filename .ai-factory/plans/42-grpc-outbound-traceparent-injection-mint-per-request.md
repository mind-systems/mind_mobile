# Plan: gRPC outbound `traceparent` injection (mint per request)

## Context
Inject a freshly-minted W3C `traceparent` into every outgoing gRPC call's metadata so mind_api stamps its own logs with the same `trace_id` (one-sided correlation floor). The work lives entirely inside the already-wired `GrpcLoggingInterceptor` — no call-site changes, no new log lines.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Context Notes
- Spec: `.ai-factory/notes/112-grpc-traceparent-inject-outbound.md`.
- Target file: `lib/Core/Grpc/GrpcLoggingInterceptor.dart`. It already implements `interceptUnary` / `interceptStreaming`, calls `invoker(...)`, and attaches an error-only `.then` handler. The interceptor is wired in `App.initialize` as `interceptors: [grpcAuthInterceptor, GrpcLoggingInterceptor()]`.
- `package:observe/observe.dart` (git dep `mind-systems/observe-dart` @ `v0.1.0`) exposes the needed API, confirmed against the resolved package:
  - `Span startSpan({String? name})` — with no active context returns a **root** span: fresh `traceId` (32 hex), fresh `spanId` (16 hex), `traceFlags = 1`. At the transport boundary there is no active context, so each call gets a fresh trace.
  - `Span` fields: `traceId`, `spanId`, `traceFlags` (int).
  - `TraceContext({required traceId, required spanId, required traceFlags})`.
  - `T runWithContext<T>(TraceContext ctx, T Function() body)` — runs `body` in a child zone carrying `ctx`; returns synchronously.
  - `void inject(Carrier carrier)` — reads the active context via the zone and writes lowercase key `traceparent` = `00-<traceId>-<spanId>-<2-hex flags>`. Writes nothing if no active context (hence the call must be inside `runWithContext`).
  - `MapCarrier(Map<String, String> map)` — `Carrier` backed by a plain map; writes directly into the map.
- Auth interceptor (`GrpcAuthInterceptor`) adds `authorization` via `CallOptions(providers: [...])`, not static metadata. `CallOptions.mergedWith` unions static `metadata` and concatenates `providers`, so a static `metadata: {'traceparent': ...}` here coexists with the auth provider — neither replaces the other.

## Tasks

### Phase 1: Inject traceparent into outgoing gRPC metadata

- [x] **Task 1: Add observe import and a per-call traceparent helper**
  Files: `lib/Core/Grpc/GrpcLoggingInterceptor.dart`
  Add `import 'package:observe/observe.dart';`. Add a private helper that takes the incoming `CallOptions` and returns options carrying a freshly-minted `traceparent`:
  ```dart
  CallOptions _withTraceparent(CallOptions options) {
    final span = startSpan();
    final carrier = <String, String>{};
    runWithContext(
      TraceContext(
        traceId: span.traceId,
        spanId: span.spanId,
        traceFlags: span.traceFlags,
      ),
      () => inject(MapCarrier(carrier)),
    );
    return options.mergedWith(CallOptions(metadata: carrier));
  }
  ```
  Notes: mint per call (root span → fresh trace each time, never reuse). The `runWithContext` zone exists only long enough to build the header — do not wrap the call lifecycle in it (that is note 113; when 113 lands this transient zone collapses into its single lifecycle zone). Carrier keys stay lowercase (the SDK writes lowercase `traceparent`). Do NOT add any log lines.

- [x] **Task 2: Wire the helper into both interceptors before `invoker`** (depends on Task 1)
  Files: `lib/Core/Grpc/GrpcLoggingInterceptor.dart`
  In `interceptUnary`, replace `invoker(method, request, options)` with `invoker(method, request, _withTraceparent(options))`. In `interceptStreaming`, replace `invoker(method, requests, options)` with `invoker(method, requests, _withTraceparent(options))`. Keep the existing error-only `.then` / `.trailers.then` handlers exactly as-is — outside the trace zone, unchanged. Confirm no new log lines were introduced and that `mergedWith` preserves the auth provider's `authorization` key (static `traceparent` metadata unions with the auth `providers`, does not replace them). HTTP/Dio is out of scope — no changes there.

## Verify
- Trigger any gRPC call with `LOG_DESTINATION=both`; via `observe-logs`, confirm mind_api's logs for that call carry a `trace_id` and that inbound metadata contained `traceparent`. Confirm auth still works (the `authorization` header is still attached), proving metadata union, not replacement.
