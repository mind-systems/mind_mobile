# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run (dev flavor)
flutter run --flavor dev -t lib/main_dev.dart

# Run (prod flavor)
flutter run --flavor prod -t lib/main_prod.dart

# Build APK
flutter build apk --flavor dev -t lib/main_dev.dart --release
flutter build apk --flavor prod -t lib/main_prod.dart --release

# Run tests
flutter test

# Regenerate Drift ORM code (after modifying database schema)
flutter pub run build_runner build
```

### First-time setup
1. `cp lib/Core/Environment.example.dart lib/Core/Environment.dart` and fill in values (API URLs, Google client IDs)
2. Create Android keystores and configure `keystore.properties`

## Architecture

The app uses a layered architecture with **RxDart** for domain state and **Riverpod** for presentation state.

```
Repository (Drift DB + Dio API)
    ↕
Notifier (domain state — RxDart BehaviorSubject, emits typed events)
    ↕
Service (implements interface declared at the module boundary; maps domain models → DTOs)
    ↕        ← domain model stops here; DTOs cross this boundary
ViewModel (Riverpod StateNotifier — module boundary, transforms DTOs for UI)
    ↕
Screen + Coordinator (UI + navigation/side-effects)
```

**Key principles**:
- UI never touches repositories or notifiers directly.
- The **ViewModel is the module boundary** — everything from ViewModel inward could be extracted into its own package. The Service interface is declared on this side of the boundary.
- **Domain models do not leak into the module.** The Service converts domain models to DTOs before passing them to the ViewModel, so the module depends only on its own DTOs and the Service interface.
- The Service implements an interface defined at the module boundary, keeping the module decoupled from concrete domain implementations.

### Dependency Injection

DI is manual via `App.shared` singleton (`lib/Core/App.dart`). See `.ai-factory/ARCHITECTURE.md` (DI Wiring section) for initialization order and wiring details.

### Module structure

| Path | Purpose |
|------|---------|
| `lib/Core/` | App singleton, Database (Drift ORM + DAO interfaces), HttpClient (Dio), routing, environment config |
| `lib/User/` | Auth state, login/logout, UserNotifier, UserRepository, IAuthApi |
| `lib/BreathModule/` | Breathing session domain — models, repositories, notifiers, all presentation screens |
| `lib/Views/` | Shared UI components (snackbar, buttons, text fields) |

### BreathModule internals

The breathing session feature has its own layered sub-structure under `lib/BreathModule/`:

- **`Core/BreathSessionNotifier.dart`** — domain notifier with pagination, CRUD, and typed event emission
- **`Presentation/BreathSessionsList/`** — list screen with coordinator, ViewModel, and presentation DTOs
- **`Presentation/BreathSession/`** — active session screen with 4-component animation system:
  - `BreathSessionStateMachine` — state machine for breathing phases (inhale / hold / exhale / rest)
  - `BreathMotionEngine` — physics-based position animation
  - `BreathShapeShifter` — path morphing between shapes (circle / square / triangle)
  - `BreathAnimationCoordinator` — orchestrates motion + shape components

### Routing

GoRouter is configured in `lib/router.dart`. Routes:

| Route | Screen |
|-------|--------|
| `/` | `BreathSessionListScreen` (initial route) |
| `/onboarding` | `OnboardingScreen` |
| `/login` | `LoginScreen` |
| `/breath/:sessionId` | `BreathSessionScreen` |
| `/constructor` | `BreathSessionConstructorScreen` |

### Authentication flow

- Two login methods: **Google Sign-In** (server auth code flow) and **passwordless email** (one-time code via deep link)
- `AuthInterceptor` (`lib/Core/Api/AuthInterceptor.dart`) attaches JWT tokens and handles 401 responses
- On 401, it publishes to `LogoutNotifier` stream, which `GlobalListeners` catches to trigger logout
- `UserNotifier` manages `AuthenticatedState` / `GuestState`

## Patterns to follow

- **Notifiers emit typed events** — prefer adding event types (e.g., `SessionCreated`, `SessionDeleted`) over ad-hoc stream triggers. See `docs/core/notifier-pattern.md`.
- **Coordinator pattern** — navigation and side effects live in a coordinator class, not the ViewModel or screen. See existing coordinators in `lib/BreathModule/Presentation/BreathSessionsList/`.
- **Service interface at module boundary** — the Service interface is declared in the module (alongside the ViewModel), not in the domain. The concrete Service implements it and bridges domain → module via DTO conversion.
- **DTOs at the domain/module boundary** — domain models are converted to DTOs by the Service before crossing into the module. The ViewModel and everything inside the module work only with DTOs, never with raw domain models.
- **Domain layer is pure Dart** — no Flutter or Riverpod imports in `Notifier` or `Repository` classes.

## Documentation

Detailed docs and Mermaid architecture diagrams live in `docs/`:
- `docs/core/notifier-pattern.md` — Notifier pattern explanation
- `docs/core/jwt-authentication.md` — JWT token lifecycle
- `docs/core/global-listeners.md` — Global event listener system
- `docs/core/theming.md` — Theme tokens, color palette, usage rules
- `docs/core/alerts-and-snackbars.md` — When to use AppAlert vs SnackBar
- `docs/breath/session/view-model.md` — BreathSessionStateMachine and BreathViewModel behaviour
- `docs/breath/session/session-lifecycle.md` — session completion, idle state, and restart flow
- `docs/breath/session/orb-animation.md` — OrbAnimationCoordinator and orb scaling
- `docs/breath/session/shape-morph-animation.md` — BreathShapeShifter path morphing
- `docs/breath/session/diagram/` — Mermaid diagrams (SVGs auto-generated by GitHub Actions)

## Mermaid diagrams

Diagrams live in `docs/breath/session/diagram/`. SVGs are auto-generated by GitHub Actions.

**Known pitfalls when editing `.mmd` files:**
- Do not use JavaScript reserved words as node IDs — `constructor` causes `Cannot set properties of undefined (setting 'order')`. Prefix with context: `smInit`, `fnPause`, etc.
- `pause`, `resume`, `complete` are also unsafe as node IDs — prefix them too.
- `text-align` is not supported in inline `style` directives.
- Long box-drawing separator lines (`─────────────`) break the parser — use `<br/>` instead. Short `───` (3 chars) is fine.
