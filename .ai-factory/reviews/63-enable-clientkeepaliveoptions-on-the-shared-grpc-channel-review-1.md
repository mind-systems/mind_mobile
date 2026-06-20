# Code Review: Enable `ClientKeepAliveOptions` on the shared gRPC channel

**Branch:** dev
**Reviewed:** `lib/Core/Grpc/GrpcClient.dart`
**Date:** 2026-06-20

## Scope of changes

Single code change: the `GrpcClient` constructor initializer now builds its `ClientChannel` with `ChannelOptions.keepAlive` set to `ClientKeepAliveOptions(pingInterval: 30s, timeout: 20s, permitWithoutCalls: true)`. The `credentials:` branch is unchanged. No other source files touched.

## Verification performed

- **Diff is exactly the planned change.** Only `GrpcClient.dart:24-36` is modified; per-stream service clients, interceptor wiring, `shutdown()`, and the detach subscription are untouched — matching the plan's "do NOT touch the per-stream clients or reconnect manager" constraint.
- **API correctness against installed `grpc 5.1.0`:**
  - `ClientKeepAliveOptions` is publicly exported from `package:grpc/grpc.dart` (`lib/grpc.dart:24`), which is already imported — no new import required.
  - Constructor signature matches: `const ClientKeepAliveOptions({Duration? pingInterval, Duration timeout = 20s, bool permitWithoutCalls = false})`. All three named args supplied are valid; the constructor is `const`, so `const ClientKeepAliveOptions(...)` compiles.
  - `ChannelOptions` accepts `keepAlive` (`lib/src/client/options.dart:62,73`), defaulting to `const ClientKeepAliveOptions()`.
  - `shouldSendPings => pingInterval != null` confirms that setting `pingInterval: 30s` activates pinging (previously disabled).
- **Const usage is valid** — `Duration(...)` literals inside a `const` constructor are themselves const; no runtime allocation concern.
- **No type mismatches, no nullability issues, no migrations involved.** This is a pure client-channel configuration change with no proto/schema/server dependency.

## Correctness / runtime assessment

- No race conditions introduced — keepalive is internal to the channel's HTTP/2 transport and orthogonal to the existing `_detachSubscription` lifecycle.
- Reconnect behavior is preserved: a ping-timeout-triggered channel close surfaces to the stream clients via `onError`/`onDone` → `scheduleReconnect()`, exactly the existing path the plan relies on.
- `permitWithoutCalls: true` carries the documented (and plan-acknowledged) risk of server-side `GOAWAY`/`ENHANCE_YOUR_CALM` if the server's min-ping guard is stricter than 30s. The note's guard (drop to `false`) is the correct mitigation and is a behavioral/ops follow-up, not a code defect. With `pingInterval: 30s` >= the server's 25s min-interval guard, no pushback is expected.

## Findings

None. The change is minimal, API-correct for the pinned `grpc 5.1.0`, scoped exactly as planned, and introduces no compile-time or runtime risk.

REVIEW_PASS
