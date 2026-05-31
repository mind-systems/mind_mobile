# Code Review — Area C: gRPC Connectivity + Home UX (Phases 14, 18)

**Date:** 2026-05-31
**Source:** conversation context (roadmap review, branch `bci-integration`)
**Scope:** `lib/Core/Grpc/{GrpcAuthInterceptor,GrpcConnectionManager,ModuleStateChannel,ModuleInstructionStream}.dart`, `lib/HomeModule/{HomeService,Presentation/HomeScreen/HomeViewModel}.dart` + Home cards

## Verdict

Both phase fixes are present and correct. The Phase 14 backoff bug is properly fixed (confirmConnected gated behind a first-message flag), the streaming auth header fix matches the spec, and the Phase 18 reconnect detection + shimmer loading are sound. Findings are robustness/precision nits only.

## Key Findings

- **[Low / robustness] Reconnect attempt counter is unbounded; `_nextDelay` raises `2^attempt` before clamping.** `GrpcConnectionManager._nextDelay` computes `base = _initialDelay * math.pow(2, _reconnectAttempt)` and only clamps afterward. `_reconnectAttempt` increments on every schedule and only resets on `confirmConnected()`. If the server stays down for ~50+ attempts, `pow(2, attempt)` overflows the `Duration` microsecond int64 before the clamp. The final `ms.clamp(0, maxDelayMs)` keeps the *delay* safe, but the intermediate `Duration` multiplication is the overflow point. Fix: clamp the exponent (`math.pow(2, math.min(_reconnectAttempt, 5))`) or cap `_reconnectAttempt`.
- **[Low / precision] A single connection drop increments backoff ~twice.** Both `ModuleStateChannel` and `ModuleInstructionStream` independently call `disconnect()` + `scheduleReconnect()` from their own `onError`/`onDone`. On one real drop both streams error, so `_reconnectAttempt` advances by 2 and the second `scheduleReconnect` cancels+reschedules the first. Backoff grows faster than the nominal curve. Self-correcting (first `confirmConnected` resets to 0) and not user-visible, but the counter is per-stream-error, not per-drop.
- **[Low / info] `HomeGrpcReconnected` can fire on the very first connect, not only on reconnects.** `HomeService.observeChanges` uses `connectionStateStream.pairwise().where(last==connected && first!=connected)`. The `first!=connected` guard correctly suppresses BehaviorSubject seed-replay, but the initial `disconnected→connecting→connected` sequence still produces a `(connecting, connected)` pair → one `HomeGrpcReconnected` → a redundant `_loadInitialData()` if the Home screen mounts before the first connect settles. Harmless extra load; flag only if double-fetch on cold start matters.

## Details

### Phase 14 — confirmed fixed
- `ModuleStateChannel._openSessionStream` (and `ModuleInstructionStream._openStream`) reset `_backoffConfirmed = false` on open and call `_connectionManager.confirmConnected()` only inside the `response.listen` data callback, guarded by `if (!_backoffConfirmed)` — i.e. on the **first real server message**, not immediately after `.listen()`. Exponential backoff now actually grows across failed attempts.

### Phase 14 — auth interceptor
- `GrpcAuthInterceptor.interceptStreaming` uses `options.mergedWith(CallOptions(providers: [_addAuthMetadata]))` — identical to `interceptUnary`. The stale `_cachedToken` static field is gone; the token is read from `FlutterSecureStorage` lazily per call via the provider. Trade-off: a keychain read per unary call / per stream open (no cache) — acceptable for correctness; note if call volume ever spikes.
- Unauthenticated handling: unary watches `response.then(onError)`, streaming watches `response.trailers.then(onError)`; both route `StatusCode.unauthenticated` to `LogoutNotifier.triggerLogout()`.

### Design note (not a finding)
`GrpcConnectionManager.connect()` is fully synchronous and optimistic — it emits `connecting` then `connected` with no real socket handshake. "Connected" therefore models *logical* auth+connectivity intent; the true transport-liveness signal is a stream's first message (hence `confirmConnected` lives there). Reasonable, but any consumer treating `connectionState == connected` as "socket is up" would be wrong.

### Phase 18 — Home reconnect + shimmer (correct)
- `HomeViewModel._onEvent` handles `HomeGrpcReconnected → _loadInitialData()`; `StatsInvalidated → _loadStats`; `HomeAppResumed → _loadSuggestions`; `HomeAuthenticated → isGuest=false + reload`; `HomeSessionExpired → reset`.
- `isSuggestionsLoading` / `isStatsLoading` are set true at the top of each loader and cleared in **every** branch (success, null-stats, and catch). Cards gate shimmer on `!isGuest && isLoading`, so guests see nothing — matches Phase 18 spec.

## Open Questions

- Worth capping `_reconnectAttempt` (cheap, prevents the theoretical overflow) — confirm 5–6 as the exponent ceiling (32–64s, already above the 30s `_maxDelay`).
- Is the first-connect `HomeGrpcReconnected` double-load acceptable, or should the event be suppressed until at least one prior `connected` has been seen?
