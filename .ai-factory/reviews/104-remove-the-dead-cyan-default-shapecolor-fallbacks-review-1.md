## Code Review — 104 Remove the dead cyan default `shapeColor` fallbacks

**Branch:** bci-integration
**Files reviewed (code):**
- `packages/breath_module/lib/src/BreathSession/Views/BreathShapePainter.dart`
- `packages/breath_module/lib/src/BreathSession/Views/BreathShapeWidget.dart`

(The other staged files are plan/review artifacts — `.ai-factory/plans/*` and `.ai-factory/plan-reviews/*` — not application code.)

### Summary
The change makes `shapeColor` a required parameter in both `BreathShapePainter` and `BreathShapeWidget`, removing the unreachable `const Color(0xFF00D9FF)` cyan defaults. The edits match the plan exactly and the scope is correctly limited to `shapeColor` — `pointColor`, `shapeStrokeWidth`/`strokeWidth`, and `pointRadius` keep their defaults and `??` fallbacks.

### Correctness verification
- **`BreathShapePainter`** — constructor now declares `required this.shapeColor`; field remains `final Color shapeColor;` (non-nullable, already was). Correct.
- **`BreathShapeWidget`** — field changed `Color? shapeColor` → `Color shapeColor`, constructor parameter `this.shapeColor` → `required this.shapeColor`, and the painter call dropped the `?? const Color(0xFF00D9FF)` fallback, now passing `shapeColor` directly. All three edits are consistent.
- **Call sites** — repo-wide search confirms exactly one constructor of each: `BreathShapePainter(` is built only inside `BreathShapeWidget.build` (line 43), and `BreathShapeWidget(` is used only at `BreathSessionScreen.dart:239`, which already passes `shapeColor: cs.tertiary`. The new `required` parameter is satisfied with no call-site edits. No behavior change.
- **Analyzer** — `flutter analyze` inside `packages/breath_module` reports "No issues found!" (no missing-required-argument errors, no dead-code/nullability warnings).

### Findings
None. No bugs, security issues, or correctness problems. The non-nullable `shapeColor` is now guaranteed at compile time by the single call site, so no runtime null path exists.

REVIEW_PASS
