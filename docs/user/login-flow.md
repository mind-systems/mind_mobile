# Login Flow

Логин возможен двумя способами: Google Sign-In и passwordless email. Оба пути идут через `UserNotifier` и завершаются одинаково: `AuthenticatedState` эмитится в поток, `LoginViewModel` вызывает `onAuthenticatedEvent`, экран попает себя с `AuthResult.success`.

## Google Sign-In

Пользователь нажимает кнопку на `OnboardingScreen`. `UserNotifier` показывает нативный пикер аккаунта — `authInProgress` на этом этапе ещё не поднят. После выбора аккаунта флаг поднимается и начинается запрос к API. Оба экрана (`OnboardingScreen` и `LoginScreen`) показывают оверлей через `isLoginInProgress` из `LoginState`, который синхронизируется с `UserNotifier.authInProgressStream` в конструкторе `LoginViewModel`.

## Email (passwordless)

Пользователь вводит адрес на `LoginScreen`. `LoginViewModel` управляет `isLoading` вручную — это просто отправка запроса, не аутентификация. Сам логин происходит позже: пользователь переходит по ссылке из письма, диплинк прилетает в `DeeplinkRouter` → `AuthCodeDeeplinkHandler` → `UserNotifier.completePasswordlessSignIn`. С этого момента `authInProgress` поднимается и поведение идентично Google-пути.

## Навигация после логина

`OnboardingScreen` и `LoginScreen` — модальные экраны. Они не навигируют сами — попают себя с `AuthResult.success`. Координатор ждёт результат через `context.push<AuthResult>(...).then(...)` и пушит нужный экран. Подробнее — в [Auth-Gated Navigation](../core/auth-gated-navigation.md).

При email-логине стек может быть `[..., Onboarding, Login]`. Оба экрана слушают один `AuthState` stream и попают себя независимо — стек разматывается корректно.

## Ошибки

Если аутентификация через диплинк падает, `UserNotifier` публикует сообщение в `authErrorStream`, `GlobalListeners` показывает снэкбар — даже если экран входа уже закрыт.

## See Also

- [Auth-Gated Navigation](../core/auth-gated-navigation.md) — паттерн `AuthResult` + `context.push(...).then(...)`
- [JWT Authentication](jwt-authentication.md) — токены, AuthInterceptor, logout по 401
- [Global Listeners](../core/global-listeners.md) — как `authErrorStream` доходит до UI
