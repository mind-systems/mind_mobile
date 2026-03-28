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
| `lib/Core/App.dart` | DI init (Google Sign-In → DB → API → Auth → Repositories → Notifiers → runApp) + theme wiring |
| `lib/Core/AppTheme.dart` | Canonical theme — `AppTheme.dark()` / `AppTheme.light()`, palette constants |
| `lib/router.dart` | All GoRouter routes |
| `lib/Core/Database/Database.dart` | Drift schema — run `flutter pub run build_runner build` after changes |
| `lib/Core/Grpc/GrpcAuthInterceptor.dart` | JWT attach + UNAUTHENTICATED → logout flow |
| `lib/Core/Sync/SyncEngine.dart` | Data sync pipeline: fetch changes → group → batch-refetch → apply to Drift |
| `lib/Core/Sync/SyncGrpcListener.dart` | Bridges gRPC `WatchChanges` server-stream events to SyncEngine |
| `lib/Core/Sync/SyncApi.dart` | gRPC client for sync changes and batch session fetching |
| `lib/Core/Database/SyncStateDao.dart` | Drift DAO for sync cursor (`lastEventId`) persistence |
| `lib/Core/Environment.example.dart` | Template for `Environment.dart` (gitignored, must be created on first setup) |
