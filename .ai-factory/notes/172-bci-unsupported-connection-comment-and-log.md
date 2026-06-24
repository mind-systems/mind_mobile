# Fix the unsupported-connection comment + restore the lost diagnostic (T8)

**Date:** 2026-06-24
**Source:** Phase 56, Tier 4 — nit.

## Key Findings

- `_onConnectionStatus`'s doc comment (`lib/Bci/NeiryBciProvider.dart:254-256`) claims `NeiryDeviceAdapter` "maps **and logs**" the unsupported-connection event before it reaches the handler.
- But `NeiryDeviceAdapter` maps `neiry.NeiryConnectionState.unsupportedConnection → BciLinkStatus.down` (`lib/Bci/Ports/NeiryDeviceAdapter.dart:69-70`) with **no `logPrint`** — the only logging in the adapter is the resistance-mismatch path (`:87`). So the comment is **wrong**, and the unsupported-vs-normal-disconnect diagnostic that previously existed is **gone** (an unsupported connection is now indistinguishable from a normal drop in logs).

## Details

**DECISION — pin one:**
- **Option A (recommended):** restore a distinct `logPrint` in `NeiryDeviceAdapter` for the `unsupportedConnection` case (before/at the `:69-70` map), so the unsupported-connection event is again triagable in logs; the provider comment then becomes true. Cheap triage value.
- **Option B:** leave behavior as-is and correct the provider comment (`:254-256`) to say the adapter maps (not logs) the unsupported case.

## Guards

- Mapping behavior unchanged (`unsupportedConnection` still → `BciLinkStatus.down`); this only restores a log line or fixes a comment.
- `logPrint` only.

## Verify

- Option A: an unsupported-connection event emits a distinct log line; the provider comment matches reality.
- Option B: the provider comment no longer claims logging.

**Done-when:** comment and code agree, per the chosen option.
