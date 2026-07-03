# Plan: Update realtime docs to the root/child model

## Context
Rewrite the two realtime tracking docs (in Russian) so they describe the shipped root + N children model — bio tagged with `root.id`, phases with the child id, client-owned pause gap, end only on explicit finish, the new client structure (registry, `RootStateChannel`, reconnect/reconcile), and the connection-resilience behaviour (transparent reconnect; last-connect-wins → session moves to another device, this one goes passive until "use here").

## Settings
- Testing: no
- Logging: no
- Docs: yes (this milestone IS the doc rewrite)

## Global guards (apply to every task)
- **Russian**, matching the tone and structure of the existing docs.
- **Describe behaviour, not code** — no method/field dumps, no file trees, no FSM/`SessionTerminated`/enum internals. The resilience section is behaviour-level only.
- **Current state only** — no "was changed / removed / added" history.
- After the rewrite, **no remaining reference** to "one active session per user" / "повторный старт игнорируется", nor to server-side pause filtering ("сервер блокирует входящие сэмплы фаз") — **in any file under `docs/realtime/`, including the `data-flow.mmd` diagram**, not only the prose docs.

## Tasks

### Phase 1: Rewrite `live-session-tracking.md`

- [x] **Task 1: Rewrite the session-model, lifecycle, correlation and pause sections**
  Files: `docs/realtime/live-session-tracking.md`
  Rework the core-model parts of the doc to root + N children:
  - **Session model** (replaces "Один поток на все модули" `:78-82`): one **root** per user — a session for the app itself, opened by the client via `activity:start{ROOT}` once the state stream is up, never ended by the client. Over the root's shared timeline lie **N flat children**, ordinary module sessions distinguished only by `activity_type` (breath / meditation). Concurrent children are the point: start breathing mid-meditation and both run at once. Delete the retired "сервер держит одну активную сессию на пользователя; повторный старт игнорируется" claim entirely.
  - **Lifecycle** (`:7-22`): `end` fires **only on explicit user finish** (breath completion, meditation Stop). Navigating away from a running screen does **not** end the child — it stays live on the server and its bio keeps flowing under the root. Keep `start` semantics and `clientTimestampMs`.
  - **Correlation key → root.id** (`:48-50`, and the bio-correlation section `:95-107`): bio samples bind to the **root** timeline and carry `root.id`; instruction/phase samples carry the **child** id. Analytics time-joins both against the root timeline. A child ending does not stop bio; bio stops only on whole-tree reset / disconnect.
  - **Phase-instruction pause** (`:52-58`): correct the myth — on pause the client simply **stops emitting phase samples**; the server filters nothing. The clean gap in the log is client-produced (pause marker → gap → resume marker). Pause-sample policy is client-owned. Keep the "phase sample held until the child id / correlation key is known" behaviour.
  Preserve the accurate sections where they still hold (control/data plane tunnels, tunnel readiness/backpressure), adjusting wording only where they assumed a single session.
  - **Do NOT blindly preserve the `## Фоновый режим Android` section** (`:74-76`). It currently says the foreground service starts/stops purely on the server session events. That is stale: keep-alive is also driven by the breath activity's **local live edge** (the offline path the server events miss) and released when the session terminates. Re-describe it behaviour-level — the foreground service is held while a session is live and released when it finishes, driven by both the server lifecycle and the local activity's live edge — and **drop the raw `ModuleSession*` event-enum names** per the describe-behaviour-not-code guard. Verify the wording against `lib/Core/Background/KeepAliveCoordinator.dart` rather than copying the current prose.

- [x] **Task 2: Rewrite the connection structure and add the resilience-behaviour section** (depends on Task 1)
  Files: `docs/realtime/live-session-tracking.md`
  Update the connection sections (`:38-40` metadata reconnect, `:66-72` connect/reconnect, `:84-93` adapters) and add a new resilience section, all behaviour-level:
  - **Client structure**: the control channel holds a **session registry** — the root plus its live children, each routed by `activity_type`. A dedicated **root channel** opens the root on every (re)connect and exposes `root.id` (idempotent per user; it never sends end/pause/resume). Commands are addressed: a start carries a stable client-side idempotency token (reused across retries, never regenerated) so a re-sent start returns the same child instead of a duplicate; end/pause/resume carry the target child's id so one child can finish while siblings stay live.
  - **Reconnect**: the reconnect request carries `root.id` in metadata. Within the server grace window the tree is rebuilt by reconcile-by-arrival — children that re-announce survive with their real paused state, children that do not are dropped; `root.id` is re-learned from the root re-open. Past the window the server abandons the whole tree as one set and the client resets and starts a fresh root.
  - **Resilience behaviour** (new section, notes 20/25/26 — behaviour only): the app survives transport drops and reconnects **transparently**, continuing the same session. Under last-connect-wins, opening the account on **another device moves the live session there** — this device goes **passive** ("opened on another device"), stops recording, and does **not** fight to reclaim it (no auto-reconnect war). It stays passive until the user explicitly chooses **"use here"**, which moves the session back and passivates the other device. Do NOT document the FSM states, `SessionTerminated`, or eviction codes — only the observable behaviour.

### Phase 2: Rewrite `meditation-tracking.md`

- [x] **Task 3: Update the meditation doc to the root/child model** (depends on Task 1)
  Files: `docs/realtime/meditation-tracking.md`
  - **Remove end-on-dispose** — not only at `:74` and the "Реализация" block `:52-72`, but also the **intro (`:3`) and the lifecycle intro (`:11`)**, which currently dump `channel.start(...)`, the `_started`/`_ended` flags and `dispose()`-shaped teardown detail and imply object-teardown lifecycle. Rewrite all of these: meditation ends **only on explicit Stop** (`active → idle`). Leaving the meditation screen does not end the session — it stays a live child; bio keeps recording under the root (this is already the deliberate "biometrics continue in background" behaviour, now generalised). The whole doc must be behaviour-level after this — no `dispose()`/flag/method-call residue anywhere.
  - **Concurrent children**: frame meditation as **one child among N** on the shared root — not a lone session. Starting breathing during meditation leaves meditation running; finishing breathing ends only the breath child.
  - Keep the meditation-specific, still-accurate content: no phase instructions, no pause/resume, the post-session note screen, the session timer, and `refId` as the pose UUID. Update the "Чего нет по сравнению с Breath" table only where a row referenced the retired lifecycle (e.g. describe dispose/finish behaviour in terms of explicit finish, not object teardown).
  - Trim the code-shaped "Реализация" block so it describes behaviour rather than dumping method calls (`channel.start(...)`, `onDispose → channel.dispose()`), per the describe-behaviour-not-code guard.
  Keep the cross-links to `live-session-tracking.md` and the biometrics stream-pipeline doc.

### Phase 3: Update the data-flow diagram

- [x] **Task 4: Rewrite `data-flow.mmd` to the root/child model** (depends on Task 1)
  Files: `docs/realtime/data-flow.mmd`
  `live-session-tracking.md:5` points at this diagram as the "общая картина потоков", yet it still encodes the retired model verbatim and now contradicts the rewritten prose. Bring it in line:
  - `Session engine` node (`:21`): drop **"one active session per user"** — describe a **root + N concurrent children** on a shared timeline (the root is opened by the app on connect; children overlay it).
  - The single **"correlation key"** binding (`:34-35` edges, `:46` analytics time-join): replace with the split — **bio binds to `root.id`, phase/instruction to the child id**, both time-joined against the shared **root** timeline. Remove "issues correlation key" / "correlation key" edge labels in favour of the root-id / child-id split.
  - Keep the still-accurate structure (one connection, tunnels open on connect, readiness ack, buffered flush, passive background bio).
  - **Mermaid `.mmd` pitfalls** (mobile `CLAUDE.md`): if any new node ids are added, do not use JS reserved words or `pause`/`resume`/`complete`/`constructor` as ids (prefix them); no `text-align` in inline styles; use `<br/>` not long box-drawing separators. Reuse existing node ids where possible to avoid the risk. The SVG is regenerated by GitHub Actions — do not hand-edit `data-flow.svg`.
