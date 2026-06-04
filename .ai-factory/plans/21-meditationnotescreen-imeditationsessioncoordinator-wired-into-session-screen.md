# Plan: MeditationNoteScreen + IMeditationSessionCoordinator wired into session screen

## Context
Adds post-session note capture to the meditation module: a full-screen note input shown when a session stops, driven by a package-side coordinator interface. Package-side only — the concrete coordinator and persistence land in later milestones.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

> **State note / assumption:** The spec (`.ai-factory/notes/64-meditation-note-screen-ui.md`) was written before `IMeditationSessionCoordinator` existed. It now exists as `abstract class IMeditationSessionCoordinator { void close(); }` (`packages/meditation_module/lib/src/MeditationSession/IMeditationSessionCoordinator.dart`), and a stale concrete `lib/MeditationModule/MeditationSessionCoordinator.dart` implements `close()`. The roadmap milestone is authoritative: the interface must become `Future<void> onSessionStopped();`. `close()` is dead code (no caller; `meditationSessionCoordinatorProvider` does not exist yet, and `MeditationModule.buildSession()` never wires a coordinator). Tasks 2 and 2b below keep the app analyzer-clean **and crash-free** after the signature change — the full `onSessionStopped()` behavior (push note screen, persist) remains scoped to a later milestone (ROADMAP line 78).
>
> **Runtime-safety note (resolves plan-review critical issue #1):** `MeditationSessionScreen` is live in production — `lib/router.dart:61-65` routes `MeditationSessionScreen.path` → `MeditationModule.buildSession(...)`. Task 5 adds a live `ref.read(meditationSessionCoordinatorProvider)` on the `active → idle` transition. The `unawaited()` wrapper does **not** protect against a throw here: `ref.read(...)` is evaluated synchronously inside the listener callback, so a throw-by-default provider would escape as an uncaught error *before* any `Future` exists. Therefore the provider **must** be overridden in `buildSession()` this milestone (Task 2b) with the Task 2 placeholder coordinator (a safe no-op), or every session stop throws `UnimplementedError`. This is the deliberate exception to "concrete coordinator lands later": the *placeholder* must be wired now because this milestone introduces a live consumer. The full `onSessionStopped()` behavior still lands in the later milestone.

### Phase 1: Coordinator interface + provider + safe wiring

- [x] **Task 1: Replace coordinator interface signature and add provider**
  Files: `packages/meditation_module/lib/src/MeditationSession/IMeditationSessionCoordinator.dart`
  Replace the existing `void close();` member with `Future<void> onSessionStopped();`. Add `import 'package:flutter_riverpod/flutter_riverpod.dart';` and declare a throw-by-default provider below the class:
  ```dart
  final meditationSessionCoordinatorProvider =
      Provider<IMeditationSessionCoordinator>((_) {
    throw UnimplementedError('must be overridden via ProviderScope');
  });
  ```
  The interface file is already exported from the barrel (`packages/meditation_module/lib/meditation_module.dart` line 11) — no barrel change needed for this file. `flutter_riverpod` is already a dependency of the package.

- [x] **Task 2: Replace `close()` with a placeholder `onSessionStopped()` in the concrete coordinator** (depends on Task 1)
  Files: `lib/MeditationModule/MeditationSessionCoordinator.dart`
  The existing class overrides `close()`, which no longer exists on the interface. Replace the `close()` override with a minimal placeholder satisfying the new contract so the app stays analyzer-clean:
  ```dart
  @override
  Future<void> onSessionStopped() async {
    // Placeholder — full implementation (push MeditationNoteScreen, persist note)
    // arrives in the meditation-notes wiring milestone (ROADMAP line 78).
  }
  ```
  Drop the now-unused `go_router` import (no longer referenced after removing the `context.pop()` body). Keep the `final BuildContext context;` field and the `package:flutter/widgets.dart` import — the field is unused this milestone (not analyzer-flagged: `unused_field` targets private fields only; `BuildContext` still needs the import) and is consumed by Task 2b's constructor call plus the real `onSessionStopped()` navigation later.

- [x] **Task 2b: Override `meditationSessionCoordinatorProvider` with the placeholder in `buildSession()`** (depends on Task 1, Task 2)
  Files: `lib/MeditationModule/MeditationModule.dart`
  `MeditationSessionScreen` is production-routed (`lib/router.dart:61-65` → `buildSession`), and Task 5 adds a live synchronous `ref.read(meditationSessionCoordinatorProvider)` on every session stop. Without an override the throw-by-default provider crashes every stop. Add the placeholder override alongside the existing `meditationSessionViewModelProvider` override in `buildSession()`'s `overrides:` list:
  ```dart
  meditationSessionCoordinatorProvider.overrideWithValue(
    MeditationSessionCoordinator(context),
  ),
  ```
  Add `import 'package:mind/MeditationModule/MeditationSessionCoordinator.dart';` (the `meditation_module` barrel — which exports the provider — is already imported). Its `onSessionStopped()` is the Task 2 no-op, so the listener fires harmlessly until the real implementation lands. Do not change the existing `viewModel`/`stateChannel` wiring.

### Phase 2: Localization

- [x] **Task 3: Add `meditationNotePrompt` ARB key and regenerate localizations** (depends on Task 1)
  Files: `packages/mind_l10n/lib/l10n/app_en.arb`, `packages/mind_l10n/lib/l10n/app_ru.arb`
  Add the key to both ARB files (reuse existing `ok` and `cancel` keys — both already present in EN and RU):
  - EN: `"meditationNotePrompt": "Write what you felt during the session — how you felt at the start, and how it changed towards the end. This will help the AI better understand your body."`
  - RU: `"meditationNotePrompt": "Запишите что чувствовали на протяжении сессии — что в начале, и как это изменилось к концу. Это поможет нейросети лучше понимать ваше тело."`
  Regenerate `AppLocalizations` by running `/usr/local/bin/flutter gen-l10n` from inside `packages/mind_l10n/` (config: `packages/mind_l10n/l10n.yaml`, `synthetic-package: false`, output `app_localizations.dart`, re-exported via the `mind_l10n` barrel). Confirm `meditationNotePrompt` appears in the generated `app_localizations*.dart`.

### Phase 3: Note screen + session screen wiring

- [x] **Task 4: Create `MeditationNoteScreen` and export it** (depends on Task 3)
  Files: `packages/meditation_module/lib/src/MeditationSession/MeditationNoteScreen.dart`, `packages/meditation_module/lib/meditation_module.dart`
  Create a plain `StatefulWidget` (no `ConsumerWidget` needed — no ViewModel), no `AppBar`, following the layout in note 64:
  - A local `TextEditingController`, disposed in `dispose()`.
  - `Scaffold` → `SafeArea` → `Column` with:
    1. `Padding(fromLTRB(16,16,16,8))` wrapping muted prompt `Text(l10n.meditationNotePrompt)` styled `Theme.of(context).textTheme.bodySmall` with color at alpha 0.5 (`...color?.withValues(alpha: 0.5)`).
    2. `Expanded` → `Padding(fromLTRB(16,0,16,0))` → `TextField(controller, autofocus: true, maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top, decoration: InputDecoration(border: InputBorder.none))`.
    3. `Padding(fromLTRB(16,0,16,16))` → `Row(mainAxisAlignment: end)` with `TextButton(Cancel → Navigator.of(context).pop(null))`, `SizedBox(width: 8)`, `TextButton(OK → Navigator.of(context).pop(_controller.text))`. Use `l10n.cancel` / `l10n.ok`.
  - Import `package:flutter/material.dart` and `package:mind_l10n/mind_l10n.dart`; access strings via `AppLocalizations.of(context)!` (same pattern as `MeditationListScreen.dart`).
  - Add a `static String name`/`path` if matching the screen-route convention used by sibling screens is desired (optional — the screen is pushed via `Navigator.push`, not GoRouter, in the later wiring task).
  Add to the barrel: `export 'src/MeditationSession/MeditationNoteScreen.dart';`.

- [x] **Task 5: Trigger coordinator on session stop in `MeditationSessionScreen`** (depends on Task 1, Task 2b, Task 4)
  Files: `packages/meditation_module/lib/src/MeditationSession/MeditationSessionScreen.dart`
  Inside `build()` (the widget is a `ConsumerStatefulWidget`, so `ref.listen` is valid here), add a listener on the status selector that fires the coordinator on the `active → idle` transition:
  ```dart
  ref.listen<MeditationSessionStatus>(
    meditationSessionViewModelProvider.select((s) => s.status),
    (previous, next) {
      if (previous == MeditationSessionStatus.active &&
          next == MeditationSessionStatus.idle) {
        unawaited(
          ref.read(meditationSessionCoordinatorProvider).onSessionStopped(),
        );
      }
    },
  );
  ```
  Add `import 'dart:async';` (for `unawaited`) and `import 'IMeditationSessionCoordinator.dart';`. Leave the stop/play `ControlButton` handler unchanged — it still calls `vm.stop()`; the listener reacts to the resulting status change. Because Task 2b overrides the provider with the no-op placeholder, this read resolves successfully and the call is a harmless no-op until the later milestone supplies the real coordinator.

## Commit Plan
- **Commit 1** (after tasks 1, 2, 2b, 3): "Add meditation session coordinator onSessionStopped contract and note prompt string"
- **Commit 2** (after tasks 4-5): "Add meditation post-session note screen and stop trigger"
