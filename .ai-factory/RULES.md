# Project Rules

> Short, actionable rules and conventions for this project. Loaded automatically by /aif-implement.

## Rules

- Services must be stateless — no `StreamController`, no `StreamSubscription`, no `dispose()`. `observeChanges()` must return a derived stream directly from the notifier (e.g. `notifier.stream.expand(...)`); Riverpod manages the subscription lifecycle via `ref.onDispose` in the ViewModel.
- Never add module-specific state, streams, or triggers to App.dart — App.dart is infrastructure only (DB, HTTP, notifiers, sync). Module concerns belong in the module's Service or coordinator.
