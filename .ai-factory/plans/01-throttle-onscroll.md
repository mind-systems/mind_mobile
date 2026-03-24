# Plan: Throttle `_onScroll`

## Context

The `_onScroll` listener in `BreathSessionListScreen` fires on every scroll pixel, calling `loadNextPage()` repeatedly even though the ViewModel guards against duplicate requests. Adding a throttle avoids unnecessary method calls and state reads during fast scrolling.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Throttle scroll handler

- [x] **Task 1: Add throttle to `_onScroll` in BreathSessionListScreen**
  Files: `packages/breath_module/lib/src/BreathSessionsList/BreathSessionListScreen.dart`
  Import `dart:async`. Add a `Timer? _scrollThrottleTimer` field to `_BreathSessionListViewState`. In `_onScroll`, if the timer is already active, return early. Otherwise, execute the existing threshold check + `loadNextPage()` call immediately, then start a `Timer` with a ~200ms duration that nulls itself on completion. This gives trailing-edge responsiveness (fires immediately on first scroll event, then suppresses for the cooldown window). Cancel the timer in `dispose()` before `_scrollController.dispose()`.
