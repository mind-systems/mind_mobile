# Wrap gRPC call lifecycle in runWithContext for phone-side correlation

**Date:** 2026-06-18
**Source:** conversation context

## Key Findings

- This is the **goal** of cross-service correlation (DoD #3): run the gRPC call's lifecycle inside `runWithContext(ctx, …)` so the **existing** error `logPrint` inherits the minted `trace_id` through Dart's `Zone`. The anchor is the error that already gets logged on failure — **no new log line is added**.
- Result: when a gRPC request fails, the phone's existing error log and mind_api's logs land on one `trace_id` (`observe-logs trace <id>` shows both sides). Successful requests still log nothing on the phone (unchanged) — the trace simply lives on the api side.
- Builds directly on note 112 (same file, same minted span). The honest fallback if zone-propagation through the response continuation proves unworkable: **drop this milestone and keep note 112** (inject-only, api-side correlation). Note 112 stands alone as the floor.

## Details

### Current state (after note 112)
`GrpcLoggingInterceptor` mints a span, injects `traceparent` into outgoing metadata, then invokes the call and attaches an error-only `.then` **outside** any trace context — so the phone's error log carries no `trace_id`.

### The change
- Move the minted span's context to cover the **whole** call lifecycle, including the `.then`/error handler, by running the invoke-and-attach body inside `runWithContext`:
  ```dart
  return runWithContext(ctx, () {
    final response = invoker(method, request, traced);
    unawaited(response.then<void>((_) {}, onError: (Object e) {
      logPrint('[gRPC] ${method.path} ERROR: $e');   // existing line — now inside ctx
    }));
    return response;
  });
  ```
  Because `runWithContext` propagates to async continuations scheduled **within** its body, the `onError` callback executes inside the zone and `log` (via `logPrint` → `observeSink`) stamps `traceId`/`spanId` automatically.
- Applies to both `interceptUnary` (`response.then`) and `interceptStreaming` (`response.trailers.then`).
- The error `logPrint` line is the one normalized in note 111 — it is reused verbatim, not added.
- **Collapse note 112's transient zone.** Note 112 wrapped `inject` in its *own* short-lived `runWithContext` purely to build the `traceparent` header. Once this lifecycle `runWithContext(ctx, …)` exists, `inject` reads the active context itself — so move the `inject(MapCarrier(map))` call **inside** this single zone and delete the transient wrap. The end state is exactly **one** `runWithContext` per call, not two. Build the metadata, merge into `CallOptions`, invoke, and attach `.then` all within that one body.

### Guards
- **Zero new logs.** Only the pre-existing error log is the anchor.
- The `.then`/`onError` must be attached **inside** the `runWithContext` body, or the continuation won't inherit the zone.
- If continuation-inheritance through `ResponseFuture` proves unreliable, this milestone is dropped and note 112 remains the shipped floor — do not invent new logging to force correlation.
- Skip HTTP/Dio (dead code).

### Verify
- With `LOG_DESTINATION=both`, force a gRPC error (e.g. point at an unreachable host); `observe-logs trace <id>` returns the phone's `[gRPC] … ERROR` line **and** the corresponding mind_api lines under one `trace_id`.
- **Gate on a live failure:** do not mark DoD #3 done on code-review alone. Run a real failing gRPC call and confirm the phone error line actually carries the `trace_id` — this is the only proof the `ResponseFuture` continuation inherited the zone.

## Open Questions

- Whether grpc-dart's `ResponseFuture` continuations reliably run in the zone active when `.then` is registered (expected yes for `runZoned`-bound continuations, but **must** verify on a real failing call before declaring DoD #3 met — see Verify). If they don't, M5 is dropped and note 112 stands as the floor.
