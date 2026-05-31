# Plan: Add meditation card to the Home grid

## Context
Add a fourth card (Meditation) to the Home screen module grid that navigates to the existing meditation list screen. All infrastructure (meditation_module package dependency, `/meditation_list` route in `router.dart`, the asset) already exists — this milestone only wires the Home grid entry, ViewModel handler, and coordinator navigation.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Localization

- [x] **Task 1: Add `homeTabMeditation` key to both ARB files**
  Files: `packages/mind_l10n/lib/l10n/app_en.arb`, `packages/mind_l10n/lib/l10n/app_ru.arb`
  Add the key `"homeTabMeditation"` next to the existing `"homeTabBreath"` / `"homeTabMind"` entries.
  - EN (`app_en.arb`): `"homeTabMeditation": "Meditation"`
  - RU (`app_ru.arb`): `"homeTabMeditation": "Медитация"`

- [x] **Task 2: Regenerate localization sources** (depends on Task 1)
  Files: `packages/mind_l10n/lib/l10n/app_localizations.dart`, `packages/mind_l10n/lib/l10n/app_localizations_en.dart`, `packages/mind_l10n/lib/l10n/app_localizations_ru.dart`
  Run the l10n codegen so the new getter `String get homeTabMeditation` appears in the generated files (these are committed in the repo, so they must be regenerated, not left stale). Use the project's localization generation (e.g. `/usr/local/bin/flutter gen-l10n` run from `packages/mind_l10n`, or the equivalent configured command). Verify the abstract getter is added in `app_localizations.dart` and concrete getters return `'Meditation'` (EN) / `'Медитация'` (RU). If codegen tooling is unavailable, add the three getters manually mirroring `homeTabBreath`.

### Phase 2: Navigation wiring

- [x] **Task 3: Add `openMeditation()` to the coordinator interface** (depends on Task 2)
  Files: `lib/HomeModule/Presentation/HomeScreen/IHomeCoordinator.dart`
  Add `void openMeditation();` to the `IHomeCoordinator` abstract class, alongside `openBreath()`.

- [x] **Task 4: Implement `openMeditation()` in `HomeCoordinator`** (depends on Task 3)
  Files: `lib/HomeModule/Presentation/HomeScreen/HomeCoordinator.dart`
  Add `MeditationListScreen` to the existing `meditation_module` import via a `show` clause (the package is already a dependency and the `/meditation_list` route is already registered in `router.dart`). Implement the override mirroring `openBreath`:
  ```dart
  @override
  void openMeditation() => context.push(MeditationListScreen.path);
  ```
  Add the import: `import 'package:meditation_module/meditation_module.dart' show MeditationListScreen;`

- [x] **Task 5: Add `onMeditationTap()` to `HomeViewModel`** (depends on Task 3)
  Files: `lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart`
  Add `void onMeditationTap() => coordinator.openMeditation();` alongside `onBreathTap` / `onComingSoonTap`.

### Phase 3: UI

- [x] **Task 6: Add the Meditation `ModuleItem` to the Home grid** (depends on Tasks 2, 5)
  Files: `lib/HomeModule/Presentation/HomeScreen/HomeScreen.dart`
  Insert a new `ModuleItem` into the `modules` list between the Breath and Mind entries so the grid order becomes Breath, Meditation, Mind, Profile:
  ```dart
  ModuleItem(
    title: l10n.homeTabMeditation,
    iconPath: 'assets/images/modules/home/meditation.png',
    onTap: vm.onMeditationTap,
  ),
  ```
  The grid already renders `modules.length` cells with `crossAxisCount: 2`, so growing the list to 4 items requires no layout changes.
