# Project: Mind Mobile

## Overview

A Flutter mindfulness/breathing exercise app for iOS and Android. Users can create, browse, and run guided breathing sessions with animated visual feedback (shape morphing + physics-based motion). The app supports Google Sign-In authentication and syncs sessions with a remote API.

## Core Features

- Breathing session list — paginated, synced with remote API, locally persisted via Drift (SQLite)
- Active session screen — guided breathing phases (inhale / hold / exhale / rest) with a 4-component animation system
- Session constructor — create custom breathing exercises with configurable steps
- Authentication — Google Sign-In via Firebase Auth, JWT tokens with auto-refresh via Dio interceptor
- Onboarding — first-run flow for new users
- Deep link support — Firebase dynamic links via `app_links`

## Tech Stack

- **Language:** Dart 3.3+
- **Framework:** Flutter 3+ (iOS + Android targets)
- **Flavors:** `dev` (mind-mobile-dev Firebase project) and `prod` (mind-mobile Firebase project)
- **Local Database:** Drift 2.x (SQLite ORM with code generation)
- **HTTP Client:** Dio 5.x with `AuthInterceptor` for JWT attach + 401 handling
- **Presentation State:** Riverpod 2.x (`StateNotifier` + `ProviderScope`)
- **Domain State:** RxDart 0.28 (`BehaviorSubject`, typed event streams)
- **Navigation:** GoRouter 17.x with coordinator pattern for side-effects
- **Authentication:** Firebase Auth 6.x + Google Sign-In 7.x
- **DI:** Manual singleton via `App.shared` (`lib/Core/App.dart`)
- **Animations:** Custom `AnimationController` + `CustomPainter` (path morphing, physics-based motion)

## Architecture

See `.ai-factory/ARCHITECTURE.md` for detailed architecture guidelines.
Pattern: Layered Flutter Architecture with Domain/Module Boundary

Layered architecture with strict domain/module boundary:

```
Repository (Drift DB + Dio API)
    ↕
Notifier (domain state — RxDart BehaviorSubject, emits typed events)
    ↕
Service (bridges domain → module; converts domain models → DTOs)
    ↕   ← domain models stop here; DTOs cross this boundary
ViewModel (Riverpod StateNotifier — module boundary)
    ↕
Screen + Coordinator (UI + navigation/side-effects)
```

**Key rules:**
- Domain layer (Notifier + Repository) is pure Dart — no Flutter or Riverpod imports
- ViewModel is the module boundary — Service interface declared alongside the ViewModel
- DTOs are module-local; domain models never reach the ViewModel or Screen
- Navigation and side-effects belong in Coordinator classes, not ViewModels or Screens
- Notifiers emit typed events (e.g. `SessionCreated`, `SessionDeleted`)

## Module Structure

| Path | Purpose |
|------|---------|
| `lib/Core/` | `App` singleton, Drift database, Dio API client, routing, Firebase, auth interceptor |
| `lib/User/` | Auth state, login/logout, `UserNotifier`, `UserRepository`, login/onboarding screens |
| `lib/BreathModule/` | Full breathing feature — domain, repositories, notifiers, all presentation screens |
| `lib/Views/` | Shared UI components (snackbar, buttons, text fields) |

## Non-Functional Requirements

- Logging: Structured via `lib/Logger.dart`
- Error handling: `ApiException` model, typed notifier events for error propagation
- Security: JWT stored in `flutter_secure_storage`; auth interceptor handles token refresh + logout on 401
- Code generation: Drift schema uses `build_runner` — run after modifying `lib/Core/Database/Database.dart`
