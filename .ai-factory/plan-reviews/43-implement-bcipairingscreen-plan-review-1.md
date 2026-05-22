# Plan Review: 43-implement-bcipairingscreen

**Plan:** `.ai-factory/plans/43-implement-bcipairingscreen.md`
**Spec reference:** `.ai-factory/notes/17-bci-pairing-screen.md`
**Risk Level:** 🟡 Medium — plan is detailed and largely faithful to note 17, but several references to APIs / constants don't exist in the codebase and one section's behaviour is under-specified.

### Context Gates

- **ARCHITECTURE / RULES:** No violations of `.ai-factory/RULES.md` — the Service / Coordinator concrete classes are explicitly out of scope, and this milestone stays inside the package, so the "stateless Service" / "no module wiring in App.dart" rules don't apply yet. `BciPairingViewModel` already exists and handles `ref.onDispose`, matching the rules. ✅
- **ROADMAP:** Plan implements ROADMAP line 95 (the only `[ ]` BCI item before the Service/Coordinator + wiring milestones at lines 97 and 99). Scope boundary respected. ✅

---

### Critical Issues

#### 1. `AppDimensions` does not exist
Task 8 says: *"Use vertical padding from `AppDimensions` between sections."*

`packages/mind_ui/lib/src/app_dimensions.dart` only exports a single `const double kCardCornerRadius = 8.0;`. There is no `AppDimensions` class and no spacing constant anywhere in `mind_ui`. As written, the implementer will either:
- silently invent/hardcode a value (drift from spec), or
- add a constant to `app_dimensions.dart` (undocumented scope creep into `mind_ui`).

**Fix:** Either (a) pick an explicit numeric value in the plan (`EdgeInsets.symmetric(vertical: 16)`), or (b) add an explicit sub-task to introduce a spacing constant in `mind_ui` and update its export.

#### 2. `BciPairingTopBar` centering trick is not specified and won't work as a plain `Row`
Task 7 describes a `Row` inside `kToolbarHeight` with:
- leading `IconButton(close)`
- *"Centered `Text(l10n.bciPairingTitle)`"*
- trailing battery + disconnect block

A plain `Row` cannot center its middle child when the leading/trailing children have unequal widths — the title will drift. Either `Stack` + centered title with `Positioned` leading/trailing, an `AppBar` widget (which already implements this), or `NavigationToolbar` is required. The plan doesn't say which, and `BreathSession`'s top bars use `AppBar`. **Recommend** rewriting Task 7 to use `AppBar(leading:, title:, actions:, centerTitle: true)` — it removes ~30 lines of custom layout code and handles `kToolbarHeight`, safe-area, and title centering correctly.

#### 3. Battery emoji conflicts with project convention
Task 7 specifies `Text('🔋 ${state.batteryPercent}%')`. This carries over verbatim from note 17, but the user's global rule is "only use emojis if the user explicitly requests it." Replace with `Icon(Icons.battery_full, size: 16) + Text('${state.batteryPercent}%')` or similar.

#### 4. Phantom "switch devices CTA" in `BciCalibrationSection`
End of Task 6: *"the disconnect dialog is owned by the top bar, but `BciCalibrationSection` may invoke `showBciDisconnectDialog` for the 'switch devices' CTA when in `ready` stage; importing the public helper from `BciDisconnectDialog.dart` is required (Guard 2 rationale)."*

The Calibration section spec (4 bullets above) never describes such a CTA — only the Start button, stage dots, instruction text, and the completion row. As written, Guard 2's rationale is justified by code that the plan does not ask the implementer to write. Either:
- add an explicit bullet describing the "switch devices" button (text, position, behaviour), or
- drop the import-from-sibling requirement and let only `BciPairingTopBar` import `showBciDisconnectDialog` (Guard 2 then becomes "public so the screen-level `BciPairingTopBar` can import it" — which is still true).

---

### Should Fix

#### 5. `just_audio` direct dep contradicts the spec
Note 17 says: *"`bci_module` does not import `just_audio` directly."* `packages/bci_module/pubspec.yaml` currently has `just_audio: ^0.10.5` as a direct dep (carried over from the scaffold). Task 1 adds `mind_audio` but doesn't remove `just_audio`. Nothing the plan asks for needs `just_audio` directly — `AudioOneShot` and `AssetAudioCatalog` from `mind_audio` are the only audio entry points. Recommend: Task 1 also removes the `just_audio` line.

#### 6. `uses-material-design` not specified for the package
Task 5/6/7 use `Icons.bluetooth`, `Icons.close`, `Icons.check_circle`. The package's `flutter:` block is currently empty and the plan adds only `assets:` under it. In practice the host app declares `uses-material-design: true`, but a package that ships with material icons in its own widgets typically should declare it too, so the package's own tests / examples bundle the icon font. Not blocking, but worth a line.

#### 7. Discovery section `_pendingSerial` is fragile by design
Task 4 acknowledges the gap: the public state lacks a `targetSerial`, so a per-row spinner is keyed off a local `_pendingSerial` tracked on tap. Limitations the plan doesn't call out:
- spinner won't appear if the connection is auto-initiated (e.g. auto-reconnect) without a user tap;
- if two devices are tapped quickly the older row's spinner disappears even if it's still the connection target;
- if user backgrounds and reopens the screen mid-connect, `_pendingSerial` is `null` and no spinner shows.

These are tolerable for a first cut, but the spec note 17 already implies the state model needs a `targetSerial` field. Consider either (a) extending `BciPairingState` with `String? targetConnectingSerial` in this milestone (a 4-line change to `BciPairingState.dart`, fully owned by `bci_module`), or (b) explicitly documenting in the plan that the spinner-on-tap is best-effort and the proper fix arrives with the Service milestone.

#### 8. Discovery section progress indicator behaviour doesn't match note 17
Plan Task 4: *"If `state.isScanning` → render a `LinearProgressIndicator` at the top of the section."*
Note 17:
- `state.isScanning && state.devices.isEmpty` → "shimmer or `LinearProgressIndicator`"
- `state.isScanning && state.devices.isNotEmpty` → "`LinearProgressIndicator` at top + device list"

Functionally the simpler "always show when scanning" subsumes both branches, so no functional regression — but the plan doesn't reference the empty-vs-non-empty distinction at all, and the implementer might miss the "shimmer when empty" affordance that note 17 hints at. Acceptable simplification, but worth an explicit "intentionally simpler than note 17" comment in the task.

#### 9. `ref.listen` placement isn't named for Task 4
Task 4 says: *"clear `_pendingSerial` in `ref.listen<BciPairingState>` whenever `next.isConnecting == false`."* `ref.listen` must be called inside `build()` of a `ConsumerStatefulWidget`. The plan never says where — implementer may try to put it in `initState` (which fails). One-line clarification needed.

---

### Minor / Stylistic

- **Task 2 l10n regeneration claim** is approximately correct (`mind_l10n` has `flutter: generate: true` + `l10n.yaml` with `synthetic-package: false`), but the regenerated files are produced by the **host app's** `flutter pub get` / build cycle, not by running `flutter pub get` inside `packages/mind_l10n/`. The plan reads as if either works. Implementer should know to run pub get from `mind_mobile/` root after editing the ARB files.

- **Discovery section spinner size** — `size ≈ 18` is approximate; consider `SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))` to keep the row leading width predictable. Not blocking.

- **Section header reuse** — Task 4 says "look at `BreathSessionListSectionHeader` for tone" but doesn't say whether to import it or build a local equivalent. `BreathSessionListSectionHeader` lives in `breath_module` and `bci_module` must not depend on it. Recommend: explicitly say "build a local `BciSectionHeader` widget with the same style (theme.cardColor at 0.3 alpha, labelLarge in bodySmall color, 16/12 padding) — do **not** import from `breath_module`."

- **`bciPairingKnownDevice` is "Previously paired"** (a long phrase) — Task 4 says trailing badge. That's wide for a list row trailing. Consider a small `Chip` or shorten the EN key to "Paired". Not blocking — translation is the team's call.

---

### Positive Notes

- Guards 1–4 capture exactly the four landmines that bit prior attempts (asset path form, dialog visibility, `unawaited` lint, mount-time false→true). Good defensive design.
- Faithful translation of note 17 into ordered, dependency-aware tasks with a coherent commit plan.
- Phase 1 correctly puts pubspec + asset wiring first so subsequent tasks compile cleanly.
- Task 6's audio cue snippet matches `AudioOneShot` / `AssetAudioCatalog` semantics exactly — the cue is loaded once, played via fire-and-forget seek+play, and disposed in `dispose()`. Good.
- Russian translations are idiomatic and complete (all 11 keys, not just the obvious ones).
- ROADMAP scope respected — Service and Coordinator implementations correctly deferred to the next milestone (line 97), avoiding the trap of doing all three at once.

---

### Recommended Action

Apply fixes for issues **1**, **2**, **3**, **4** before implementation — each one will otherwise produce code that either won't compile, will look wrong, or implements behaviour the plan doesn't actually request. Issues 5–9 are cleanup that improves quality but won't block compilation.
