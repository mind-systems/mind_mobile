# Plan: Fix `docs/home/suggestions-widget.md` line 27

## Context
The suggestions-widget doc references a deleted `LiveBreathSessionEnded` event as the source of `StatsInvalidated`. The actual source is now `ModuleSessionEnded` from `moduleStateChannel.events` in `HomeService.observeChanges()`.

## Settings
- Testing: no
- Logging: no
- Docs: yes (this milestone is a docs-only fix)

## Tasks

### Phase 1: Fix event source reference

- [x] **Task 1: Update StatsInvalidated event source on line 27**
  Files: `docs/home/suggestions-widget.md`
  On line 27, in the event table row for `StatsInvalidated`, replace the source text `Завершение живой сессии (`LiveBreathSessionEnded`)` with `Завершение сессии модуля (`ModuleSessionEnded` из `moduleStateChannel`)`. This matches the current implementation in `lib/HomeModule/HomeService.dart` lines 56-58 where `moduleStateChannel.events.where((e) => e is ModuleSessionEnded)` triggers the `StatsInvalidated` event.
