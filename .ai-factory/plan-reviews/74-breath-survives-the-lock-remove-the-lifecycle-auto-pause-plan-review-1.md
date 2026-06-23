## Plan Review Summary

**Plan:** 74 — Breath survives the lock (remove the lifecycle auto-pause)
**Files Reviewed:** 1 plan + target source + spec note 140 + coordinator internals
**Risk Level:** 🟢 Low

The plan is accurate, well-scoped, and faithful to its spec (`notes/140-breath-survives-background.md`). Every concrete claim was verified against the actual code.

### Verification Results

All line references in `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart` are correct as written:
- `:34` — `with TickerProviderStateMixin, WidgetsBindingObserver` ✅
- `:50` — `WidgetsBinding.instance.addObserver(this)` ✅
- `:122` — `WidgetsBinding.instance.removeObserver(this)` ✅
- `:126-138` — `didChangeAppLifecycleState` (the `@override` is at 126; body 127-138) ✅
- `didChangeAppLifecycleState` is confirmed the **only** lifecycle observer callback in the file, so removing the `WidgetsBindingObserver` mixin (Task 2) is safe. ✅
- `WidgetsBinding.instance.addPostFrameCallback` (`:81`, `:143`) does **not** depend on the observer registration and is correctly left intact. ✅
- Removal does not orphan any imports: `BreathSessionStatus`/`BreathSessionState` are still used in `_buildControlButton` and `listenManual`. ✅

### Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** WARN → none. This is a presentation-package-only change inside `packages/breath_module`. No domain/module boundary crossing, no DTO/Service/Notifier changes, no Drift schema or migration involved. Fully compliant.
- **Rules (`.ai-factory/RULES.md`):** No violations. The rules concern Module Service statelessness and App.dart hygiene — neither is touched.
- **Roadmap (`.ai-factory/ROADMAP.md`):** WARN → this is behavior-changing (`feat`-like) work with **no corresponding ROADMAP entry/phase**. The roadmap has no line for "breath survives backgrounding." Consider adding a roadmap task linking notes 138/139/140 so the milestone is tracked. Non-blocking.

### Critical Issues

None.

### Observations (non-blocking)

1. **Stricter than the spec on observer removal — and that's fine.** Note 140 says "Keep the `WidgetsBindingObserver` registration … unless `flutter analyze` flags it unused — then remove cleanly." Worth noting that `WidgetsBindingObserver` has *no* abstract members (all callbacks have empty default impls), so `flutter analyze` would **not** flag the unused mixin on its own. The plan instead removes it unconditionally in Task 2 as dead-code cleanup. This is the cleaner outcome and won't break compilation — just be aware the "resolve analyze warnings" step in Task 2 is mostly a safety net; the removal is justified by intent, not by an analyzer warning.

2. **`BreathSoundCoordinator.suspend()` / `resume()` become dead public methods.** Confirmed: after the call sites are deleted, `suspend()` (`:136`) and `resume()` (`:141`) are no longer invoked. `_isSuspended` is still *read* at `:198`, so there is **no** `unused_field` warning, and the methods are public so there is **no** `unused_element` warning — `flutter analyze` stays clean. The plan's guard "do not touch `BreathSoundCoordinator` internals" is therefore safe to honor. (Optional future cleanup: prune the now-unreachable `suspend`/`resume`/`_isSuspended` — but explicitly out of scope here and correctly left alone.)

3. **Tooling note:** project memory records Flutter at `/usr/local/bin/flutter`. The implementer should run `/usr/local/bin/flutter analyze` (per Task 2) rather than a bare `flutter`.

4. **Dependency correctly flagged.** The plan and note state the feature only fully works once notes 138 (iOS background audio) and 139 (Android FGS) are in place; without them the engine still freezes on suspension (acceptable degradation). This deletion is the right unit of work regardless.

5. **Commit message** ("Remove breath session lifecycle auto-pause so it survives backgrounding") complies with global commit conventions — imperative, sentence case, no type prefix, no period.

### Positive Notes

- Scope is tight and correct: only `BreathSessionScreen` is touched. The sibling `BreathSessionConstructorScreen` also mixes in `WidgetsBindingObserver` (`:24`) but is correctly left untouched.
- Task dependency ordering (Task 2 depends on Task 1) is right — wiring removal must follow body removal.
- Guards explicitly protect the user-initiated pause button, the state machine, tick sources, and coordinator internals.

PLAN_REVIEW_PASS
