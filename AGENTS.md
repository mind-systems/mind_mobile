# AGENTS.md

> Project map for AI agents. Keep this file up-to-date as the project evolves.

See `.ai-factory/DESCRIPTION.md` for full project spec and tech stack.
See `.ai-factory/ARCHITECTURE.md` for architecture decisions, folder structure, and layer rules.

## Routes

| Route | Screen |
|-------|--------|
| `/` | `HomeScreen` |
| `/breath_session_list` | `BreathSessionListScreen` |
| `/coming-soon` | `ComingSoonScreen` |
| `/onboarding` | `OnboardingScreen` |
| `/login` | `LoginScreen` |
| `/breath/:sessionId` | `BreathSessionScreen` |
| `/constructor` | `BreathSessionConstructorScreen` |

## Key Entry Points

| File | Purpose |
|------|---------|
| `lib/Core/App.dart` | DI init (Firebase → DB → API → Auth → Repositories → Notifiers → runApp) + theme wiring |
| `lib/Core/AppTheme.dart` | Canonical theme — `AppTheme.dark()` / `AppTheme.light()`, palette constants |
| `lib/router.dart` | All GoRouter routes |
| `lib/Core/Database/Database.dart` | Drift schema — run `flutter pub run build_runner build` after changes |
| `lib/Core/Api/AuthInterceptor.dart` | JWT attach + 401 → logout flow |
| `lib/Core/Environment.example.dart` | Template for `Environment.dart` (gitignored, must be created on first setup) |
