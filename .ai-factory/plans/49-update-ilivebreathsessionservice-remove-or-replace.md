# Plan: Update ILiveBreathSessionService — remove or replace

## Context

Milestones 45–48 deleted `ILiveBreathSessionService`, `LiveBreathSessionService`, `LiveBreathSessionCoordinator`, and `IBreathTelemetryService` from source code and rewired `BreathModule.dart` to use `BreathModuleStateChannel` directly. This milestone verifies the cleanup is complete and updates all documentation files that still reference the deleted interfaces — so they reflect the current `BreathModuleStateChannel` → `ModuleStateChannel` architecture.

## Settings
- Testing: no
- Logging: no
- Docs: yes (stale doc update only)

## Tasks

### Phase 1: Verify source cleanup

- [x] **Task 1: Verify no Dart source references to deleted interfaces**
  Files: `packages/breath_module/lib/breath_module.dart`, `lib/BreathModule/BreathModule.dart`
  Grep `lib/` and `packages/` for `ILiveBreathSessionService`, `LiveBreathSessionService`, `LiveBreathSessionCoordinator`, `IBreathTelemetryService`, `LiveBreathSessionDto`. Confirm zero matches. Confirm the barrel `packages/breath_module/lib/breath_module.dart` has no export lines for deleted files. Confirm `BreathModule.dart` creates `BreathModuleStateChannel` directly with no interface indirection. If any stale reference is found in Dart source, delete it.

### Phase 2: Update stale documentation

- [x] **Task 2: Rewrite live-session-tracking.md** (depends on Task 1)
  Files: `docs/socket/live-session-tracking.md`
  This file has pervasive stale references — rewrite all affected sections while keeping the language Russian to match the rest of the file:
  - **Line 26**: Replace "от UI до Socket.io" with "от UI до gRPC live stream" — Socket.io was removed in phase 3/6.
  - **Lines 28–33 (diagram)**: Replace the stale chain `LiveSessionCoordinator → ILiveBreathSessionService → LiveBreathSessionService → ModuleStateChannel` with the current architecture: `BreathModuleStateChannel` subscribes to `BreathViewModel.stream` and delegates lifecycle commands to `ModuleStateChannel`, telemetry samples to `BreathModuleInstructionStream`.
  - **Line 35 (paragraph below diagram)**: Rewrite to describe `BreathModuleStateChannel`'s behaviour: subscribes to `BreathSessionState`, translates status transitions to `channel.start/pause/unpause/end`, manages `liveSessionId` from channel state, holds pending telemetry until the ID arrives. Note that `BreathViewModel` has no knowledge of live session logic.
  - **Line 54**: Replace "LiveSessionCoordinator перехватывает обновления BreathSessionState" — rewrite to describe `BreathModuleStateChannel._handleTelemetry`: monitors phase/exerciseIndex changes from the state stream, sends samples via `BreathModuleInstructionStream`, and stashes pending telemetry if `liveSessionId` is not yet available.
  - **Lines 76–78**: Replace `SocketConnectionCoordinator` with `GrpcConnectionManager` and replace `LiveSessionNotifier` with `ModuleStateChannel` — describe that `GrpcConnectionManager` manages gRPC channel lifecycle (subscribes to `UserNotifier` for auth state, handles reconnection), and `ModuleStateChannel` receives server state updates including `liveSessionId`.
  - **Line 105 (See Also)**: Replace "LiveSocketService" reference with current infrastructure names (`GrpcConnectionManager` / `ModuleStateChannel`).

- [x] **Task 3: Update session-lifecycle.md** (depends on Task 1)
  Files: `docs/breath/session/session-lifecycle.md`
  Two stale references to `LiveSessionCoordinator` in the "Завершение сессии" section. Keep the language Russian.
  - **Line 7**: Replace "LiveSessionCoordinator" in the list of Riverpod subscribers with "BreathModuleStateChannel". Note: `BreathModuleStateChannel` subscribes to the ViewModel's state stream directly (not via Riverpod listener) — it is created in `BreathModule.buildSession()` and receives `vm.stream` in its constructor.
  - **Line 9**: Replace "LiveSessionCoordinator получает состояние со статусом complete и вызывает liveSessionService.endSession()" with a description of `BreathModuleStateChannel`: it detects the `complete` status from the state stream and calls `channel.end()` on `ModuleStateChannel`, which sends the `activity:end` event to the server via gRPC.

- [x] **Task 4: Update view-model.md LiveSessionCoordinator section** (depends on Task 1)
  Files: `docs/breath/session/view-model.md`
  Replace the "LiveSessionCoordinator" section (lines 64–66) that references `LiveSessionCoordinator` and `ILiveBreathSessionService`. Rewrite to explain that lifecycle tracking and telemetry are handled by `BreathModuleStateChannel`, which is created in `BreathModule.buildSession()` and subscribes to `BreathViewModel.stream` — the ViewModel has no knowledge of live session logic. Keep the language Russian.

- [x] **Task 5: Update vm.mmd diagram** (depends on Task 1)
  Files: `docs/breath/session/diagram/vm.mmd`
  Two changes — remove the `LiveSessionCoordinator` node and update the data flow:
  - **Line 38**: Remove the `LiveCoordinator` node (`LiveCoordinator["<b>LiveSessionCoordinator</b>..."`) entirely. Replace with a `StateChannel` node labeled "BreathModuleStateChannel" — note in the label that it subscribes to `BreathViewModel.stream` directly (not via Riverpod listener) and handles lifecycle + telemetry.
  - **Line 58**: Change the edge `RiverpodState -->|"Riverpod listener"| LiveCoordinator` to `BreathViewModel -->|"vm.stream (direct)"| StateChannel` — this reflects that `BreathModuleStateChannel` subscribes to the ViewModel's stream in its constructor, not through Riverpod.

- [x] **Task 6: Update module.mmd diagram** (depends on Task 1)
  Files: `docs/breath/session/diagram/module.mmd`
  Three changes to replace `LiveSessionCoordinator` with `BreathModuleStateChannel`:
  - **Line 59**: Replace the `LiveSessionCoordinator` node declaration with a `BreathModuleStateChannel` node. Update the description: subscribes to `BreathViewModel.stream`, delegates lifecycle to `ModuleStateChannel`, telemetry to `BreathModuleInstructionStream`, manages `liveSessionId` from channel state.
  - **Line 69**: In the `BreathSessionScreen` "creates" block, remove `LiveSessionCoordinator`. `BreathModuleStateChannel` is NOT created by the screen — it is created in `BreathModule.buildSession()` inside the provider factory. Either remove it from the screen's block or add a separate note showing it is created at the module assembly level.
  - **Line 91**: Change the edge `BreathViewModel -->|"Riverpod state"| LiveSessionCoordinator` to `BreathViewModel -->|"vm.stream (direct)"| BreathModuleStateChannel` — reflecting that it subscribes via constructor-injected stream, not Riverpod.

## Commit Plan
- **Commit 1** (after tasks 1–3): "Update live-session-tracking and session-lifecycle docs to reflect BreathModuleStateChannel"
- **Commit 2** (after tasks 4–6): "Update view-model docs and Mermaid diagrams to remove LiveSessionCoordinator"
