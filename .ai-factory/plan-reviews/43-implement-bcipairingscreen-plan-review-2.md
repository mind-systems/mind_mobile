# Plan Review: 43-implement-bcipairingscreen (iteration 2)

**Plan:** `.ai-factory/plans/43-implement-bcipairingscreen.md`
**Spec reference:** `.ai-factory/notes/17-bci-pairing-screen.md`
**Prior review:** `.ai-factory/plan-reviews/43-implement-bcipairingscreen-plan-review-1.md`
**Risk Level:** 🟢 Low — plan v2 resolved every blocker raised by review 1 and most of the "should fix" items. Remaining items are minor under-specification and one small fact-check.

### Context Gates

- **ARCHITECTURE / RULES:** Scope correctly stays inside `packages/bci_module/` — concrete `BciPairingService`/`BciPairingCoordinator` are deferred to the next ROADMAP milestone (line 97), so the "stateless Service" rule does not apply yet. Nothing in the plan adds module-specific state to `App.dart`. ✅
- **ROADMAP:** Implements line 95 (the open BCI item). Guards 1–4 listed in ROADMAP map exactly onto Guards 1–4 in the plan. ✅
- **CLAUDE.md / project conventions:** Battery indicator switched from emoji to `Icons.battery_full`, satisfying the global "no emojis unless requested" rule. ✅

---

### Resolution of prior review

| Prior issue | Status in v2 |
|---|---|
| 1. `AppDimensions` does not exist | ✅ Fixed — plan now explicitly says "do not reference `AppDimensions`" and uses a literal `16`. |
| 2. Top bar `Row` cannot center title | ✅ Fixed — Task 7 rewritten to use `AppBar(leading:, title:, actions:, centerTitle: true)`. |
| 3. Battery emoji | ✅ Fixed — replaced with `Icons.battery_full`. |
| 4. Phantom "switch devices CTA" in Calibration section | ✅ Fixed — explicit note added: "this section does **not** invoke `showBciDisconnectDialog`"; Guard 2 rationale rewritten to refer to `BciPairingTopBar` sibling import. |
| 5. `just_audio` still in pubspec | ✅ Fixed — Task 1 explicitly removes it. |
| 6. `uses-material-design` | ✅ Fixed — Task 1 declares it. |
| 7. `_pendingSerial` fragility | ✅ Documented — three concrete limitations called out under Task 4 as acceptable for this milestone. |
| 8. Discovery progress simplification | ✅ Documented — Task 4 explicitly flags the "intentionally simpler than note 17" deviation. |
| 9. `ref.listen` placement | ✅ Fixed — Task 4 says "Inside `build()` (not `initState`)". |
| Minor: l10n regen claim | ✅ Fixed — Task 2 specifies running pub-get from `mind_mobile/` root. |
| Minor: spinner size | ✅ Fixed — explicit `SizedBox(18,18, CircularProgressIndicator(strokeWidth: 2))`. |
| Minor: section header reuse | ✅ Fixed — explicit "build a **local** `BciSectionHeader`, do **not** import from `breath_module`". |
| Minor: long "Previously paired" | ✅ Fixed — EN key shortened to "Paired". |

---

### Remaining Issues

#### WARN — Asset source path is ambiguous about the monorepo level
Task 1 says: *"copy the calibration completion sound from `neiry_kit/example/assets/sounds/done.wav` into `packages/bci_module/assets/calibration_complete.wav`"*.

`neiry_kit/` lives at the **monorepo root** (`/Users/max/projects/mind/neiry_kit/`), not inside `mind_mobile/`. Verified: `done.wav` exists at `/Users/max/projects/mind/neiry_kit/example/assets/sounds/done.wav` (35 324 bytes). From `mind_mobile/packages/bci_module/`, the relative source is `../../../../neiry_kit/example/assets/sounds/done.wav`. An implementer running the copy from `mind_mobile/` CWD would expect `neiry_kit/` to be a sibling and fail (`mind_mobile/neiry_kit/` does not exist).

**Fix:** Either spell out the path relative to the monorepo root, or include the literal `cp` command. Suggestion:
```bash
# from the monorepo root (parent of mind_mobile/):
mkdir -p mind_mobile/packages/bci_module/assets
cp neiry_kit/example/assets/sounds/done.wav \
   mind_mobile/packages/bci_module/assets/calibration_complete.wav
```

#### WARN — `unawaited` import not mentioned
Task 6 uses `unawaited(_loadCue())` inside `initState`. `unawaited` lives in `dart:async`, not in any of the imports the file would naturally pick up (`flutter/material.dart`, `flutter_riverpod`, `mind_audio`, `mind_l10n`). Implementer must `import 'dart:async';` — worth one line in the task to prevent a guaranteed analyzer error on first build.

#### WARN — Inter-section spacing assertion in Task 8 is not actually wired in the snippet
Task 8 says: *"Use `EdgeInsets.symmetric(vertical: 16)` for inter-section breathing room inside each section's own root padding."*

But none of Tasks 4/5/6 add an outer `Padding`/`EdgeInsets.symmetric(vertical: 16)` to their section roots, and the Task 8 `Column` snippet has no `SizedBox` between sections (only after the last one). With the `Divider(height: 1)` between sections, the visual result will be: header `top: 16` from `BciSectionHeader.fromLTRB(16, 16, 16, 8)` against a 1px divider against the previous section's bottom content (which has no bottom padding spec). Likely fine in practice, but the "16 vertical breathing room" guidance in Task 8 has no concrete landing site in the per-section tasks — it will be silently dropped by the implementer or interpreted inconsistently. Either remove the sentence or add an explicit `Padding(padding: EdgeInsets.only(bottom: 16), child: ...)` wrapper bullet to each section task.

#### Minor — Discovery list row construction is described, not committed
Task 4 enumerates `Leading` / `Title` / `Subtitle` / `Trailing` keys for each device row but does not say "use `ListTile`". Two reasonable implementations exist:
- `ListTile(leading: ..., title: ..., subtitle: ..., trailing: ..., onTap: ...)` — straightforward.
- Custom `Row`/`Column` — wider freedom, but won't match `ListTile`'s elevation/padding/Material tap feedback.

Spec note 17 leaves this open too. Recommend the plan explicitly say "use `ListTile`" so the visual result stays consistent with the rest of the app's settings/list rows.

#### Minor — Channels-placeholder branch loses the `Adjust headband` caption affordance only partially
Task 5 says: *"Always render four placeholder circles even when `state.channels.isEmpty` ... so the section reserves vertical space."* and then *"Caption below the row: `Text(l10n.bciPairingAdjustHeadband)`"*. The caption is rendered unconditionally in the snippet. When channels are empty (`state.stage == discovery`), the section is anyway dimmed by `IgnorePointer` + `AnimatedOpacity 0.38`, so the caption shows greyed-out — acceptable, but worth confirming that the placeholder + caption combo at 38 % opacity reads as "inactive" rather than "no signal yet". Cosmetic; non-blocking.

#### Minor — `BciCalibrationSection` stage-dots disappearance on completion is implicit
The dots row is rendered only when `state.calibration != null && !state.calibration!.isComplete`. On completion (`isComplete == true`) the dots vanish and the green check + "Calibration complete" row takes their place. This matches note 17 (which shows the checkmark as the completion state), but the plan doesn't say "the dots disappear when complete" — the reader infers it from the boolean condition. One-line acknowledgment would help avoid the implementer adding `stagesCompleted == 4 ? ... : ...` logic on top.

---

### Positive Notes

- Guards 1–4 are preserved and now have concise rationale paragraphs immediately after the relevant code snippet — easy for an implementer to apply without losing context.
- The "Known limitations" callout under Task 4 (`_pendingSerial`) is precisely the right level of honesty: it documents what won't work, attributes it to the missing `targetConnectingSerial` field, and commits to revisiting it in the Service milestone instead of papering over it now.
- `BciSectionHeader` is now a local widget with its own styling spec (`labelLarge` + `onSurfaceVariant`, `fromLTRB(16, 16, 16, 8)`), eliminating the cross-package coupling temptation that review 1 flagged.
- Task 7's switch to `AppBar` cuts ~30 lines of custom `Stack`/`NavigationToolbar` layout and is the idiomatic Flutter answer to "centered title with asymmetric leading/trailing."
- `AssetAudioCatalog` instantiation (`AssetAudioCatalog()`) inside `_loadCue()` is correct — it's a stateless adapter, not a singleton, and re-instantiating is cheap.
- Russian translations remain complete and idiomatic across all 11 keys.
- Commit plan groups changes by logical phase (wiring → widgets → assembly) and matches each commit to a coherent reviewable unit.

---

### Recommended Action

None of the remaining items block compilation or correctness. Address the **WARN** items (asset-source path clarity, `dart:async` import, inter-section spacing wording) for implementer ergonomics; the **Minor** items are stylistic and can be left to implementer judgment.

PLAN_REVIEW_PASS
