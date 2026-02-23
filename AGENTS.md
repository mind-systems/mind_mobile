# AGENTS.md

> Project map for AI agents. Keep this file up-to-date as the project evolves.

## Project Overview

Mind is a Flutter mindfulness app (iOS + Android) where users create and run guided breathing sessions with animated visual feedback. It uses Firebase Auth with Google Sign-In and syncs sessions with a remote REST API.

## Tech Stack

- **Language:** Dart 3.3+
- **Framework:** Flutter 3+ (iOS + Android)
- **Local DB:** Drift (SQLite ORM)
- **HTTP:** Dio + AuthInterceptor (JWT)
- **Presentation State:** Riverpod 2.x
- **Domain State:** RxDart (BehaviorSubject)
- **Navigation:** GoRouter
- **Auth:** Firebase Auth + Google Sign-In
- **DI:** Manual singleton (`App.shared`)

## Project Structure

```
lib/
├── Core/                          # App-wide infrastructure
│   ├── App.dart                   # DI singleton — initialization order matters
│   ├── Environment.dart           # API base URL, keys (gitignored, copy from .example)
│   ├── Database/                  # Drift ORM — schema, DAOs, generated code
│   ├── Api/                       # Dio client, AuthInterceptor, ApiException model
│   ├── GlobalUI/                  # GlobalKeys, GlobalListeners (auth events)
│   ├── Handlers/                  # Firebase deep link handler
│   └── DeeplinkRouter.dart        # Deep link → GoRouter bridge
├── User/                          # Authentication module
│   ├── UserNotifier.dart          # Domain: auth state (AuthenticatedState/GuestState)
│   ├── UserRepository.dart        # Domain: user persistence + API calls
│   ├── LogoutNotifier.dart        # Publishes logout events from AuthInterceptor
│   └── Presentation/Login/        # LoginScreen, LoginViewModel, LoginService
├── BreathModule/                  # Breathing feature (self-contained module)
│   ├── Core/                      # Domain: BreathSessionNotifier, BreathSessionRepository
│   ├── Models/                    # Domain models: BreathSession, ExerciseStep, StepType
│   ├── Presentation/
│   │   ├── BreathSessionsList/    # List screen: Screen, ViewModel, Coordinator, DTOs, Views
│   │   ├── BreathSession/         # Active session screen + 4-component animation system
│   │   │   ├── BreathSessionEngine.dart         # State machine (inhale/hold/exhale/rest)
│   │   │   ├── Animation/BreathMotionEngine.dart # Physics-based position animation
│   │   │   ├── Animation/BreathShapeShifter.dart # Path morphing (circle/square/triangle)
│   │   │   └── Animation/BreathAnimationCoordinator.dart
│   │   └── BreathSessionConstructor/  # Create/edit sessions
│   ├── BreathSessionListService.dart  # Service: domain → list DTOs
│   ├── BreathSessionService.dart      # Service: domain → session DTOs
│   └── BreathSessionDTOMapper.dart    # Shared domain model → DTO mapping
├── Views/                         # Shared UI components
├── router.dart                    # GoRouter config — all routes
├── Logger.dart                    # Structured logging
├── main_dev.dart                  # Dev flavor entry point
└── main_prod.dart                 # Prod flavor entry point
```

## Key Entry Points

| File | Purpose |
|------|---------|
| `lib/Core/App.dart` | DI initialization (must follow order: Firebase → DB → API → Auth → Repositories → Notifiers → runApp) |
| `lib/router.dart` | All GoRouter routes |
| `lib/Core/Database/Database.dart` | Drift schema — run `flutter pub run build_runner build` after changes |
| `lib/Core/Environment.example.dart` | Template for `Environment.dart` (gitignored, must be created on first setup) |
| `lib/Core/Api/AuthInterceptor.dart` | JWT attach + 401 → logout flow |

## Routes

| Route | Screen |
|-------|--------|
| `/` | `BreathSessionListScreen` |
| `/onboarding` | `OnboardingScreen` |
| `/login` | `LoginScreen` |
| `/breath/:sessionId` | `BreathSessionScreen` |
| `/constructor` | `BreathSessionConstructorScreen` |

## Documentation

| Document | Path | Description |
|----------|------|-------------|
| Project spec | `.ai-factory/DESCRIPTION.md` | Tech stack and architecture overview |
| Architecture | `.ai-factory/ARCHITECTURE.md` | Architecture decisions and guidelines |
| Notifier pattern | `docs/core/notifier-pattern.md` | How domain notifiers emit typed events |
| JWT auth | `docs/core/jwt-authentication.md` | Token lifecycle |
| Global listeners | `docs/core/global-listeners.md` | Auth event propagation |
| Session ViewModel | `docs/breath/session/view-model.md` | BreathSessionEngine state machine |
| Setup | `README_SETUP.md` | First-time setup instructions |

## AI Context Files

| File | Purpose |
|------|---------|
| `AGENTS.md` | This file — project structure map |
| `CLAUDE.md` | Claude Code instructions and architecture reference |
| `.ai-factory/DESCRIPTION.md` | Project specification and tech stack |
| `.ai-factory/ARCHITECTURE.md` | Architecture decisions and guidelines |
