# Plan Review: Propagate classifier streams through `BciDeviceManager` + `BciNotifier`

**Plan file:** `.ai-factory/plans/55-propagate-classifier-streams-through-bcidevicemanager-bcinotifier.md`
**Risk Level:** 🟢 Low

## Context Gates

- **ARCHITECTURE.md:** PASS. The plan touches only the domain layer (`lib/Bci/`) and the existing `BciPairingService` reducer. It does not introduce DTOs into the notifier, does not pull module types upstream, and respects the layered direction (provider → manager → notifier → service). No boundary violations.
- **RULES.md:** PASS. The three rules in `.ai-factory/RULES.md` cover Module Services, `App.dart` hygiene, and constructor-injected dependencies — none of which are affected. `BciNotifier` already receives its `BciDeviceManager` via constructor; the new subscriptions stay inside it. No module Service is being added or mutated.
- **ROADMAP.md:** PASS. The plan maps 1:1 onto the third milestone of Phase 19 (`.ai-factory/ROADMAP.md:121`), and the explicit deviation from the milestone wording ("No changes to `BciPairingService`") is acknowledged in the Context section with a sound technical justification.

## Codebase Verification

Verified each task against the current code:

- `lib/Bci/Models/BciNotifierEvent.dart` — confirmed it is a `sealed class` with six current `final class` variants and no `default:` consumer. The "place after `BciBatteryUpdated`, before `BciError`" instruction matches the file layout (lines 42–53).
- `lib/Bci/BciDeviceManager.dart` — confirmed the "Public getters" section (lines 68–78) already passes `signalQualityStream`, `batteryStream`, and `calibrationStream` through to `_provider` with no controller layer. Imports for `BciNfbData`/`BciCardioData`/`BciEmotionsData` are not yet present in this file, so Task 2's "add the corresponding imports" instruction is needed and correct.
- `lib/Bci/BciNotifier.dart` — confirmed five `StreamSubscription<dynamic>?` fields and the `_batterySub` block at lines 61–67 that the plan tells Task 3 to mirror. Task 3's choice to declare the new subs as `StreamSubscription<dynamic>?` is consistent with the existing five. The plan's claim that no data-model imports are required is correct: the parameter types are inferred from the manager's stream signatures, and the event constructors don't name the data types at the call site.
- `lib/BciModule/BciPairingService.dart` — confirmed `_reduce` (lines 46–84) switches exhaustively on `BciNotifierEvent` with no `default:`. Without Task 4, Task 1 would produce a non-exhaustive-switch compile error. The plan's call to add three no-op `case` labels falling through to a single `return acc;` is the minimum correct fix.
- `lib/Bci/IBciDeviceProvider.dart` and `lib/Bci/NeiryBciProvider.dart` — confirmed `nfbStream` / `cardioStream` / `emotionsStream` already exist on both interface and adapter (Phase 19 milestones 1–2 are `[x]` in the roadmap), so this milestone has nothing upstream to wait on.
- Grep across `lib/` for `switch.*BciNotifierEvent` and `case BciStateChanged` confirms `BciPairingService._reduce` is the only consumer that pattern-matches on the sealed type. No other reducer will silently break from the new variants.

## Critical Issues

None.

## Suggestions / Nits

- **(Optional) Stream subscription generic types.** Task 3 reuses the existing `StreamSubscription<dynamic>?` style for the three new fields. This is consistent with the file but unnecessarily loose — the manager getters are typed `Stream<BciNfbData>` etc., so `StreamSubscription<BciNfbData>?` would be just as cheap and would document intent. Not a blocker, and matching the prevailing style is also defensible; flagging only because it's the one place in the plan where a small typing tightening could land "for free."
- **(Optional) `BciPairingService._reduce` fall-through.** The Dart switch-statement syntax for fall-through requires the cases to share a body with no statements between them — `case BciNfbUpdated(): case BciCardioUpdated(): case BciEmotionsUpdated(): return acc;` is correct exactly as written in the plan. Just calling it out for the implementer: do not split into three separate `return acc;` blocks (more lines, same effect), and do not insert blank lines or comments between the case labels — that breaks fall-through under Dart 3 pattern-switch rules.
- **(Optional) Doc-comment wording for new variants.** The plan says "Add a short doc comment above each in the same `///` single-line style used by neighbors." For consistency, suggest something like `/// Emitted when the NFB classifier reports new band amplitudes.` and analogues — mirroring the present-tense, single-stream-source phrasing already used for `BciSignalQualityUpdated` and `BciBatteryUpdated`. Purely stylistic.

## Positive Notes

- The Context section explicitly resolves the contradiction between the roadmap text ("No changes to `BciPairingService`") and the compile-time reality of an exhaustive sealed switch. This is exactly the kind of detail that usually trips up the implementer if left implicit.
- Each task lists its target file(s) and the exact insertion point/style to mirror — no ambiguity about which neighbor pattern to copy.
- Dependencies between tasks are correctly declared (`Task 2` and `Task 4` depend on `Task 1`; `Task 3` depends on `Task 2`). The compile chain works task-by-task: after Task 1 the project compiles only once Task 4 lands (or both can be considered a single atomic unit, but the ordering as written is fine).
- The plan correctly notes that the new subscriptions need `onError` handling identical to the `_batterySub` pattern, and that disposal must cancel them in declaration order before `_subject.close()` — both are real footguns that often get missed in pass-through refactors.
- The plan correctly avoids importing data-model types in `BciNotifier.dart`. Adding unnecessary imports there would have been a minor hygiene regression.

PLAN_REVIEW_PASS
