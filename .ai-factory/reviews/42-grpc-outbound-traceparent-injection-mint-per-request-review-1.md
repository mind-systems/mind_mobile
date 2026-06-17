# Code Review: gRPC outbound `traceparent` injection (mint per request)

**Plan:** `.ai-factory/plans/42-grpc-outbound-traceparent-injection-mint-per-request.md`
**Reviewed change:** `lib/Core/Grpc/GrpcLoggingInterceptor.dart` (the only code file in the diff)

## Scope of the diff
- `lib/Core/Grpc/GrpcLoggingInterceptor.dart` — adds `import 'package:observe/observe.dart';`, a `_withTraceparent(CallOptions)` helper, and routes both `interceptUnary` / `interceptStreaming` `invoker` calls through it.
- Remaining staged files are planning artifacts (`.json`, plan `.md`, plan-review `.md`) — no executable code.

## Verification performed (source, not memory)

- **Analyzer:** `flutter analyze lib/Core/Grpc/GrpcLoggingInterceptor.dart` → *No issues found*. Confirms no symbol collision between `package:observe/observe.dart` (`startSpan`, `runWithContext`, `TraceContext`, `inject`, `MapCarrier`) and `package:grpc/grpc.dart` / `package:mind/Logger.dart` under the bare imports.

- **observe API matches usage** (`~/.pub-cache/git/observe-dart-69fd6cc.../lib/src/...`, ref `v0.1.0`):
  - `startSpan()` with no active zone context returns a root span (`newTraceId`, `newSpanId`, `traceFlags: 1`) — pure id minting, **does not require `init()`** to have run. The interceptor therefore mints correctly regardless of observe SDK init state.
  - `inject(Carrier)` only writes when an active context exists; the code correctly wraps `inject` inside `runWithContext`, so the carrier is always populated.
  - `runWithContext` runs its body **synchronously** (`runZoned`), so `carrier` is fully populated before line 19 reads it — no async race between injection and `mergedWith`.

- **Metadata union is correct** (`grpc-5.1.0/lib/src/client/call.dart`):
  - `CallOptions.mergedWith` does `Map.of(metadata)..addAll(other.metadata)` and `List.of(metadataProviders)..addAll(...)` — static metadata and providers both survive.
  - This interceptor contributes **static metadata** (`traceparent`); `GrpcAuthInterceptor` contributes a **provider** (`authorization`). Different fields → no collision, order-independent.
  - At send time (`call.dart:267-272`) the metadata map is seeded from `options.metadata` (carrying `traceparent`) **then** providers run over it — the auth provider preserves the traceparent key.
  - `_sanitizeMetadata` lowercases/trims keys and rejects reserved headers; `traceparent` is already lowercase and not reserved, so it passes through untouched.
  - `CallOptions(metadata: carrier)` wraps the map in `Map.unmodifiable` (a copy) — later mutation of `carrier` is impossible anyway since it is fully built synchronously beforehand. No aliasing hazard.

## Correctness / runtime considerations checked
- **Mint-per-call:** a fresh root span per `intercept*` invocation → fresh `trace_id` per call, never reused. ✔
- **Streaming:** one `traceparent` per stream lifetime (interceptor runs once per call, not per message) — correct and expected. ✔
- **Zero new log lines:** the only `logPrint` calls are the pre-existing error handlers, left verbatim and outside the trace zone. ✔
- **WebCallOptions path:** if `options` is a `WebCallOptions` (grpc-web), `options.mergedWith(plainCallOptions)` dispatches to `WebCallOptions.mergedWith`, which unions metadata the same way — no breakage. ✔
- **Hot path cost:** per-call `runZoned` + id minting is negligible; streaming pays it once per stream, not per emission. Not a concern. ✔

## Findings
None. The change is surgical, compiles clean, matches the plan task-for-task, and the metadata-union / auth-preservation reasoning holds against the actual grpc and observe sources.

REVIEW_PASS
