# Root/child — update realtime docs to the root/child model

**Date:** 2026-07-02
**Source:** conversation context; `docs/realtime/live-session-tracking.md`, `docs/realtime/meditation-tracking.md`

## Key Findings

- The realtime docs describe the retired single-session model and a myth about server-side pause filtering — both wrong under root/child.
- Stale claims to fix:
  - "one active session per user; a second start is ignored" (`live-session-tracking.md:82`) — reversed: one root + N concurrent children.
  - "on pause the server blocks incoming phase samples" (`live-session-tracking.md:58`) — false; the server filters nothing during pause, the pause gap is produced by the client ceasing to emit phases (handoff §6). Pause sample policy is client-owned.
  - session ends on leaving the activity screen / `dispose()→stop` (`meditation-tracking.md:74`, `:11`) — reversed: end only on explicit finish (note 18).
- Last task in Phase 61 — after behavior is settled. Docs in Russian (repo convention).

## Details

### Change
- Rewrite `docs/realtime/live-session-tracking.md` to the root/child model: one root per user opened via `activity:start{ROOT}`; N flat children overlaid on the shared root bio timeline; bio tagged with `root.id`; phases tagged with the child id; lifecycle end only on explicit finish; correct the pause section (client-owned gap, no server filter).
- Update `docs/realtime/meditation-tracking.md`: remove the end-on-dispose description; concurrent children; meditation as one child among N.
- Reflect the new client structure: session registry (root + N children, routed by `activity_type`), `RootStateChannel`, reconnect via `root.id` header + reconcile-by-arrival, start-race retry keyed on `client_activity_id`.

### Guards
- Describe behavior, not code (no method/field dumps, no file trees) — global doc style.
- Russian; match neighboring docs' language and tone.
- Describe current state only — no "was changed / removed" history.

### Verify
- No remaining reference to "one active session per user" or server-side pause filtering.
- Docs match the shipped behavior of notes 13-20.
