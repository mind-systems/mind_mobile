# Plan Review: Stream biometric samples through pause

**Plan:** `.ai-factory/plans/58-stream-biometric-samples-through-pause.md`
**Target file:** `lib/Biometrics/BiometricStreamClient.dart`
**Risk Level:** 🟢 Low

## Verification Summary

Verified the plan against the actual codebase:

- **Line references are accurate.** `sendBatch` guard is at line 95 (`if (_currentSessionId == null || _isPaused) return;`), `bool _isPaused = false;` at line 31, the `_onLifecycleEvent` switch at lines 74–90 with the Paused/Unpaused cases at 80–83 and the started/ended assignments exactly as described. Class doc comment "or the session is paused" is at line 18.
- **Scope guards are sound.** Replay ring, readiness gate (`_isReady`/`_readyTimer`), 2 s reopen cooldown (`_lastOpenAttempt` in `_ensureSinkOpen`), and connection-state teardown are all independent of `_isPaused` — leaving them untouched is correct.
- **`_isPaused` has no external readers.** It is a private field used only inside this class, so deleting it cannot break any other file.
- **Event types are correctly preserved.** `ModuleSessionPaused` / `ModuleSessionUnpaused` are still emitted by `lib/Core/Grpc/ModuleStateChannel.dart`, so the plan is right to remove only this client's handling and keep the types in `ModuleStateEvent.dart`.
- **No test breakage.** `test/Biometrics/biometric_batcher_test.dart` exercises a `_FakeBiometricStreamClient implements BiometricStreamClient` and does not reference `_isPaused`, so the `Testing: no` setting is safe here.
- **Roadmap linkage confirmed.** Maps to ROADMAP.md line 181 ("Stream biometric samples through pause"), which itself depends on the `mind_api` Phase 39 / note 49 pause-guard removal — consistent with the plan's "inert until server deploy" framing.

## Context Gates

- **Architecture** (`.ai-factory/ARCHITECTURE.md`): present. No boundary violations — change is confined to a single transport client in `lib/Biometrics/`, no module/domain boundary crossed. PASS.
- **Rules** (`.ai-factory/RULES.md`): present. The three rules concern stateless Module Services, App.dart purity, and constructor injection — none are touched by this change. PASS.
- **Roadmap** (`.ai-factory/ROADMAP.md`): milestone linkage present and explicit. PASS.

## Findings

### Recommendation (non-blocking): make the sealed-switch exhaustiveness fix explicit in Task 1

`ModuleStateEvent` is a **sealed class** (`lib/Core/Grpc/ModuleStateEvent.dart:1`). The `switch (event)` in `_onLifecycleEvent` is an exhaustive switch *statement* over that sealed type. Task 1 instructs to "delete the entire `ModuleSessionPaused()` case and the entire `ModuleSessionUnpaused()` case." If an implementer does exactly that with no replacement, the switch is no longer exhaustive and `flutter analyze` reports `non_exhaustive_switch_statement` — the two variants are still members of the sealed hierarchy even though their handling is gone.

Task 2 *does* anticipate this ("the switch ... must still handle every remaining variant exhaustively, or use a default if the enum/sealed type requires it"), so the plan is self-correcting and will not ship broken. But the resolution is left vague across a task boundary. Recommend making Task 1 concrete by retaining a no-op branch rather than deleting the cases outright, e.g.:

```dart
case ModuleSessionPaused() || ModuleSessionUnpaused():
  break; // streaming continues through pause; no gating state to update
```

This keeps the switch exhaustive without reintroducing `_isPaused`, makes the intent self-documenting, and removes the dependency on Task 2 to discover-and-fix an analyzer error. (A wildcard `default:` would also satisfy the analyzer but is weaker — it would silently swallow any future variant, defeating the sealed-type exhaustiveness check the codebase relies on. Prefer the explicit combined case.)

### Positive Notes

- Correctly identifies that this is an inert change until the server-side guard (`module-biometric-stream.grpc.controller.ts:132-139`) is removed, and explicitly scopes that server work out — matching the documented server→mobile deploy order.
- Precise about what *not* to touch (replay ring, readiness gate, cooldown, teardown), which are the parts most at risk of accidental collateral edits.
- Includes an analyzer-cleanliness verification step (Task 2) for the unused-field / unhandled-case fallout of the deletion.
- Single-commit, minimal-footprint change that matches the milestone scope exactly.

## Conclusion

The plan is accurate, well-scoped, and safe. The only item is a clarity recommendation to fold the sealed-switch exhaustiveness fix directly into Task 1; the plan already covers it via Task 2 and will not produce broken code.

PLAN_REVIEW_PASS
