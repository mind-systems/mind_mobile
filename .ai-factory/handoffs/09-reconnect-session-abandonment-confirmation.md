# Handoff — reconnect session abandonment confirmation

## 1. Frame
A cross-project protocol decision was settled in **mind_api**: how a reconnecting mobile client learns that its in-flight session was abandoned (grace expired while backgrounded). The server side is speced in mind_api; this note is the **mobile-side contract + the work required from mind_mobile**. The chat is compacted — rehydrate from the files below, not memory.

## 2. Read-first map

### Must-read now (minimal rehydration set)
- `mind_api/.ai-factory/notes/62-reconnect-no-session-terminal-event.md` — the full settled contract: how the server resolves a reconnect and when it emits the abandonment confirmation. ← single best entry doc
- `mind_api/docs/realtime/session-lifecycle.md` (~line 20) — the `idle` vs `abandoned` protocol: "no unfinished session on connect ⇒ client receives `idle`, not `abandoned`."

### Read on demand
- `mind_mobile/lib/Core/Grpc/ModuleStateChannel.dart` — opens the control stream **eagerly on connect** (`:54-57`); maps proto lifecycle events incl. `ABANDONED → reset` (`:136-138`).
- `mind_mobile/lib/.../BiometricStreamClient.dart` — `_onLifecycleEvent` (`:82-86`), `_currentSessionId` gating (the source of the `NO_SESSION` flood today).
- `mind_mobile` notes 137 / 143 / 144 — prior client-timestamp + reconnect/abandoned handling.

## 3. Current state

**Done:**
- Server-side approach decided and speced (mind_api `note 62` rewritten; mind_api ROADMAP milestone rewritten under the new design).
- The earlier server approaches were rejected (see Error log).

**In-flight:**
- mind_api server task not yet planned/implemented (pending `/aif-plan` → implement on the mind_api side).
- mind_mobile work not started.

**Uncommitted working-tree state:**
- mind_api: `ROADMAP.md` + `notes/62-...md` modified; the failed orchestrator run's slug-79 artifacts (plan/plan-reviews/reviews/sidecar) deleted — all uncommitted.
- mind_mobile: nothing yet (this handoff note only).

## 4. Next step
Mobile work lands **after** mind_api ships the server side. Implement three things (detail in §10): present the `moduleSessionId` on reconnect, gate biometric streaming on a confirmed session, and handle the abandonment confirmation. First action: confirm with mind_api which id-transport mechanism shipped (gRPC metadata `module-session-id` — the pinned choice — vs a `ResumeCmd` proto message).

## 5. Working discipline
Confirm before executing; show diffs before applying. **Never commit without explicit permission.** All files in English. Do not auto-create or resurrect sessions — a new session is born only on an explicit user `activity:start`.

## 6. Error log
Mistakes from the prior (server-side) attempts — listed so the mobile side does not rebuild the same broken mental model:
- **Blanket `ABANDONED` on `handleReconnect === null`** → fired on *every* idle/fresh connect, contradicting the documented `idle` protocol. `null` ≠ abandoned.
- **`recentlyAbandoned: Set<userId>` server memory** → unbounded growth (offline-abandoned users who never return) + a watchdog TOCTOU that plants a stray flag → spurious `ABANDONED` on a later legitimate connect.
- **Mobile equivalent to avoid:** do NOT infer abandonment from a *timeout* / absence of `RESUMED`. Decide only on a **positive** signal (`RESUMED` to confirm, or `ABANDONED` to reset).

## 8. Domain model spine (don't re-litigate)
- `handleReconnect === null` means fresh / idle / cleanly-ended — **not** abandoned. → `mind_api/.ai-factory/notes/62-...md`.
- An abandoned session is **terminal**: never resurrected, never auto-replaced. New session only on explicit `activity:start`. → note 62.
- The gRPC control stream is **long-lived across many sessions** (opened on connect, not per session). "Stream open, no session" is the normal idle state — not a bug, not a phantom session. → `ModuleStateChannel.dart:54-57`.
- Session start/end already ride the client clock (`client_timestamp_ms`); abandonment confirmation is the remaining reconnect gap. → mind_mobile notes 137/143/144.

## 9. Hard rules
- Proto is owned by **mind_api**. If mind_api adds a `ResumeCmd` message instead of using metadata, copy the updated `module_state.proto` into `mind_mobile/proto/` and regenerate — never author or symlink proto.
- Backward compatibility: a client that sends no session id must behave exactly as today (server stays silent = idle).

## 10. What mind_mobile must implement (the contract)
1. **Present the session id on reconnect.** When (re)opening the `trackActivity` stream while the client believes it holds an active session, attach gRPC metadata **`module-session-id: <last-known moduleSessionId>`**. Omit it on a genuinely fresh/idle open. (If mind_api ships `ResumeCmd` instead, send that as the first stream message — coordinate.)
2. **Gate biometric streaming on a confirmed session.** Do NOT stream biometrics into a session until it is confirmed by `RESUMED` (server re-confirms the id) **or** a fresh `activity:start`. On reconnect, treat the local `moduleSessionId` as **unconfirmed** and suspend streaming until confirmation. This alone removes the `NO_SESSION` flood regardless of server timing — it is the load-bearing client invariant.
3. **Handle the abandonment confirmation.** On `sessionState{ status: ABANDONED, moduleSessionId }` → reset to idle (already mapped, `ModuleStateChannel.dart:136-138`). Optionally surface a "session lost" UX.
4. **Silence ⇒ idle.** If on reconnect neither `RESUMED` nor `ABANDONED` arrives → the session is fresh/idle/cleanly-ended → stay idle, stream nothing, do not auto-create.
5. **Grace path unchanged.** Reconnect within 30 s → server sends `RESUMED` with the id → resume normally.
