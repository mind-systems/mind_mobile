# Handoff — mind_mobile root/child realtime rollout

> Audience: an agent working **inside `mind_mobile`** (separate git repo). This brief is authored from the `mind_api` side and explains exactly what the backend realtime contract is, what the mobile client must do, and where the authoritative answer for every detail lives. All `mind_api/...` paths below are readable from the monorepo (`/Users/max/projects/mind/...`). **The `mind_api` backend is DONE & committed on branch `feature/root-session` — the contract below is LIVE, not aspirational. There is no blocker; this gets its own `/aif-plan` inside `mind_mobile`.**

## 1. Frame
`mind_api` evolves the realtime subsystem to a **continuous-bio-timeline** model (bio lives on one continuous **root session** per user; breath/meditation are flat **child sessions** overlaid on that timeline) plus a **generic session-data-flow** epic (the root is a normal **client-started module session of type `root`**, and data ingestion is ownership-addressed — any number of concurrent activities each stream their own data, all overlaid on one root bio timeline). The mobile client is the **producer** that adopts this model. The API chat is compacted but every decision is durable in `mind_api/.ai-factory/notes/` — rehydrate from the files named below, don't trust memory.

The target capability, concretely: the user starts a **meditation** (child M); mid-way starts a **breathing module** (child B) that brings them to a state and finishes; the meditation keeps running. M and B have **different `session_id`s**, run in parallel, and both record against the **same root bio timeline** (each slices its own `[startedAt, endedAt)` window of the shared root bio).

## 2. Read-first map (all in `mind_api/`)

### Must-read now (minimal rehydration set)
- **The committed implementation itself** (`feature/root-session`) — the ultimate ground truth, now REAL, not a spec: a1 `d111c4c` (client-started ROOT + `activity_type` discriminator + `CANNOT_END_ROOT`), a2 `8585de4` (bio ingest ownership), a3 `7f96da3` (instruction ingest ownership); corrective tests `bc06827` + `a5b709f`. The consumer-facing surfaces to read: `proto/module_state.proto` and `src/realtime/module-{state,instruction-stream,biometric-stream}.grpc.controller.ts`. If a spec note and the code ever disagree, **the code wins** — but they were audited consistent.
- `.ai-factory/notes/13-mobile-proto-regen-behavior.md` — the **command-side mobile spec**: which proto to copy, the regen command, the `client_activity_id` / `session_id` / don't-end-on-navigation behavior changes, verify steps. Start here for the command half.
- `proto/module_state.proto` — the changed contract. Relevant fields: `client_activity_id = 5` on `ActivityStartCmd`; `optional session_id` on `ActivityEnd/Stop/Pause/ResumeCmd`; **`ROOT` added to the `ActivityType` enum**; **`ActivityType activity_type = 4` added to `StateEvent`** (the discriminator on every state frame). This is what you copy + regenerate. (There is **no `is_root` field** — an earlier design used one; it was withdrawn in favour of `activity_type`.)
- `.ai-factory/notes/34-deliver-root-id-on-connect.md` — **how the client opens & learns its root id:** the client sends `activity:start { activity_type: ROOT }`; the server upserts the user's root (idempotent by `userId`) and responds with a `session:state` whose `activity_type == ROOT` and `module_session_id == root.id`. The root is distinguished from a child **by `activity_type`, never by a connect frame or ordering.** (Filename is legacy; the design inside is client-started root.)
- `.ai-factory/notes/36-generalize-instruction-ingest-ownership.md` — instruction/phase ingest accepts **any live session the user owns** (any child OR the root), addressed by `session_id` — so N concurrent activities each stream phases, and root-level marks attach to the root.
- `.ai-factory/notes/35-generalize-bio-ingest-ownership.md` — bio binds to the root, resolved server-side from `userId`; the client tags `BioSample.session_id` with `root.id` and the server is tolerant (it stores under the resolved root regardless).

### Read on demand (answer-lookup by question)
- "Root vs child? schema?" → `notes/02-root-session-schema.md` (`rootSessionId` nullable; `root` is a real `activityType`; FK `ON DELETE CASCADE`).
- "Multiple concurrent sessions on the server?" → `notes/03-multi-session-store-engine.md`, `notes/04-lazy-root-creation.md` (root idempotent **per userId**; reconnect resumes, never duplicates).
- "Command routing / start dedup?" → `notes/06-state-controller-concurrent-idempotency.md` (`session_id` → sole-child fallback → `AMBIGUOUS_SESSION`; `client_activity_id` short-window dedup; revoke stops all children + root).
- "How is bio read back per activity?" → `notes/09-analytics-tolerant-bio-read.md` (windowed time-join: a child slices `[startedAt, endedAt)` of the shared root timeline).
- "Human-readable behavior?" → `mind_api/docs/realtime/*.md` + `docs/stats/stats.md` (Russian; the root/child docs).

## 3. Current state

**Backend — DONE & committed (`feature/root-session`):**
- Bio-timeline (schema, multi-session store/engine, lazy root, proto `session_id`/`client_activity_id`, concurrent-start routing + idempotency, root excluded from stats/run-history, empty-root janitor, deleteRun orphan cleanup, tolerant windowed bio read, bio ingest bound to root, 1:1 backfill migration, Russian docs).
- Generic session-data-flow — the root is a client-started `activity_type=ROOT` session (a1 `d111c4c`); bio ingest resolves the root server-side and ignores the client echo (a2 `8585de4`); instruction ingest accepts any owned live session (a3 `7f96da3`, N concurrent children + root-level marks). The proto (`ActivityType += ROOT=3`, `StateEvent += activity_type=4`, no `is_root`) is regenerated and committed in `mind_api/proto/generated`.

**No blocker.** The contract is live and stable. `feature/root-session` is not yet merged to `dev`/`master` and a full API code-review is pending, but neither changes the wire contract below — copy the proto from `mind_api/proto/` and build. (If you want to gate on the merge, ask the human; the API side considers the contract frozen.)

**Mobile (mind_mobile) — not started.** Gets its own `/aif-plan`.

**In-flight in `mind_api` (does not affect mobile):**
- A server-side **realtime durability** epic (immediate marker persistence, connection-loss markers, pause-state integrity, restart rehydration) is parked — **server-internal, no proto/contract change** for mobile. Ignore it. The one mobile-visible nicety it later brings: the reconnect `session:state` reporting the *actual* `is_paused` instead of a hardcoded `false`.

## 4. Next step
Run `/aif-plan` **inside `mind_mobile/`** for the client rollout. The plan covers:
1. Copy `mind_api/proto/module_state.proto` → `mind_mobile/proto/` (overwrite) and regenerate Dart stubs with `./scripts/gen_proto.sh` (**NOT** `build_runner` — that's Drift).
2. **Open the root explicitly:** send `activity:start { activity_type: ROOT }` once the state stream is up; read the response `session:state` whose `activity_type == ROOT` and store its `module_session_id` as the **root id**. The call is idempotent by user — safe to (re)send; it always returns the same root.
3. Send a retry-stable `client_activity_id` on every `activity:start`; keep the returned **child** id (a `BREATH`/`MEDITATION` start returns a child, an `ROOT` start returns the root).
4. Thread the target child's `session_id` on `end/stop/pause/resume`. **Never** send `end`/`stop` for the root id — the server rejects it with `CANNOT_END_ROOT`.
5. Stop sending `activity:end` on screen navigation — only on explicit user finish.
6. **Bio stream:** tag `BioSample.session_id = root.id` (known from step 2). The server resolves the root from `userId` and is tolerant, but send the real root id.
7. **Phase/instruction stream:** tag each phase sample with the **child** id of the activity producing it. Concurrent activities each stream their own phases (the server accepts any owned live session). Optionally, root-level marks (device connect, screen open/close) can be streamed tagged with the **root** id.
8. Keep DTO/Drift shapes in sync with any changed realtime shape (the client now models one **root** + N **children**, and reads `activity_type` off every state frame).

## 5. Working discipline
- **Confirm-before-execute.** Show the plan and hold; never fabricate a contract detail — read it from `mind_api/proto/` or the named note.
- **Never commit without explicit user permission.** Commit messages: short noun phrase, sentence case, no `feat:`/`fix:` prefix, no body for single-concern.
- `mind_api/proto/` is the **single source of truth**. Consumers copy + regenerate, never symlink. Change order is always proto → mind_api → consumers (`/Users/max/projects/mind/CLAUDE.md`).
- `.ai-factory/` files in **English**; `mind_api/docs/` in **Russian**.
- Auth flow / `AuthInterceptor` is untouched by this refactor — do not modify it.

## 6. Error log (mistakes already made on the API side — don't repeat the reasoning)
- **Don't claim the server filters samples during pause.** It does NOT. The instruction stream / `stream-engine` have zero `isPaused`/phase-filter logic — a sample sent during pause is accepted and stored as-is. The pause "gap" in the phase stream is produced **by the client ceasing to emit phases**, not by any server-side drop. **Pause sample policy is entirely client-owned.** Do not add a "mobile must do X for pause" task.
- **The root IS `ActivityType.ROOT`.** The proto `ActivityType` enum now carries `ROOT` (`= 3`), and the client uses it: send `activity:start { activity_type: ROOT }` to open the root and identify the root frame by `activity_type == ROOT`. (An earlier design made the root server-internal and used an `is_root` bool — both are withdrawn. Do not look for `is_root`; do not treat `root` as a non-enum special case.)

## 7. Orientation (traps)
- **Distinguish the root by `activity_type`, not by ordering or a connect frame.** Every `session:state` carries `activity_type`; the root frame is the one with `activity_type == ROOT`. There is **no** unsolicited connect frame — the root id arrives as the **response to your own `activity:start { ROOT }`**.
- **root id vs child id.** A `ROOT` start returns the **root** id; a `BREATH`/`MEDITATION` start returns a **child** id. Thread the **child** id on `end/stop/pause/resume` and tag phases with it; tag **bio** and any **root-level marks** with the **root** id. Never conflate them, and never `end`/`stop` the root.
- **Concurrent phase streams are real.** Ingestion is ownership-addressed: two live children can each stream phases simultaneously (each tagged with its own child id). You must tag each phase with the **correct** child id; a sample tagged with a session the user doesn't own / that isn't live is rejected (`SESSION_NOT_FOUND`).
- **`module_biometric_stream.proto` did NOT change** — it already carries `session_id`. Bio→root is which id you put there (the root id), not a proto change. Only `module_state.proto` is recopied (for `ActivityType.ROOT` + `StateEvent.activity_type` + the command fields).
- **Lifecycle inversion:** the old client ended the session on leaving the activity screen. New rule: do **not** send `activity:end` on navigation — only on explicit finish. A meditation stays active while the user steps into breathing (the whole point of concurrent children).

## 8. Domain model spine (settled on the API side — do not re-litigate)
- **One root per user** (`ensureRoot` is idempotent by `userId`). The root is the "app is open" container, a normal module session of `activityType = root`. The client **opens** it via `activity:start { activity_type: ROOT }` and learns its id from the response; the server also ensures one lazily on connect so a bio-only flow has a root. Two devices on one account share the root (accepted).
- Bio binds to the **root**; a child is a time-window `[startedAt, endedAt)` on the shared root timeline. → `notes/09`, `notes/35`.
- **Two-level only:** `rootSessionId`, no `parentSessionId`. A root has `rootSessionId = null` and `activityType = 'root'`; a child carries a real `activityType` and `rootSessionId = root.id`. The root/child split is two fields, not a special path. → `notes/02`.
- **Root end is implicit:** the root ends only by grace (connection drop) or the janitor (childless, idle, no live connection). `activity:end`/`activity:stop` on the root → `CANNOT_END_ROOT`. → `notes/34`.
- A root is reaped only when it has **zero children** (FK cascade removes orphaned bio). → `notes/08`.

## 9. Hard rules
- Proto single-source-of-truth + copy/regen/no-symlink (§5).
- Regenerate Dart proto with `./scripts/gen_proto.sh`; `flutter pub run build_runner build` is **Drift only**, not proto (note 13, `mind_mobile/CLAUDE.md`).
- Never commit without explicit permission; English `.ai-factory/`; no memory writes without a trigger phrase.

## 10. Cross-cutting contract checklist (what mobile sends/expects — verify each against `proto/module_state.proto`)
- **`ActivityType.ROOT`** (enum value `= 3`) — send `activity:start { activity_type: ROOT }` to open the root; the response frame's `activity_type == ROOT` carries `module_session_id = root.id`. Store it as the root id.
- **`StateEvent.activity_type`** (field 4) — present on **every** `session:state`; `ROOT` marks the root frame, a practice type (`BREATH`/`MEDITATION`) marks a child frame. This is the only root/child discriminator. (No `is_root` field exists.)
- **`ActivityStartCmd.client_activity_id`** (field 5, optional string) — locally generated, **stable across retries** of the same logical start. Server dedups within a short window → returns the same session instead of a duplicate.
- **`ActivityStartCmd.ref_id`** (field 2, optional string) — the breath-session / practice reference id (maps to `activityRefId` on the entity; no hard FK). Send it on a `BREATH`/`MEDITATION` start to link the session to its practice record; omit on a ROOT start. **Wire name is `ref_id`, not `activity_ref_id`.** (`client_timestamp_ms` = field 4; field 3 is reserved.)
- **`ActivityEnd/Stop/Pause/ResumeCmd.session_id`** (optional string) — address a specific child among concurrent ones. Omit → server uses the sole child, or errors `AMBIGUOUS_SESSION` if >1 child is live. The root id is **not** a valid target for end/stop (`CANNOT_END_ROOT`).
- **`BioSample.session_id = root.id`** — the root id from the ROOT-start response. Server resolves the root from `userId` and is tolerant of the echo, but send the real root id.
- **Phase/instruction samples** — tagged with the producing **child** id; N concurrent children supported; root-level marks tagged with the **root** id. A sample tagged with a session not owned / not live is rejected (`SESSION_NOT_FOUND`).
- **Reconnect** resumes both the root and any live children (server resumes disconnected sessions during the grace window); resumed-child frames carry `status: resumed` + their `activity_type`.
- **Error codes** the client may receive (the string in `StateErrorEvent.code` / the stream error frame): `AMBIGUOUS_SESSION` (state: >1 live child + no `session_id`); `CANNOT_END_ROOT` (end/stop addressed to the root id); `SESSION_NOT_FOUND` (instruction stream: `session_id` is not an owned live session); `NO_ROOT_SESSION` (bio: root couldn't be resolved — defensive); `INVALID_ARGUMENT` (missing/empty `session_id`; or bio batch-hygiene — inconsistent/empty `sample_type`, empty batch); `RATE_LIMIT_EXCEEDED` (too many `activity:start` in the window); `INTERNAL_ERROR` (server-side failure). **Retired / never emitted anymore — do NOT branch on them:** `SESSION_MISMATCH`, `NO_SESSION`, `SESSION_PAUSED`.

## 11. Per-unit map with watch-points (mobile-facing changes)
- **Proto copy + regen** → overwrite `mind_mobile/proto/module_state.proto`, run `./scripts/gen_proto.sh`. Watch: don't run `build_runner` for this; don't hand-edit generated stubs. The Dart `ActivityType` enum now includes `ROOT`.
- **open root** → send `activity:start { activity_type: ROOT }`, read the response with `activity_type == ROOT`, store `root.id`. Watch: the discriminator is `activity_type`, not order or a connect push; the call is idempotent so a retry is safe.
- **activity:start (child)** → add `client_activity_id`; keep the returned child id. Watch: the token must survive a retry unchanged, else dedup can't fire → duplicate children.
- **end/stop/pause/resume** → send the target child's `session_id`. Watch: two live children + no `session_id` → `AMBIGUOUS_SESSION`; the root id → `CANNOT_END_ROOT` (never end the root).
- **bio stream** → send `session_id = root.id`. Watch: tag with the **root** id, not a child id; the server is tolerant but correctness reads expect bio under the root.
- **phase stream** → tag each sample with the producing child id; multiple concurrent children stream independently. Watch: tag each with the **right** child; an unowned/dead session id is rejected `SESSION_NOT_FOUND`.
- **lifecycle** → stop sending `activity:end` on navigation; only on explicit finish. Watch: behavior inversion — audit every navigation path that today closes the session.
- **Drift/DTO** → sync any cached realtime shape that changed. Watch: the client now models one **root** + N **children**; the root id arrives from the ROOT-start response, child ids from child starts; every state frame carries `activity_type`.
