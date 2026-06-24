# Broaden the fire-and-forget teardown `.catchError` to log-and-swallow non-QueueClosed errors (T2)

**Date:** 2026-06-24
**Source:** Phase 56, Tier 2 — low-severity hardening (flagged by both reviews). Carries a test-contract change.

## Key Findings

- `_teardownAfterUnexpectedDrop`'s enqueued command (`lib/Bci/NeiryBciProvider.dart:412`) only swallows `QueueClosedException` via `.catchError(test: (e) => e is QueueClosedException)` (`:448-457`). **Any other throw escapes as an unhandled zone error with no `logPrint`.**
- Two confirmed trigger sources:
  1. A thrown `sub.cancel()` in the cancel chain (`:420-429`) — these awaits are not individually guarded; on a throw the `finally` (`:445`) still reaches the recreate (L1 holds), but the cancel's `StateError` propagates out of the command.
  2. A thrown `_locatorFactory()` during recreate inside `_resetLocatorSession` (`:372`, reached from the `finally` at `:446`).

## Details

- Broaden the `.catchError` so it also **logs and swallows** non-`QueueClosedException` errors (the per-step bodies already `logPrint`; this is the top-level safety net for the unguarded cancel chain + recreate). Keep the existing `QueueClosedException`-specific comment/handling (that path is the documented dispose-races-drop case).

## ⚠️ Test-contract change (call out — not a green→green violation)

`test/Bci/neiry_bci_provider_full_teardown_test.dart` currently **asserts** that a thrown connection-sub cancel "surfaces as an unhandled async error". This task **deliberately** changes that behavior to logged-and-swallowed, so that assertion **must be updated** to expect the new behavior. This is an intentional contract change, not a regression of the B2 suite — document it in the commit so it is not mistaken for a green→green break.

## Guards

- Do not touch the queue's CONSTRAINTs or the `QueueClosedException` dispose-races-drop handling (the accepted leak documented at `:448-457`).
- `logPrint` only (project logger facade).

## Verify

- A thrown `sub.cancel()` or a thrown `_locatorFactory()` during an unexpected-drop teardown is logged and swallowed — no unhandled zone error.
- The updated B2 assertion passes; the rest of B1/B2 stays green.

**Done-when:** the drop-teardown command emits no unhandled async errors for any in-step throw, the relevant `full_teardown_test` assertion is updated to expect logged-and-swallowed, and suites pass.
