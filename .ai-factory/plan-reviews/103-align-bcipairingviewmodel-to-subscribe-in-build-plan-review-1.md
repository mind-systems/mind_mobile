# Plan Review: Align `BciPairingViewModel` to subscribe in `build()`

**Plan:** `103-align-bcipairingviewmodel-to-subscribe-in-build.md`
**Files Reviewed:** 5 (plan + 4 source files)
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** PASS. The change keeps the module boundary intact — the ViewModel still depends only on `IBciPairingService` and module DTOs, and lifecycle ownership moves to the canonical Riverpod `Notifier.build()` + `ref.onDispose` pattern. No domain types leak in.
- **Rules (`.ai-factory/RULES.md`):** PASS. The rule "Riverpod manages the subscription lifecycle via `ref.onDispose` in the ViewModel" is exactly what this plan enforces. `BciPairingService` remains stateless (no `StreamController`/`StreamSubscription`/`dispose()`) — untouched. No App.dart changes. No external wiring of the class.
- **Roadmap (`.ai-factory/ROADMAP.md`):** WARN (non-blocking). This is an internal refactor with no behavior change, so milestone linkage is optional; no action required.

## Verification of Plan Assumptions (all confirmed correct)

- **Canonical pattern claim is accurate.** `BciDataViewModel.build()` (lines 43–49) subscribes via `_eventsSubscription = service.events.listen(...)` before returning `BciDataState.initial()`. `BreathSessionListViewModel.build()` subscribes *and* fires a command (`_loadInitialPage()`) before returning initial state. The plan mirrors both faithfully — subscribe + `startScan()` (the command analogue) before `return BciPairingState.initial()`.
- **File paths are correct.** Both target files exist at the stated paths; the method shapes match the plan's description exactly (`initState()` with the `if (_eventsSubscription != null) return;` guard at VM lines 29–33; the post-frame `initState()` override at screen lines 26–32).
- **No "modify provider during build" hazard.** `observeChanges()` is built on `bciNotifier.stream` (a `BehaviorSubject`). Dart stream events — including a BehaviorSubject's replayed value — are delivered asynchronously (microtask), never synchronously inside `.listen()`. So `_onServiceEvent`'s `this.state = state` runs *after* `build()` returns. This is the same mechanism `BciDataViewModel` already relies on in production, so the refactor inherits proven-safe behavior.
- **No orphaned call sites.** A repo-wide search for `.initState()` on the pairing VM and for `bciPairingViewModelProvider` shows the only caller is `BciPairingScreen` (being removed in Task 2). The remaining `.initState()` test references belong to `BreathSession*` ViewModels, not this one. No tests exercise `BciPairingViewModel`, so "Testing: no" is acceptable.
- **Guard removal is safe.** With `build()` owning the single subscription and running once per provider lifetime (the VM has no `ref.watch` dependencies that would re-trigger `build()`), the `_eventsSubscription != null` guard is genuinely redundant. On any future invalidation, the prior `ref.onDispose` cancels + nulls before the new `build()` re-subscribes — correct.
- **Screen left as `ConsumerStatefulWidget`.** Acceptable per the plan's "minimal churn" note; converting to `ConsumerWidget` is optional and out of scope.

## Recommendations (non-blocking)

1. **Stale comment in `lib/BciModule/BciPairingService.dart` (lines 16–19).** The `NOTE` block explicitly states *"`BciPairingViewModel.initState()` calls `startScan()` on mount to trigger fresh emissions"*. After this refactor that method no longer exists, leaving the comment pointing at deleted code. Recommend the plan add a small step to update that sentence to reference `build()` (e.g. "`BciPairingViewModel.build()` calls `startScan()` on subscribe…"). Settings say "Docs: no", but this is an in-code comment that becomes factually wrong as a direct result of the change, so it belongs in the diff rather than a doc pass.

## Positive Notes

- Tightly scoped, two-task plan with a clean dependency order (Task 2 depends on Task 1).
- Correctly identifies and removes the post-frame-callback workaround, replacing it with the idiomatic lifecycle hook — a genuine simplification, not just a move.
- Explicitly enumerates what to leave unchanged (`_onServiceEvent`, gesture methods, field, constructor), reducing the chance of incidental edits.

The plan is solid and implementable as written; the single recommendation is an optional polish that prevents a stale comment.

PLAN_REVIEW_PASS
