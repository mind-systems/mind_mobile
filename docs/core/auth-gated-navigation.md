# Auth-Gated Navigation

Паттерн для случаев, когда гость пытается выполнить действие, требующее авторизации. Онбординг открывается как модальный экран и возвращает типизированный результат вызывающему коду — координатор сам решает, что делать дальше.

## AuthResult

```dart
enum AuthResult { success, cancelled }
```

`OnboardingScreen` и `LoginScreen` попают себя с `AuthResult.success` после успешной аутентификации. Если пользователь закрывает экран без логина — GoRouter возвращает `null`.

## Как использовать

### Навигация после логина

```dart
void openProfile() {
  final authState = App.shared.userNotifier.currentState;
  if (authState is GuestState) {
    context.push<AuthResult>(OnboardingScreen.path).then((result) {
      if (result == AuthResult.success && context.mounted) {
        context.push(ProfileScreen.path);
      }
    });
  } else {
    context.push(ProfileScreen.path);
  }
}
```

Стек до и после:

```
До:    [Home] → push → [Home, Onboarding] → pop(success) → [Home] → push → [Home, Profile]
После: Back из Profile возвращает на Home ✓
```

### Side effect без навигации

```dart
context.push<AuthResult>(OnboardingScreen.path).then((result) {
  if (result == AuthResult.success) viewModel.starExercise(exerciseId);
});
```

## Почему не context.go с returnPath

`context.go()` заменяет весь стек — `[Home, Onboarding]` → `go('/profile')` → `[Profile]`. Home уничтожен, кнопка Back из Profile ведёт в никуда.

`context.push(...).then(...)` сохраняет стек: онбординг попает себя, Home жив, координатор пушит Profile поверх.

## Двойной pop при email-логине

`OnboardingScreen` открывает `LoginScreen` через `context.push`. Итоговый стек: `[..., Onboarding, Login]`. Оба экрана имеют независимые ViewModels, оба слушают `AuthState` stream. Когда `AuthenticatedState` эмитится:

1. `LoginScreen` получает событие → `context.pop(AuthResult.success)` → стек: `[..., Onboarding]`
2. `OnboardingScreen` получает то же событие → `context.pop(AuthResult.success)` → стек: `[...]`

Каждый экран попает только себя. `push<AuthResult>` в координаторе резолвится с результатом последнего pop из Onboarding.

## See Also

- [Login Flow](../user/login-flow.md) — детали Google и email аутентификации
- [Global Listeners](global-listeners.md) — обработка ошибок через authErrorStream
