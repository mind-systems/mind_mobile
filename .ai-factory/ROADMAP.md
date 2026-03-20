# Mind Mobile — Roadmap

## Milestones

- [x] **Fix suggestions endpoint path** — change `/users/me/suggestions` → `/breath_sessions/suggestions` in `UserApi.fetchSuggestions()`
- [ ] **Route 401 handling through UserNotifier** — `LogoutNotifier` becomes a private channel; `GlobalListeners` moves to `UserNotifier.sessionExpiredStream`; no more broadcast to all subscribers on every 401; see [note](.ai-factory/notes/route-401-through-usernotifier.md)
- [ ] **Create HomeScreen Service layer** — add `IHomeService`, `HomeService`, `HomeViewModel`, DTOs, and state; follow ProfileModule pattern; guest-guard moves into Service; see [note](.ai-factory/notes/homescreen-service-layer.md)
- [ ] **Rewrite HomeScreen widgets to use ViewModel** — `SuggestionsCard` and `StatsCard` stop calling `App.shared` directly; watch `homeViewModelProvider` instead; `StatsCard` drops to `ConsumerWidget`; `HomeModule` wires everything via `ProviderScope` overrides

## Completed

| Milestone | Date |
|-----------|------|
| Personal Access Tokens | 2026-03-17 |
| Time-of-Day Suggestions Integration | 2026-03-19 |
| Time-of-Day Suggestions Widget UI | 2026-03-19 |
