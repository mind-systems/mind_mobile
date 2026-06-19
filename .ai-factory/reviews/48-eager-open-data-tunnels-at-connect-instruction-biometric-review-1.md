# Code Review: Eager-open data tunnels at connect (instruction + biometric)

**Branch:** dev
**Reviewer:** code review pass 1
**Scope:** `lib/Core/Grpc/ModuleInstructionStream.dart`, `lib/Biometrics/BiometricStreamClient.dart`, `lib/Core/App.dart`

## Summary

The change makes both data tunnels open eagerly on `GrpcConnectionState.connected`, mirroring the already-eager state tunnel (`ModuleStateChannel`). It is a faithful, minimal implementation of the plan. All three tasks are correctly applied, the readiness gate and biometric session gate / cooldown / replay ring are preserved intact, and no compilation breakage was found across call sites or tests. No correctness, security, or runtime-safety defects were identified.

## Verification performed

- **Full diff + status reviewed**, all three changed code files read in full alongside their collaborators (`GrpcConnectionManager`, `ModuleStateChannel`).
- **`_streamRequested` fully removed** — field, the `connected`-case conditional, the `emit()` assignment, and both `onError`/`onDone` assignments are all gone. No dangling references remain anywhere in the repo (only docs/notes mention it historically).
- **No call-site breakage from the new required `connectionState` param.** The only real construction site is `App.dart:215`, which now passes `connectionState: connectionManager.connectionState`. `connectionManager` is built earlier in the same method (line 206), so ordering is fine. Tests use `_FakeBiometricStreamClient implements BiometricStreamClient` (interface, not the real constructor) — no new public member was added, so the fake still satisfies the contract and tests compile.
- **`_FakeInstructionStream`** in the breath test implements `BreathModuleInstructionStream` (the wrapper), unaffected by the `ModuleInstructionStream` change.

## Correctness analysis

- **No double-open in `ModuleInstructionStream`.** `_openStream()` is unguarded against an existing `_streamSink`, but `GrpcConnectionManager.connect()` is itself guarded (`if (currentState == connected || _isConnecting) return`), so every `connected` emission is preceded by a `disconnected` (which tears down and nulls the sink). The seeded BehaviorSubject value is `disconnected`, so construction-time replay is a harmless no-op. This matches the existing, proven `ModuleStateChannel` pattern.
- **`BiometricStreamClient` is safer still** — `_ensureSinkOpen()` early-returns when `_sink != null`, so even a redundant `connected` cannot double-open.
- **Readiness gate re-arms per open** in both tunnels (`_openStream` resets `_isReady`/`_outbox`/`_readyTimer`; `_ensureSinkOpen` resets `_isReady`), preserving reconnect correctness — the core guard from notes 114/115.
- **Idle sink is inert** — `_encodeAndAdd()` still early-returns on `_currentSessionId == null`, and `emit()`'s outbox is flushed within the 5 s readiness fallback (or sooner on server `ready`), so neither idle tunnel accumulates unbounded buffer.
- **Subscription hygiene** — the new `_connectionSub` in `BiometricStreamClient` is cancelled first in `dispose()`; `ModuleInstructionStream` already cancels its `_connectionSub`.

## Non-blocking observations (no action required)

1. **Biometric eager-reopen is subject to the 2 s cooldown, unlike the state/instruction tunnels.** If a disconnect→`connected` cycle completes within 2 s of the last `_ensureSinkOpen` attempt, the cooldown short-circuits the eager reopen and the bio sink stays closed until the next trigger. This is explicitly mandated by the plan's guards ("preserve the bio session gate + cooldown") and is **not a regression** — the prior lazy implementation gated `_ensureSinkOpen` with the same cooldown. It self-heals during an active session (continuous `sendBatch` retries reopen once 2 s elapse, with the bounded replay ring covering the gap) and is harmless while idle (no samples flow). `_lastOpenAttempt` resets to `null` on `ModuleSessionStarted`, and after a steady-state session the last open is far in the past, so a real mid-session reconnect reopens immediately. Worth being aware of, but correct as specified.

2. **Cosmetic doc drift (pre-existing):** the `BiometricStreamClient._sink` field comment still reads "lazy-opened on first send" (line 36). The sink is now also opened eagerly at connect. Not a defect; optional cleanup for a future pass.

REVIEW_PASS
