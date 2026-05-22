# Plan Review: Remove AppBar from BciPairingScreen

**Plan:** `.ai-factory/plans/52-remove-appbar-from-bcipairingscreen.md`
**Risk Level:** 🟢 Low

## Context Gates

- **ARCHITECTURE.md** — no boundary issues. Change is fully inside `packages/bci_module`, preserves the existing ViewModel/Service module boundary, and does not introduce new dependencies. PASS.
- **RULES.md** — not present at `.ai-factory/RULES.md`. WARN (no enforcement file to consult).
- **ROADMAP.md** — present; the change is a small UX cleanup. Linkage to a specific milestone is not declared in the plan. WARN (informational only — minor refactor).

## Verification of plan assumptions

Cross-checked against the actual codebase:

- `BciPairingScreen.dart` (lines 1–53) — already a `ConsumerStatefulWidget`/`ConsumerState`; `flutter_riverpod` is already imported. ✅ Plan is correct that only `mind_l10n`, `Models/BciPairingStage.dart`, and `Views/BciDisconnectDialog.dart` need to be added.
- `BciPairingTopBar.dart` is only referenced from `BciPairingScreen.dart` and the plan/notes files (grep confirmed). Deletion is safe. ✅
- `showBciDisconnectDialog(BuildContext)` returns `Future<bool>` (non-nullable). The plan's pattern `final ok = await ...; if (ok && context.mounted) vm.onDisconnect();` matches the API. ✅
- `BciPairingStage` exists at `Models/BciPairingStage.dart` with a `discovery` variant. ✅
- `AppLocalizations` exposes `bciPairingDisconnect` and `cancel` — both present in `app_en.arb`/`app_ru.arb`. ✅
- Current `Column.children` is `const [...]` and the new header is non-const — dropping `const` from the list literal while keeping `const` on individual section children is the right Dart move. ✅

## Critical Issues

None.

## Suggestions / Minor Issues

### 1. Header now scrolls with content (behavior change — confirm intent)
The original `Scaffold.appBar: BciPairingTopBar()` was pinned to the top of the screen. Inserting `_BciPairingHeader()` as the first child of the `Column` inside `SingleChildScrollView` makes the close button, battery indicator, and disconnect action **scroll out of view** once the user scrolls down through the discovery / impedance / calibration sections.

This may be acceptable (the spec says "match the rest of the app's title-bar-less style"), but worth verifying that the other title-bar-less screens behave the same way. If the close button must remain reachable while scrolling, consider either:
- Keeping `_BciPairingHeader()` outside the `SingleChildScrollView` (still inside `SafeArea`, as a sibling above the scroll view inside a `Column`), or
- Using a `CustomScrollView` with a non-floating `SliverToBoxAdapter` header (functionally same result but composes better with sliver sections later).

Not a blocker — flag only.

### 2. Disconnect button visibility behavior changes
Original `BciPairingTopBar` **conditionally rendered** the disconnect `TextButton` (`if (state.stage != BciPairingStage.discovery)`). The plan renders it always and disables it (`onPressed: null`) during discovery. The resulting UX shows a permanently-visible, dimmed "Disconnect" button on the discovery screen. This is per spec, but worth a quick design confirmation since the visual semantics differ from before.

### 3. Battery indicator visibility behavior changes
Same pattern — originally absent when `batteryPercent == null`, now always shown with `Opacity(0.3)` and `"--"` text. Per spec; just confirming this is intentional.

### 4. Orphaned l10n string `bciPairingTitle`
After this change, `bciPairingTitle` ("Connect Headband" / "Подключить нейрогарнитуру") becomes unreferenced — grep shows the only remaining production usage is in `BciPairingTopBar.dart`, which is being deleted. Consider adding a small follow-up task to:
- Remove `bciPairingTitle` from `packages/mind_l10n/lib/l10n/app_en.arb` and `app_ru.arb`.
- Regenerate `app_localizations*.dart` (or hand-edit the generated files consistent with how this project regenerates l10n).

Not strictly required, but it avoids dead translation strings.

### 5. Status bar / system overlay styling
`AppBar` automatically configures `SystemUiOverlayStyle` (status bar icon brightness). Once the AppBar is gone, the BCI pairing screen will inherit whatever the parent route last set. On Android in particular this can result in mismatched status bar icon colors against the screen background. If this is observable, set `AnnotatedRegion<SystemUiOverlayStyle>` on the Scaffold or rely on a global theme setting. Worth a quick visual check after implementation.

### 6. Tap-target padding
`EdgeInsets.symmetric(horizontal: 4, vertical: 4)` is fine for the row but leaves the close `IconButton` flush-left at 4px. Material default `IconButton` has 8px internal padding + 48dp tap area, so it lays out OK, but the visual gap on the leading edge is tighter than typical (`16` is more common). Cosmetic only — defer to the spec.

## Positive Notes

- Plan correctly identifies all three live controls that must survive the migration and preserves their wiring (`vm.onClose`, `vm.onDisconnect`, `showBciDisconnectDialog`).
- Co-locating `_BciPairingHeader` as a private `ConsumerWidget` in the same file (rather than introducing `BciPairingHeader.dart`) is a reasonable trade-off for a trivial header.
- Dependency ordering (`Task 1` before `Task 2`) is correct — deleting `BciPairingTopBar.dart` first surfaces the import error in `BciPairingScreen.dart` and forces the screen update.
- `context.mounted` guard after `await showBciDisconnectDialog` is preserved — good async-safety hygiene.
- ViewModel access pattern (`ref.watch` for state, `ref.read(...notifier)` for actions) matches the rest of the codebase.

## Overall

Plan is well-scoped, internally consistent, and faithful to the spec. All file paths, imports, and API usages check out against the current codebase. The only items above are cosmetic / clarifying — none block implementation.

PLAN_REVIEW_PASS
