# Plan Review: Remove close button from BciPairingScreen + delete now-empty BciPairingCoordinator

**Plan:** `.ai-factory/plans/80-remove-close-button-from-bcipairingscreen-delete-now-empty-bcipairingcoordinator.md`
**Files Reviewed:** 7 (plan, BciPairingScreen.dart, BciPairingViewModel.dart, IBciPairingCoordinator.dart, bci_module.dart barrel, BciPairingCoordinator.dart, BciModule.dart) plus router.dart, BciDataHeader.dart, RULES.md, ARCHITECTURE.md.
**Risk Level:** 🟢 Low

## Context Gates

- **ARCHITECTURE.md:** ✅ The deletion respects the layered model. The `IBciPairingCoordinator` interface only had `close()`, which was a pure navigation side-effect — removing it does not collapse any domain leakage because no domain types crossed through it. The remaining `IBciPairingService` continues to keep the boundary clean.
- **RULES.md:** ✅ Rule 3 ("All dependencies must be injected via constructor") still holds — removing the `coordinator` field simply removes one injected dependency. Rules 1 and 2 are not touched.
- **ROADMAP.md:** WARN — No explicit milestone entry for this cleanup (item 80 is not in ROADMAP). For a small UI tidy this is acceptable, but if the project enforces roadmap linkage you may want to record it alongside the prior "remove AppBar" entry (Phase 9-ish, plan 52).

## Cross-checked codebase facts

| Plan claim | Verified? |
|---|---|
| `IconButton(Icons.close, onPressed: vm.onClose)` at `BciPairingScreen.dart:68–71` | ✅ exact match |
| `Spacer()` at line 72 separates close button from battery | ✅ exact match |
| `final IBciPairingCoordinator coordinator;` at `BciPairingViewModel.dart:16` | ✅ exact match |
| `required this.coordinator,` in constructor (line 22) | ✅ exact match |
| `import 'IBciPairingCoordinator.dart';` at line 3 | ✅ exact match |
| `void onClose() => coordinator.close();` at line 59 | ✅ exact match |
| `IBciPairingCoordinator` is single-method (`close()`) | ✅ confirmed in `IBciPairingCoordinator.dart` |
| Barrel export at `bci_module.dart:9` | ✅ exact match |
| `BciPairingCoordinator(this.context)` only does `context.pop()` | ✅ confirmed |
| `BciModule.buildPairing` wires both `service` and `coordinator` (lines 13, 17) | ✅ exact match; import on line 5 |
| No other references to `IBciPairingCoordinator`, `BciPairingCoordinator`, or `onClose` outside the listed files | ✅ grep confirms (remaining matches are in docs/notes/roadmap/plan-reviews, not in compiled code) |
| Back-navigation exit remains possible after the X is removed | ✅ Route is a top-level `GoRoute` pushed from `BciDataCoordinator.openPairing()` via `context.push(...)` (`router.dart:54–57`, `BciDataCoordinator.dart:13`), so iOS swipe-back and Android system back work — user is not stranded |

## Critical Issues

None.

## Minor Issues / Suggestions

1. **Sibling-layout reference is slightly imprecise** (Task 1, non-blocking).
   The plan says "mirror the sibling `BciDataHeader` layout: battery indicator on the left, `Spacer()` in the middle, red disconnect `TextButton` on the right". `BciDataHeader` actually has `[battery, Spacer, channelRow (impedance dots)]` — there is no disconnect TextButton there. The structural mirror (`[batteryLeading, Spacer, trailingItem]`) is what is being copied; the trailing item differs (disconnect button vs. impedance dots). The instruction itself (`[batteryRow, Spacer(), disconnectTextButton]`) is unambiguous and produces the right tree, so this is documentation/wording polish rather than a functional gap.

2. **Spacer relocation, not deletion** (Task 1, wording).
   Current layout: `[IconButton, Spacer, Opacity(battery), TextButton]`. After deleting the `IconButton` and the existing `Spacer`, you get `[Opacity(battery), TextButton]` — there is no Spacer between battery and the disconnect button yet. The plan reads "Remove the now-unused `Spacer()` … (only one `Spacer()` remains, between battery and disconnect)", which is correct only if the implementer adds a fresh `Spacer()` between `Opacity(...)` and the `TextButton`. Re-phrasing it as "move the existing Spacer from before the battery to after it" would make the intent unambiguous and prevent an accidental `[battery, TextButton]` layout where the disconnect button hugs the battery.

3. **Residual `SizedBox(width: 8)` inside the battery `Row`** (Task 1, cosmetic).
   The inner battery `Row` ends with `const SizedBox(width: 8)` (line 83) that was originally trailing whitespace before the disconnect button. Once a `Spacer` is added between battery and disconnect, this `SizedBox(8)` becomes a small extra inset — visually harmless but redundant. `BciDataHeader` does not have it. Consider removing for parity with the sibling header.

4. **Optional barrel-export hygiene** (Task 4).
   The header comment block above the export is `// Service + Coordinator interfaces`. After deleting `IBciPairingCoordinator` only `IBciDataCoordinator` remains under that header, which is still accurate. No action required, just flagging that the section comment continues to make sense.

5. **No mention of `flutter analyze`** (process).
   The plan disables testing and logging. Since this change deletes a public symbol (`IBciPairingCoordinator`) exported from the package barrel and removes a constructor parameter, running `flutter analyze` (or `dart analyze`) at the end is the cheapest safety net to catch any forgotten consumer. Strongly recommended as a Phase-3 closing step even though it is implicit.

## Positive Notes

- Task ordering is correct: UI removal → ViewModel cleanup → interface deletion → barrel export → concrete deletion → wiring removal. The dependency annotations on each task match the actual compile-time chain, so the build can be validated at each step.
- Scope is correct — `BciDataCoordinator` (which lives next door and *does* have meaningful navigation duties) is explicitly left alone.
- File paths and line numbers all line up with the live source, including the import paths.
- The plan correctly identifies that `vm` must stay in `_BciPairingHeader.build()` because `vm.onDisconnect()` is still referenced inside the dialog callback (line 92). This is the kind of detail that often gets missed.
- No migrations, secrets, async ordering, or security surface is touched — pure cleanup.

PLAN_REVIEW_PASS
