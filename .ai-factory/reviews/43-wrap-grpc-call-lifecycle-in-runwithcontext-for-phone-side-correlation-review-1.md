# Code Review: Wrap gRPC call lifecycle in `runWithContext` for phone-side correlation

**Scope reviewed:** `lib/Core/Grpc/GrpcLoggingInterceptor.dart` (only code change in the diff; the other staged files are plan/plan-review artifacts).

## Summary

The change is faithful to the plan and to note 113. Both `interceptUnary` and `interceptStreaming` now mint a root span outside the zone, then run carrier-build + inject + invoke + error-`.then` attach inside a single `runWithContext(ctx, …)`. The transient `_withTraceparent` helper (note 112's second zone) is deleted, leaving exactly **one** zone per call. No new log line was added — the existing `[gRPC] … ERROR` line is reused verbatim. Imports (`dart:async` for `unawaited`, `package:observe/observe.dart` for `startSpan`/`runWithContext`/`TraceContext`/`inject`/`MapCarrier`) are all still in use.

## Correctness verification (traced through the `observe` package)

I verified the full stamping chain against the resolved `observe-dart` source:

1. **`inject` reads the active zone context.** `propagation.dart` → `inject()` calls `getActiveContext()` and writes `00-<traceId>-<spanId>-<flags>`. Called inside `runWithContext(ctx, …)`, the active context is `ctx`, so the carrier always receives the correct `traceparent`. The previous transient inner zone is no longer needed — relocation is sound.
2. **`startSpan()` outside the zone mints a root span.** `span.dart` → with no active context it returns a fresh `traceId`/`spanId`, `traceFlags = 1`. Calling it *before* entering the zone is correct (and necessary — the zone is built from the span). Per-request root minting matches note 112's intent. No reuse across requests.
3. **`logPrint` stamps at emit time.** `Logger.dart` → `observeSink` → `api.dart log()` calls `getActiveContext()` at line 199 and stamps `traceId`/`spanId` onto the `LogRecord`. So if the `onError` continuation runs in the trace zone, the error record carries the trace id.
4. **Continuation zone inheritance.** `runWithContext` is `runZoned(body, zoneValues: {…})`. `response.then(…, onError:)` is registered synchronously inside the body, so `Zone.current` at registration is the child trace zone; standard Dart `Future` semantics run the callback in that zone regardless of which zone completes the future. grpc-dart's `ResponseFuture` / `trailers` future delegate `then` to a plain inner `Future`, preserving `Zone.current` — so inheritance is expected to hold. This is precisely the behavior the plan's Task 4 gates on a live failing call; correctly flagged as a runtime-verify item rather than assumed.

## Other checks

- **Return typing:** `runWithContext<ResponseFuture<R>>` / `<ResponseStream<R>>` are explicit and match the body's returned `response`, which is returned out to the caller. Returning the future across the zone boundary is fine — only the internal `onError` logging needs the zone; downstream awaiters are unaffected.
- **Metadata merge:** `options.mergedWith(CallOptions(metadata: carrier))` is unchanged from note 112; auth-interceptor metadata union semantics are not altered by this diff.
- **No behavioral regression:** the error handler is the same passive `unawaited(.then((_) {}, onError:))` as before — it adds a second listener on a multi-listener `Future`, identical to prior behavior. No double-logging, no new lines.
- **No error-swallowing zone:** `runWithContext` uses `runZoned` with no `onError`/`handleUncaughtError`, so async errors propagate normally; only the explicit `onError` branch handles them.

## Findings

No correctness, security, or runtime-breakage findings. The one residual risk (whether `ResponseFuture`/`trailers` continuations inherit the registration zone in practice) is inherent to the milestone, is reliable under standard Dart `Future` semantics, and is explicitly gated by the Task 4 live-failure verification with a documented fallback (revert to note 112). That gate must still be executed before marking DoD #3 done — but it is a verification step, not a code defect.

REVIEW_PASS
