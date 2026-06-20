# Plan Review: Enable `ClientKeepAliveOptions` on the shared gRPC channel

**Plan:** `.ai-factory/plans/63-enable-clientkeepaliveoptions-on-the-shared-grpc-channel.md`
**Files Reviewed:** 1 plan + verified against `lib/Core/Grpc/GrpcClient.dart`, grpc 5.1.0 package source, ROADMAP Phase 44
**Risk Level:** 🟢 Low

## Verification Performed

Every concrete claim in the plan was checked against the codebase and the pinned `grpc: ^5.1.0` package source:

- **API correctness** — `ClientKeepAliveOptions` is exported from `package:grpc/grpc.dart` (`grpc.dart:24`), already imported at `GrpcClient.dart:3`. Constructor params `pingInterval` (`Duration?`), `timeout` (`Duration`, default 20s), `permitWithoutCalls` (`bool`, default false) all match the plan's usage exactly (`src/client/client_keepalive.dart:25-47`). ✅
- **`ChannelOptions.keepAlive`** — confirmed to exist as a field (`src/client/options.dart:62`, constructor at `:73`). The plan's `keepAlive:` argument is valid. ✅
- **Target line** — `ChannelOptions(credentials: …)` is on `GrpcClient.dart:25` (the constructor initializer the plan calls out as `:24-25`). Single creation site; no other `ChannelOptions` instances in `lib/`. ✅
- **Transport support** — keepalive is wired through the dart:io HTTP/2 transport (`src/client/http2_connection.dart` has `keepAliveManager`), so it is effective on Flutter mobile. ✅
- **Reconnect claim** — confirmed: stream clients call `_connectionManager.scheduleReconnect()` on error/done (`ModuleInstructionStream.dart:148,156`), and `GrpcConnectionManager.scheduleReconnect()` exists (`GrpcConnectionManager.dart:111`). The plan's instruction not to touch these is correct — the closed channel propagates to streams which already reconnect. ✅
- **Timing math** — `pingInterval 30s + timeout 20s ≈ 50s` dead-server detection is consistent with the package's keepalive manager behavior. ✅

## Context Gates

- **Architecture (`ARCHITECTURE.md`)** — `WARN` none. Change is confined to the Core gRPC infrastructure layer; no module-boundary, DTO, or domain-leak concerns. Aligned.
- **Rules (`RULES.md`)** — `WARN` none. The three rules (stateless module services, App.dart purity, constructor injection) are not touched by this change.
- **Roadmap (`ROADMAP.md`)** — Aligned. The plan is a faithful 1:1 implementation of **Phase 44** ("Enable `ClientKeepAliveOptions` on the shared gRPC channel"), including the exact ping/timeout values, the "do not touch per-stream clients / `GrpcConnectionManager`" constraint, and the `permitWithoutCalls` pushback guard. Linkage is explicit.
- **Skill-context** — `.ai-factory/skill-context/aif-review/SKILL.md` not present; no project-specific review overrides to apply.

## Observations (non-blocking)

1. **`idleTimeout` default undercuts the "warm between sessions" claim (WARN).** The plan (and ROADMAP) state `permitWithoutCalls: true` "keeps the prod LB/NAT mapping warm between sessions" while deliberately leaving `idleTimeout` at its default. That default is **5 minutes** (`src/client/options.dart:23`, `defaultIdleTimeout`). When no calls are active, the connection arms an idle timer and tears down after 5 min (`http2_connection.dart:272-273` → `_handleIdleTimeout` → `_disconnect`), at which point keepalive pings stop with it. So the "warm connection" benefit only holds for idle gaps **shorter than 5 minutes**; longer between-session gaps will still drop the channel (then reconnect normally on next use). This is a caveat on the stated rationale, not a defect — dead-server detection during active/short-gap usage (the primary goal) works as designed. No plan change required; flagging so expectations are accurate.

2. **Server ping-policy pushback risk is already handled.** Pinging every 30s with `permitWithoutCalls: true` against a server that doesn't permit pings-without-data can draw `GOAWAY`/`ENHANCE_YOUR_CALM`. The plan's post-merge behavioral guard (drop to `permitWithoutCalls: false`) is the correct mitigation and explicitly noted. Coordination with mind_api Phase 41 server keepalive is acknowledged. ✅

3. **Logging setting honored.** Plan declares "Logging: minimal" and adds no log statements — appropriate for a one-option config change; existing detach/shutdown logging in `GrpcClient` is untouched.

## Positive Notes

- Correctly identifies the shared-channel design so a single edit covers all 13 service clients without per-client changes.
- Explicitly scopes out reconnect logic, interceptors, and `idleTimeout` — preventing accidental over-reach.
- Anticipates the realistic failure mode (server ping pushback) with a concrete, reversible guard.
- Code snippet is syntactically valid and uses only already-imported symbols — no new import needed, as claimed.

The plan is technically sound, accurately scoped, and aligned with the roadmap. The single WARN is a wording caveat on the stated benefit, not an implementation flaw.

PLAN_REVIEW_PASS
