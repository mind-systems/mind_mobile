# Root/child — session registry contract (skeleton + red routing tests)

**Date:** 2026-07-02
**Source:** conversation context; `roadmap-decompose-skeleton` pass over Phase 61

## Key Findings

- The session registry (note 14) is a **shared type surface** consumed by 5 downstream tasks — RootStateChannel (note 15, `rootId`), command addressing (note 16, `childOfType`), bio (note 17, `rootId`), start-race (note 19, `childOfType`/pending), reconnect (note 20, rebuild + `rootId`). Its shape must exist and compile before those tasks.
- Its routing **fails silently** (test-philosophy discriminator): a wrong `rootId`, a wrong `childOfType`, a mis-keyed upsert, or a missed terminal-removal produce wrong ids downstream (bio tagged wrong, wrong child ended, adopt picks the wrong session) with **no crash**. That is exactly the surface worth testing.
- This is the fused **contract** milestone: `ModuleSession` type + `SessionRegistry` surface (signatures, no routing bodies) **plus red tests** over the silent points — in one commit that compiles and has red tests. The impl milestone (note 14) turns them green.

## Details

### Skeleton (types + signatures — NO routing bodies)
- `ModuleSession` value type: `{ String id; ActivityType activityType; ModuleStateStatus status; bool isPaused }` (`ActivityType` incl. `root` from note 13; `ModuleStateStatus` from `ModuleState.dart:1`).
- `SessionRegistry` surface owned by / exposed from `ModuleStateChannel`:
  - `void upsert(ModuleSession)` / ingest from a `StateEvent` — keyed by `module_session_id`.
  - `void removeTerminal(String id)` — on `COMPLETED`/`INTERRUPTED`/`ABANDONED`.
  - `String? get rootId` — the sole entry with `activityType == root`.
  - `ModuleSession? childOfType(ActivityType)` — the sole non-root entry of that type.
  - stream(s) so adapters/bio observe `rootId` / child changes.
- Bodies throw `UnimplementedError` (or return null) so the file compiles; note 14 implements them.

### Red tests (silent-failure points, against the skeleton)
- upsert by `module_session_id` — a second frame for the same id updates in place, does not duplicate.
- `removeTerminal` — a child `COMPLETED`/`ABANDONED` removes only that child; a child terminal does **not** drop the root.
- `rootId` — returns the `ROOT` entry's id; null when no root; never a child id.
- `childOfType(breath)` — returns the sole breath child; null when none; does not return the root or a meditation child.
- route-by-`activity_type` — a `ROOT` frame and a `BREATH` frame land as two distinct entries; `rootId` and `childOfType` resolve each correctly.
- Use a **stateful** registry double / the real registry — not a pass-through stub (m36: a stateless double would let a missed-removal bug pass).

### Guards
- Skeleton only — no routing logic in this milestone; tests are RED until note 14.
- Do not test loud surfaces (proto decode, enum mapping — covered by note 13's compile).

### Verify
- Commit compiles; the routing tests are RED; downstream Phase 62-64 tasks can import `ModuleSession` / `SessionRegistry` signatures.
