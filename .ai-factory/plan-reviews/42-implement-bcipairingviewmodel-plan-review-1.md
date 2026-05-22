# Plan Review: 42 — Implement `BciPairingViewModel`

**Plan file:** `.ai-factory/plans/42-implement-bcipairingviewmodel.md`
**Risk level:** 🟢 Low

## Context Gates

- **ARCHITECTURE.md:** No `BciPairing`/`bci_module` content yet — package is mid-rollout (milestones 32–41 already landed). No boundary conflict. (no WARN)
- **RULES.md:**
  - Rule "Module Services must be stateless — Riverpod manages subscription lifecycle via `ref.onDispose` in the ViewModel" — plan complies: the `StreamSubscription` lives in the ViewModel and is cancelled via `ref.onDispose(...)`.
  - Rule "All dependencies must be injected via constructor" — plan complies: `service` and `coordinator` are required named ctor params; `initState()` is invoked from outside but takes no dependencies.
  - No violations.
- **ROADMAP.md:** Milestone 93 is the `[ ]` item this plan targets. The plan correctly flags and resolves the two milestone/codebase mismatches (`service.events` → `observeChanges()`, `StateNotifier` → `Notifier`). Roadmap alignment is preserved.

## Codebase Cross-Check

Verified against the actual files:

- `packages/bci_module/lib/src/BciPairing/IBciPairingService.dart` — confirms `observeChanges()` (method, not getter), sealed `BciPairingServiceEvent { BciPairingStateUpdated(BciPairingState) }`, and command signatures (`startScan()`, `connectDevice(serial)`, `startCalibration()`, `disconnect()`) — all match the plan exactly.
- `packages/bci_module/lib/src/BciPairing/IBciPairingCoordinator.dart` — exposes only `close()`. Plan's `onClose()` correctly forwards to `coordinator.close()`.
- `packages/bci_module/lib/src/BciPairing/Models/BciPairingState.dart` — `BciPairingState.initial()` exists; plan correctly seeds `build()` with it.
- `packages/bci_module/lib/bci_module.dart` — `// ViewModels` comment header is present and empty on line 2, exactly where the plan places the new export.
- `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart` — confirms the reference pattern: `NotifierProvider` with `UnimplementedError`, `Notifier<TState>`, `ref.onDispose` inside `build()`, `initState()` as a separate entry point. Plan mirrors all four faithfully.

No incorrect file paths, no wrong type names, no API drift.

## Findings

### Critical Issues
*(none)*

### Suggestions (non-blocking)

1. **`initState()` signature divergence — worth flagging in passing.** Plan declares `void initState()` (synchronous) while the mirrored `BreathViewModel.initState()` returns `Future<void>`. This is **correct** for BCI (no async work — `startScan()` is fire-and-forget) but the plan says "mirrors `BreathViewModel.initState()`". A reader following the analogy too literally might wrap the body in `async`/`await`. Not a defect — just an opportunity to add a half-sentence: "synchronous because all forwarded calls are fire-and-forget; no `await` needed."

2. **Variable shadowing in the sealed `switch`.** The snippet `case BciPairingStateUpdated(:final state): this.state = state;` works (Notifier's `state` setter is reached via `this.`) but the implicit shadow of the inherited `state` getter is slightly opaque. Aliasing — `:final state as next` then `this.state = next;` — would read cleaner. Stylistic only.

3. **Subscription is established but never exercised this milestone.** Plan correctly defers `initState()` invocation to the next milestone (`BciModule.buildPairing`). Worth noting in the plan body that the implemented ViewModel will be inert (no subscription, no scan) until milestone 99 wires it — so reviewers of the resulting patch don't expect a runtime change.

### Positive Notes

- Plan opens by reconciling the milestone description against actual interfaces — explicit, justified, traceable. Excellent.
- Subscribe-before-`startScan()` ordering is called out — protects against missing the first event emission.
- Double-subscription guard (`if (_eventsSubscription != null) return;`) covers the case where the assembler accidentally calls `initState()` twice.
- Exhaustive sealed `switch` (no `default`) — adding a new `BciPairingServiceEvent` variant later becomes a compile error rather than a silent ignore. Future-proof.
- Verification command uses `/usr/local/bin/flutter analyze packages/bci_module` (full path per user preference; scoped to the package). Correct on both axes.
- Imports list explicitly excludes anything from `lib/Bci/` — the module boundary is honored.
- Barrel export placement (under `// ViewModels`) matches existing file layout exactly.

## Verdict

The plan is internally consistent, references real files and real APIs, complies with `RULES.md`, mirrors the established `BreathViewModel` pattern correctly, and correctly translates the slightly-stale roadmap text into accurate calls against the current `IBciPairingService`/`IBciPairingCoordinator` interfaces. No blocking issues.

PLAN_REVIEW_PASS
