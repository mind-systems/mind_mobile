# Plan: Wrap gRPC call lifecycle in `runWithContext` for phone-side correlation

## Context
Move the gRPC invoke-and-attach lifecycle inside a single `runWithContext(ctx, …)` zone in `GrpcLoggingInterceptor` so the **existing** `[gRPC] … ERROR` error log inherits the minted `trace_id` through Dart's `Zone`, giving a failed request one shared `trace_id` across the phone error log and mind_api logs. No new logs are added — only correlation of the line that already exists.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Refactor interceptor to a single lifecycle zone

- [x] **Task 1: Wrap `interceptUnary` lifecycle in one `runWithContext` zone**
  Files: `lib/Core/Grpc/GrpcLoggingInterceptor.dart`
  Replace the current flow (`invoker(..., _withTraceparent(options))` followed by an out-of-zone `.then`) with a single `runWithContext(ctx, () { … })` body that:
  1. Mints the span with `startSpan()` and builds `ctx` as `TraceContext(traceId: span.traceId, spanId: span.spanId, traceFlags: span.traceFlags)`.
  2. Inside the zone body: builds the metadata carrier and calls `inject(MapCarrier(carrier))` (relying on the active zone context — no transient inner `runWithContext`), merges it into `CallOptions` via `options.mergedWith(CallOptions(metadata: carrier))`, invokes `invoker(method, request, traced)`, attaches the **existing** `unawaited(response.then<void>((_) {}, onError: (Object e) { logPrint('[gRPC] ${method.path} ERROR: $e'); }))` line verbatim, and returns `response`.
  3. Returns the result of `runWithContext` (a `ResponseFuture<R>`, since `runWithContext<T>` returns the body's value) from `interceptUnary`.
  The `.then`/`onError` MUST be registered **inside** the zone body so the `ResponseFuture` continuation inherits the zone and `logPrint` stamps `traceId`/`spanId`. Do NOT add any new log line.

- [x] **Task 2: Wrap `interceptStreaming` lifecycle in one `runWithContext` zone** (depends on Task 1)
  Files: `lib/Core/Grpc/GrpcLoggingInterceptor.dart`
  Apply the same single-zone refactor to `interceptStreaming`: mint span, build `ctx`, and inside `runWithContext(ctx, () { … })` build/inject the carrier, merge into `CallOptions`, call `invoker(method, requests, traced)`, attach the existing `unawaited(response.trailers.then<void>((_) {}, onError: …) { logPrint('[gRPC] ${method.path} ERROR: $e'); })` line verbatim inside the body, and return `response`. Return the `runWithContext` result (a `ResponseStream<R>`) from `interceptStreaming`. Keep the error line identical to the current one — zero new logs.

- [x] **Task 3: Remove the now-dead `_withTraceparent` helper and its transient zone** (depends on Tasks 1, 2)
  Files: `lib/Core/Grpc/GrpcLoggingInterceptor.dart`
  Delete the `_withTraceparent` method (note 112's transient `runWithContext` that existed only to build the header). After Tasks 1–2 both call sites build the carrier inline within the single lifecycle zone, so the end state is exactly **one** `runWithContext` per call. Keep the `package:observe/observe.dart` import (`startSpan`, `runWithContext`, `TraceContext`, `inject`, `MapCarrier`) and `dart:async` (`unawaited`). Confirm no leftover references to `_withTraceparent`.

### Phase 2: Live-failure verification gate

- [ ] **Task 4: Verify correlation on a real failing gRPC call** (depends on Task 3)
  Files: (no code changes — verification only)
  Build/run with `LOG_DESTINATION=both` and force a gRPC failure (e.g. point the client at an unreachable host). Capture the `trace_id` from the phone's `[gRPC] … ERROR` line and run `observe-logs trace <id>`; confirm the phone error line **and** the corresponding mind_api lines appear under one `trace_id`. This live failure is the only proof the `ResponseFuture`/`trailers` continuation inherited the zone — do not consider the milestone done on code review alone.
  **Fallback:** if the phone error line still carries no `trace_id` (continuation-inheritance proves unreliable), revert this milestone's changes and keep note 112 as the shipped floor. Never add new logging to force correlation.
