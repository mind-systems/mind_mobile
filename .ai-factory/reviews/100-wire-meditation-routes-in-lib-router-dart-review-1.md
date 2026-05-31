# Code Review: Wire meditation routes in `lib/router.dart`

## Scope
Single changed file: `lib/router.dart` (two imports + two `GoRoute`s). Plus plan/metadata artifacts (not code).

## Verification performed
- `git diff HEAD` / `git status` — only `lib/router.dart` is a code change.
- Confirmed referenced symbols exist:
  - `MeditationListScreen.path` / `.name` and `MeditationSessionScreen.path` / `.name` are defined as `static` fields and exported from the `meditation_module` barrel.
  - `MeditationModule.buildSessionList(context)` and `MeditationModule.buildSession(context, {required String poseId})` exist with matching signatures.
- Checked the navigation source: `MeditationListCoordinator.openSession` calls `context.push(MeditationSessionScreen.path, extra: poseId)` with a non-null `String` sourced from the static pose list — so the `state.extra as String` cast in the session route builder is safe and will not throw.

## Findings
- Imports and routes are an exact mirror of the existing breath routes. Import ordering is cosmetically inconsistent (the `MeditationModule` app-layer import sits above the `breath_module`/`bci_module` package imports), but this matches the pre-existing mixed ordering in the file and has no functional impact — not a defect.
- No bugs, type mismatches, null-safety hazards, or runtime risks identified. No security concerns (routing only, no auth/data handling).

REVIEW_PASS
