## Code Review Summary

**Files Reviewed:** 5 (plan + 2 adapters + 2 test suites, cross-checked against spec note 18, ROADMAP line 61, RULES.md)
**Risk Level:** 🟢 Low

Plan reviewed: `19-invert-lifecycle-end-only-on-explicit-finish-drop-stop-on-dispose.md`
Governing spec: `.ai-factory/notes/18-rootchild-lifecycle-inversion.md`
Roadmap milestone: `ROADMAP.md:61` — "Invert lifecycle: end only on explicit finish (drop stop-on-dispose)".

### Context Gates

- **Architecture** (`ARCHITECTURE.md`): OK. The change is confined to the two module adapters (`lib/BreathModule/Core/`, `lib/MeditationModule/Core/`) that bridge domain lifecycle → `ModuleStateChannel`. No layer boundaries crossed, no new dependencies. Aligns with the "server adapter is not re-architected" stance established in Phase 58.
- **Rules** (`RULES.md`): OK. The three rules concern stateless module Services, App.dart purity, and constructor injection — none are touched. The adapters retain their constructor-injected `ModuleStateChannel` and self-managed subscriptions.
- **Roadmap** (`ROADMAP.md:61`): OK. Plan maps 1:1 to the milestone and its `Spec:` note (18). Spec intent ("end only on explicit finish; a child stays live while the user navigates away") is faithfully realized.
- **Spec-tree dependency** (note 14 registry): **Satisfied.** Spec 18 notes a dependency on the registry "so leftover live children are tracked." `lib/Core/Grpc/SessionRegistry.dart` and `RootStateChannel.dart` are present, so children left live on navigation are tracked rather than orphaned. Premise holds.

### Verification of plan claims against the codebase

All line references in the plan are **exact** as of the current tree:

- `BreathModuleStateChannel.dart:168-176` is `dispose()`; the removable block is `:169-172` (`if (_started && !_ended) { logPrint(...); _channel.stop(...); }`). The three `.cancel()` calls at `:173-175` are correctly preserved.
- The explicit-finish `end` path (`→completed`, `:117-123`) is correctly identified as out-of-scope-to-touch and remains the sole breath terminator after the change.
- `MeditationModuleStateChannel.dart:73-78` is `dispose()`; the removable line is `:74`. The `active → idle` `end` path (`:62-69`) is correctly preserved.
- Navigation-path audit corroborated independently: a `.stop(` sweep over `lib/` surfaces only the two teardown calls (`BreathModuleStateChannel.dart:171`, `MeditationModuleStateChannel.dart:74`); all other hits are unrelated (`Stopwatch.stop`, `AudioPlayer.stop`, `ForegroundKeepAlive.stop`, `Block.stop`). No coordinator, screen pop, or route change sends `end`/`stop` independently — the audit conclusion is accurate.
- Breath tests: the `dispose() / stop()` group is at `:641`; the two assertions to flip are at `:667-677` (`breath -> dispose`, currently `stopCount, 1`) and `:679-691` (`breath -> pause -> dispose`, currently `stopCount, 1`). The three cases already asserting `0` (before-emission `:642`, non-ready `:652`, after-complete `:693`) are correctly left unchanged.
- Meditation tests: the `dispose` group is at `:339`; the case to flip is `:350-360` (`stop exactly once when active`, currently `stopCount, 1`). The before-emission (`:340`) and active-to-idle (`:362`) cases already assert `0`; the subscription-teardown cases (`:376`, `:391`) are correctly left as-is.

Task dependencies (Task 3 → Task 1, Task 4 → Task 2) are correctly ordered, and the "migrate existing assertions only, no new coverage" scope matches the plan's `Testing: no` setting.

### Critical Issues

None. No missing steps, no wrong codebase assumptions, no incorrect paths/API usage, no missing migrations (none applicable — client-only lifecycle trigger change).

### Minor Notes (non-blocking, informational)

- **`ModuleStateChannel.stop()` becomes unreferenced in the app.** After both call sites are removed, `void stop({String? sessionId})` (`lib/Core/Grpc/ModuleStateChannel.dart:285`) has no remaining production caller. This is expected and harmless: `stop` is a legitimate public method of the channel's wire API, the spec does not ask to remove it, and being public it triggers no unused-element lint. Test fakes still exercise `stopCount`. No action required; flagging only so the implementer does not add a redundant "remove dead method" step outside scope.
- **Server-side leak of never-finished children** (start breath, walk away, never finish) is the deliberate consequence of this inversion and is handled at the system level by the registry + reconnect/eviction milestones (ROADMAP:68/78), not here. The plan correctly scopes FGS/biometrics gating out. No change needed.

### Positive Notes

- Line-accurate recon folded into the plan (the navigation audit) rather than deferred — every claim was independently reproducible.
- Correctly preserves the two explicit-finish `end` transitions and the subscription-cancellation teardown, changing only the implicit `stop` trigger — matching the spec's "only the trigger inverts" guard.
- Test migration is surgical: only the two assertions whose behavior actually inverts are flipped, with descriptions updated; unrelated golden-master cases and the subscription-bookkeeping groups are explicitly left untouched.
- Scope discipline: FGS/biometrics gating, the stopwatch, instruction markers, `reset()`, and re-arm bookkeeping are all explicitly called out as do-not-touch, consistent with the spec guards.

PLAN_REVIEW_PASS
