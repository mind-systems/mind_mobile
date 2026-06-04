# Plan: Enable starring own breath sessions (flip `canStar` guard)

## Context
Make the user's own breath sessions starrable from the detail screen by flipping the single UI guard that currently hides the star for owned sessions. The whole write-path and backend are already ownership-agnostic, so one line is sufficient.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Flip the guard

- [x] **Task 1: Make own sessions starrable in the detail DTO**
  Files: `lib/BreathModule/BreathSessionDTOMapper.dart`
  In `BreathSessionDTOMapper.map`, change line 13 from `canStar: session.userId != currentUserId,` to `canStar: true,`. Keep the `canStar` field (the screen's `if (canStar)` guard stays and the field documents intent). Leave the `map` method signature untouched — `currentUserId` remains a `required` named parameter passed from all 3 call sites in `lib/BreathModule/BreathSessionService.dart` (lines 21, 31, 55); Dart does not warn on an unused parameter, so do not remove it. Optionally add a short comment noting own sessions are now starrable too.

  Out of scope (do NOT touch):
  - `BreathSessionListCell` / list cells — no star control is added to the list (note 100's concern).
  - The star write-path: `BreathSessionViewModel.toggleStar` → `BreathSessionService.starSession` → `BreathSessionNotifier.starSession` → `BreathSessionRepository.starSession` → `BreathSessionApi.starSession`. Already ownership-agnostic.
  - Drift schema — `BreathSessions.isStarred` already exists.
  - The note-83 star color logic (`isStarred ? AppColors.warmAccentDark : AppColors.accent`) in `BreathSessionScreen`.
