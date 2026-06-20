# Plan: Enable `ClientKeepAliveOptions` on the shared gRPC channel

## Context
Enable client-side HTTP/2 keepalive pings on the shared `ClientChannel` so the app reaps a silently-dead server in ~50s (instead of hanging until the next write) and keeps the prod LB/NAT mapping warm between sessions.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Channel keepalive

- [x] **Task 1: Add `keepAlive` to the shared `ChannelOptions`**
  Files: `lib/Core/Grpc/GrpcClient.dart`
  In the `GrpcClient` constructor initializer (`lib/Core/Grpc/GrpcClient.dart:24-25`), extend the existing `ChannelOptions` with a `keepAlive` argument while keeping the current `credentials:` branch unchanged. Set:
  ```dart
  options: ChannelOptions(
    credentials: isSecure ? const ChannelCredentials.secure() : const ChannelCredentials.insecure(),
    keepAlive: const ClientKeepAliveOptions(
      pingInterval: Duration(seconds: 30),
      timeout: Duration(seconds: 20),
      permitWithoutCalls: true,
    ),
  ),
  ```
  `ClientKeepAliveOptions` is provided by `package:grpc/grpc.dart` (already imported), so no new import is needed. Do NOT touch the per-service clients (`authService`, the three realtime stream services, unary services), the interceptor wiring, or any reconnect logic in `GrpcConnectionManager` — the shared channel covers all RPCs and the stream clients already react to a closed stream via `onError`/`onDone` → `scheduleReconnect()`. Do NOT override `idleTimeout`; leave its default. No proto change, no server dependency — ships in any order relative to mind_api Phase 41.

  Guard (post-merge, behavioral — not a code change for this task): if logs show server-side ping-policy pushback (`GOAWAY` / `ENHANCE_YOUR_CALM`) during a normal long session, drop `permitWithoutCalls` to `false` (active-call pings already cover the whole session since biometrics stream throughout).
