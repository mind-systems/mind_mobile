# Login Flow

Логин возможен двумя способами: Google Sign-In и passwordless email. Оба пути идут через `UserNotifier` и завершаются одинаково: `AuthenticatedState` эмитится в поток, `LoginViewModel` вызывает `onAuthenticatedEvent`, экран попает себя с `AuthResult.success`.

## Google Sign-In

Пользователь нажимает кнопку на `OnboardingScreen`. `UserNotifier` показывает нативный пикер аккаунта — `authInProgress` на этом этапе ещё не поднят. После выбора аккаунта флаг поднимается и начинается запрос к API. Оба экрана (`OnboardingScreen` и `LoginScreen`) показывают оверлей через `isLoginInProgress` из `LoginState`, который синхронизируется с `UserNotifier.authInProgressStream` в конструкторе `LoginViewModel`.

### Fallback на браузерный флоу

`GoogleAuthProvider.getServerAuthCode()` работает в два режима:

1. **GMS-флоу** (`_gmsFlow`) — нативный пикер аккаунта через `GoogleSignIn`. Возвращает `serverAuthCode` без `redirectUri`. Используется по умолчанию.
2. **Browser-флоу** (`_browserFlow`) — браузерный OAuth через `flutter_web_auth_2`. Используется как fallback, если GMS недоступен (нет Google Play Services, `MissingPluginException`, прочие ошибки платформы). Открывает `accounts.google.com` и перехватывает callback на `{deeplinkUrl}/auth/google/callback`. Возвращает код вместе с `redirectUri`.

Если пользователь отменяет в любом из флоу — выбрасывается `GoogleSignInCanceledException`, логин прерывается без ошибки.

`redirectUri` включается в запрос к бэкенду (`GoogleAuthRequest`) только при browser-флоу (в GMS-флоу это поле `null`). Бэкенд использует его для завершения обмена кода на токен.

## Email (passwordless)

Пользователь вводит адрес на `LoginScreen`. `LoginViewModel` управляет `isLoading` вручную — это просто отправка запроса, не аутентификация. Сам логин происходит позже: пользователь переходит по ссылке из письма, диплинк прилетает в `DeeplinkRouter` → `AuthCodeDeeplinkHandler` → `UserNotifier.completePasswordlessSignIn`. С этого момента `authInProgress` поднимается и поведение идентично Google-пути.

## Навигация после логина

`OnboardingScreen` и `LoginScreen` — модальные экраны. Они не навигируют сами — попают себя с `AuthResult.success`. Координатор ждёт результат через `context.push<AuthResult>(...).then(...)` и пушит нужный экран. Подробнее — в [Auth-Gated Navigation](../core/auth-gated-navigation.md).

При email-логине стек может быть `[..., Onboarding, Login]`. Оба экрана слушают один `AuthState` stream и попают себя независимо — стек разматывается корректно.

## Ошибки

Если аутентификация через диплинк падает, `AuthCodeDeeplinkHandler` показывает локализованный снэкбар напрямую через `rootScaffoldMessengerKey` — даже если экран входа уже закрыт. При превышении лимита попыток (`OtpLockedException`) отображается `loginTooManyAttemptsError`; для любой другой ошибки (истёкшая или уже использованная ссылка) — `loginCodeInvalidError`.
