# Plan Review: T8 · Fix the unsupported-connection comment + restore the diagnostic

**Plan:** `97-t8-fix-the-unsupported-connection-comment-restore-the-diagnostic-decision-log-vs-comment.md`
**Risk Level:** 🟢 Low

## Summary

The plan restores a lost diagnostic log line for the `unsupportedConnection`
branch of `NeiryDeviceAdapter.connectionStateStream`, then corrects two stale
doc comments (adapter + provider) so code and comments agree. It implements
**Option A** from decision note `172-bci-unsupported-connection-comment-and-log.md`.
Scope is minimal, behavior-preserving, and the chosen approach matches the
recorded ruling.

## Context Gates

- **Architecture** — `.ai-factory/ARCHITECTURE.md` present. No boundary impact:
  the change stays entirely inside the adapter Port (`lib/Bci/Ports/`) and the
  provider, with `neiry_kit` confined to the adapter as the existing comment
  documents. No new cross-layer dependency. PASS.
- **Rules** — `.ai-factory/RULES.md` present. The plan uses `logPrint` (the
  mandated logger facade per project CLAUDE.md), not `print`/`debugPrint`.
  `logPrint` is already imported in the file (`:5`, used at `:90`). PASS.
- **Roadmap** — `.ai-factory/ROADMAP.md` present and references this T8 item.
  Linkage is established. PASS (WARN-none).

## Accuracy Check (verified against current code)

All line references in the plan are correct as of the current file state:

- `connectionStateStream` map is at `:64-75`; the `unsupportedConnection` branch
  is at `:72-73` and currently returns `BciLinkStatus.down` with no log. ✓
- Adapter doc comment to correct is at `:56-63`. ✓
- `logPrint` already imported/used at `:90`, so Task 1 needs no new import. ✓
- Provider `_onConnectionStatus` doc comment is at `:255-259` and currently
  claims the adapter "maps **and logs** the latter" — which is false today and
  becomes true after Task 1. ✓

A repo-wide grep for `unsupportedConnection` / `maps and logs` /
`unsupported-connection` surfaces only the two comment sites and the one code
branch the plan already targets — no other stale reference is left behind.

## Observations (non-blocking)

- **Single subscriber, no double-logging.** `connectionStateStream` is a
  `late final` mapped stream subscribed exactly once
  (`NeiryBciProvider.dart:199`). The `logPrint` placed inside `.map` therefore
  fires once per emitted event, not per-listener — so the restored diagnostic
  won't multiply. Good fit for the chosen location.
- **Silent `disconnected` branch rationale is sound.** The plan correctly keeps
  the `disconnected` branch unlogged to avoid firing during the post-`disconnect()`
  noise window, while the idempotency guard that actually suppresses redundant
  handling lives in the provider (`:265-267`). The distinction the plan draws —
  log the device-rejection (`unsupportedConnection`) case but not the
  routine-drop case — is the right triage boundary.
- **Comment wording (Task 2).** Note that after Task 1 the existing adapter
  comment sentence "so no logging is done here" becomes outright false, not just
  imprecise — Task 2 must replace that clause, not merely append to it. The plan
  already calls for stating that `unsupportedConnection` *is* logged and
  `disconnected` is intentionally *not*; just ensure the contradictory existing
  sentence (`:60-63`) is rewritten rather than left in place.

## Critical Issues

None.

## Positive Notes

- Plan is anchored to a recorded decision note and picks the recommended option.
- Behavior is explicitly preserved (`unsupportedConnection` still →
  `BciLinkStatus.down`); only a log line and two comments change.
- Greppable, class-tagged log message convention matches the existing
  `NeiryDeviceAdapter:` log at `:90`.
- All three tasks together leave code and both comments mutually consistent.

PLAN_REVIEW_PASS
