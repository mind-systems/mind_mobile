# Project: Mind Mobile

## Overview

A Flutter mindfulness app for iOS and Android. Users create and run guided breathing sessions with animated visual feedback (shape morphing + physics-based motion). Supports Google Sign-In and passwordless email login, syncs sessions with a remote API.

## Core Features

- Home screen — module grid entry point; navigates to Breath and Coming Soon screens
- Breathing session list — paginated, synced with remote API, locally persisted via Drift (SQLite)
- Active session screen — guided breathing phases (inhale / hold / exhale / rest) with a 4-component animation system
- Session constructor — create custom breathing exercises with configurable steps
- Authentication — Google Sign-In (server auth code flow) and passwordless email (one-time code), JWT tokens with auto-refresh via gRPC interceptor
- Onboarding — first-run flow for new users
- Deep link support via `app_links`

## Tech Stack

- **Language:** Dart 3.11+
- **Framework:** Flutter 3+ (iOS + Android targets)
- **Flavors:** `dev` and `prod`
- **Local Database:** Drift 2.x (SQLite ORM with code generation)
- **gRPC Client:** grpc 5.x + protobuf 6.x for Protocol Buffer messaging
- **Presentation State:** Riverpod 2.x (`Notifier` class-based API + `NotifierProvider` + `ProviderScope`)
- **Domain State:** RxDart 0.28 (`BehaviorSubject`, typed event streams)
- **Navigation:** GoRouter 17.x with coordinator pattern for side-effects
- **Authentication:** Google Sign-In 7.x (server auth code → backend JWT exchange) + passwordless email OTP
- **DI:** Manual singleton via `App.shared` (`lib/Core/App.dart`)
- **Theming:** `AppTheme` (`lib/Core/AppTheme.dart`) — `ThemeMode.system`, dark + light themes
- **Animations:** Custom `AnimationController` + `CustomPainter` (path morphing, physics-based motion)

## Architecture

See `.ai-factory/ARCHITECTURE.md` for detailed architecture guidelines.
Pattern: Layered Flutter Architecture with Domain/Module Boundary

Layered architecture with strict domain/module boundary:

```
Repository (Drift DB + gRPC API)
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
| `lib/Core/` | `App` singleton, Drift database, GrpcClient, routing, Google Sign-In init, gRPC auth interceptor, sync engine |
| `lib/User/` | Auth state, login/logout, `UserNotifier`, `UserRepository`, login/onboarding screens |
| `lib/BreathModule/` | Breathing feature domain layer — notifiers, repositories, concrete services/coordinators that bridge domain → `packages/breath_module` |
| `lib/HomeModule/` | Home screen — module grid, suggestions carousel, session stats card |
| `lib/McpModule/` | Personal Access Tokens — `TokenNotifier`, token CRUD, MCP screen |
| `lib/ProfileModule/` | Profile screen — settings, theme/language, account management |
| `lib/Device/` | Device ping — `DeviceApi`, `DeviceRepository` |
| `lib/Bci/` | BCI domain abstraction — `IBciDeviceProvider` interface + domain models (`BciDeviceInfo`, `BciConnectionState`, `BciChannelQuality`, `BciCalibrationEvent`) |
| `packages/breath_module/` | Standalone package — all breathing presentation screens, ViewModels, service/coordinator interfaces, DTOs |
| `packages/mind_ui/` | Standalone package — shared UI components (buttons, snackbar, theme tokens) |
| `packages/mind_l10n/` | Standalone package — ARB files and generated `AppLocalizations` |

## Non-Functional Requirements

- Logging: Structured via `lib/Logger.dart`
- Error handling: `GrpcError` exceptions, typed notifier events for error propagation
- Security: JWT stored in `flutter_secure_storage`; gRPC auth interceptor handles token attach + logout on UNAUTHENTICATED (code 16)
- Code generation: Drift schema uses `build_runner` — run after modifying `lib/Core/Database/Database.dart`
