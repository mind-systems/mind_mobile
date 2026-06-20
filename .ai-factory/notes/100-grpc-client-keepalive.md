# Client-side gRPC keepalive — symmetric hardening for the realtime channel

**Date:** 2026-06-20
**Source:** conversation context

## Key Findings

- The Dart `grpc` `ClientChannel` is built with keepalive **disabled**. `GrpcClient` (`lib/Core/Grpc/GrpcClient.dart:24-25`) passes `ChannelOptions(credentials: …)` only — `keepAlive` defaults to `const ClientKeepAliveOptions()`, whose `pingInterval` is `null`, and `shouldSendPings => pingInterval != null` is false. The client never PINGs the server.
- Consequence: the client can only notice a silently-dead server through a failed write (biometrics are streamed continuously, so this is usually fast) or via the OS TCP timeout (slow). Through the prod TLS path (`grpc.mind-awake.life:443`, likely behind a load balancer), an idle/half-open connection can linger until the next write fails.
- This is the **mirror** of the `mind_api` server-keepalive fix (mind_api note 51 / Phase 41). The server change reaps dead *clients*; this change lets the client reap a dead *server* and keeps the LB connection warm. **Not required** for the server fix to work — the client already tolerates server pings and reconnects robustly (`onError`/`onDone` → `disconnect()` + `scheduleReconnect()`, backoff 1–30s across all three realtime streams). Pure defense-in-depth.

## Details

### The change

`grpc` 5.1.0 API (verified in `~/.pub-cache/.../grpc-5.1.0/lib/src/client/options.dart` + `client_keepalive.dart`):

```dart
class ClientKeepAliveOptions {
  final Duration? pingInterval;          // null ⇒ no pings (current default)
  final Duration  timeout;               // default 20s — wait for ping ack before declaring dead
  final bool      permitWithoutCalls;    // default false — only ping while a call is active
  const ClientKeepAliveOptions({ this.pingInterval, this.timeout = const Duration(seconds: 20), this.permitWithoutCalls = false });
}
```

In `GrpcClient` (`lib/Core/Grpc/GrpcClient.dart:24-25`) add `keepAlive` to the existing `ChannelOptions`:

```dart
options: ChannelOptions(
  credentials: isSecure ? const ChannelCredentials.secure() : const ChannelCredentials.insecure(),
  keepAlive: const ClientKeepAliveOptions(
    pingInterval: Duration(seconds: 30),
    timeout: Duration(seconds: 20),
    permitWithoutCalls: true,   // keep the connection warm between calls (prod LB idle-timeout)
  ),
),
```

- `pingInterval: 30s` mirrors the server cadence (mind_api note 51). Keep it ≥ the server's `min_ping_interval_without_data_ms` guard (25s) — they are independent directions (client→server vs server→client pings), but symmetric values avoid surprises.
- `permitWithoutCalls: true` so the channel is pinged even when no RPC is in flight (between sessions), keeping a NAT/LB mapping alive. If this ever triggers a server-side `GOAWAY ENHANCE_YOUR_CALM` (server enforces `GRPC_ARG_HTTP2_MIN_RECV_PING_INTERVAL_WITHOUT_DATA_MS`, default 5 min), back the interval off — but with `pingInterval: 30s` and no-active-calls being rare (biometrics stream continuously during a session), this is unlikely.

### Scope / guards

- One change in `GrpcClient` — the channel is shared by all RPCs (auth, the three realtime streams, unary calls). Do not touch the individual stream clients or the reconnect manager; they already react correctly to a closed stream.
- No proto change, no server dependency. Ships independently of the `mind_api` change, in any order.
- `idleTimeout` on `ChannelOptions` already defaults to a sane value; do not override it as part of this task.

### How to verify

- During an active session, kill the server (or block its egress) ungracefully. With keepalive on, the client should detect the dead connection within ≈ `pingInterval + timeout` (~50s) via the ping-timeout path and trigger `scheduleReconnect()`, instead of hanging until the next write fails or the OS TCP timeout.
- Confirm no `GOAWAY`/`ENHANCE_YOUR_CALM` appears in logs during a normal long session (pings are within server tolerance).

## Open Questions

- `permitWithoutCalls: true` vs `false`: `true` keeps idle connections warm (better through LB/NAT) but pings between sessions. If the prod LB or server complains, drop to `false` (ping only during active calls — which already covers the whole session since biometrics stream throughout). Default to `true`; revisit only if logs show ping-policy pushback.
