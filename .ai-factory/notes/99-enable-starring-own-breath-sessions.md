# Enable Starring Own Breath Sessions

**Date:** 2026-06-04
**Source:** conversation context — starred-own-sessions feature (mobile half)

## Key Findings

- Today the star control on `BreathSessionScreen` (detail view) is hidden for the user's own sessions by the guard `canStar = session.userId != currentUserId` in `lib/BreathModule/BreathSessionDTOMapper.dart:13`. Only **other users'** shared sessions can be starred from the UI.
- The entire star write-path (ViewModel → Service → Notifier → Repository → gRPC `UpdateSessionSettings`) has **no ownership restriction** — the only thing blocking starring your own session is that single UI guard. The backend `UpdateSessionSettings` handler also has no owner guard, so starring an own session already persists server-side.
- This milestone flips that guard so own sessions become starrable from the detail screen. It is independent of the list/cursor migration (note 100) and ships on its own: starring an own session persists and the star icon reflects state on detail re-open. The new STARRED list section that floats own-starred sessions to the top is delivered separately in note 100.

## Details

### Current state

`lib/BreathModule/BreathSessionDTOMapper.dart` builds the detail-screen DTO:

```dart
canStar: session.userId != currentUserId,
```

`packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart` (~lines 348–355) renders the star only when `canStar`:

```dart
if (canStar)
  IconButton(
    icon: Icon(isStarred ? Icons.star : Icons.star_border),
    color: isStarred ? AppColors.warmAccentDark : AppColors.accent,
    onPressed: () => viewModel.toggleStar(),
  ),
```

The write-path that runs on tap — all already ownership-agnostic:
- `BreathSessionViewModel.toggleStar()` (`packages/breath_module/.../BreathSession/BreathSessionViewModel.dart:295`) — optimistic flip, calls `service.starSession`.
- `BreathSessionService.starSession` (`lib/BreathModule/BreathSessionService.dart:49`) → `notifier.starSession`.
- `BreathSessionNotifier.starSession` (`lib/BreathModule/Core/BreathSessionNotifier.dart:154`) → `repository.starSession`, updates in-memory `isStarred`, emits `SessionStarred`.
- `BreathSessionRepository.starSession` (`lib/BreathModule/Core/BreathSessionRepository.dart:81`) → `_api.starSession` + Drift write-through.
- `BreathSessionApi.starSession` (`lib/BreathModule/Core/BreathSessionApi.dart:61`) → `UpdateSessionSettingsRequest(id, starred)`.

### The change

One line in `lib/BreathModule/BreathSessionDTOMapper.dart`:

```dart
canStar: true,   // own sessions are now starrable too (was: session.userId != currentUserId)
```

Keep the `canStar` field rather than deleting it — the screen's `if (canStar)` stays, and the field documents intent. `currentUserId` may become unused inside the mapper after this; if so, remove the now-dead parameter usage only if it produces an analyzer warning, otherwise leave the signature untouched (other call sites pass it).

### Guards / scope

- **Detail screen only.** Do not add a star control to list cells (`BreathSessionListCell`) — starring stays a detail-screen action. The list's reaction to a star (floating into the STARRED section) is note 100's concern.
- Do not touch the Notifier/Service/Repository/Api star path — it already works for own sessions.
- Do not touch the Drift schema — `BreathSessions.isStarred` column already exists.
- The orb-gold star color logic (`isStarred ? AppColors.warmAccentDark : AppColors.accent`) from note 83 stays as-is.

### How to verify

1. Open a session you own → the star icon is now visible (was hidden).
2. Tap it → icon fills; reopen the session → still starred (persisted via `UpdateSessionSettings`).
3. Tap again → unstars and persists.
4. A session owned by another user still shows the star (unchanged behavior).
5. No list reordering yet — that arrives with note 100.
