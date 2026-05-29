# Источники тиков (тайминг-движок дыхательной сессии)

Стейт-машина дыхательной сессии управляется потоком тиков — каждый тик продвигает время вперёд на указанное в нём количество миллисекунд. Источник тиков абстрагирован за интерфейсом `ITickService`, что позволяет подменять его в тестах без изменения стейт-машины.

## Контракты

```
ITickService  — эмитит TickData(durationMs); принадлежит BreathViewModel
               source: TickSource  — идентификатор активного источника
               sourceChanges: Stream<TickSource>  — единая точка синхронизации смены источника
               trySwitchTo(TickSource): bool  — запрос на переключение; false если источник недоступен
```

`TickSource` — перечисление: `timer` (таймер) и `heartbeat` (сердечный ритм). Текущее значение хранится в `BreathSessionState.tickSource` и используется в `BreathSoundCoordinator` для выбора звука тика.

## Реализации

### ClockTickService

```
TickSource.timer → ClockTickService: Timer.periodic(1000 мс)
```

Метроном на основе `Timer.periodic`. Первый тик вызывается немедленно через `simulateTick()` для инициализации начального состояния стейт-машины.

### HeartRateTickService

```
TickSource.heartbeat → HeartRateTickService: подписка на ActiveRrSource.stream
```

Подписывается на `ActiveRrSource.stream` и превращает каждый RR-интервал в `TickData(rr.intervalMs)`. Один RR-интервал — один тик. Жизненный цикл: создаётся при старте сессии и уничтожается вместе с ViewModel; вышестоящий `ActiveRrSource` — синглтон уровня приложения.

Подробнее об источнике RR-интервалов: [docs/biometrics/active-rr-source.md](../../biometrics/active-rr-source.md).

### SwitchableTickService

Фасад, владеющий обоими источниками. Активный источник по умолчанию — `TickSource.timer`. Инжектируется в `BreathViewModel` как `ITickService`.

```
SwitchableTickService
  ├─ ClockTickService    (дочерний, всегда создан)
  └─ HeartRateTickService (дочерний, всегда создан)
```

Ключевые свойства:
- `trySwitchTo(target)` — ручное переключение источника; возвращает `false` если запрошенный источник недоступен (нет активного кардио-сигнала).
- `sourceChanges: Stream<TickSource>` — единая точка синхронизации для ручного переключения и автоматического откатa.
- `dispose()` — уничтожает обоих дочерних.

## Переключение источника

### Ручное переключение

Кнопка-сердце в `SessionBottomBar.leadingActions` вызывает `viewModel.toggleHeartTickSource()`. ViewModel вызывает `tickService.trySwitchTo(target)`. Если переключение недоступно (нет активного RR-источника) — возвращается `false` и генерируется `BreathSessionUiEvent.noCardioSource`, что приводит к показу `AppAlert` «Подключите датчик сердца».

### Автоматический откат

Когда все RR-источники замолкают (сигнал пропал), `SwitchableTickService` автоматически переключается обратно на таймер и публикует новое значение в `sourceChanges`.

### Единая точка синхронизации

`BreathViewModel` подписывается на `tickService.sourceChanges` и записывает полученное значение в `BreathSessionState.tickSource`. Метод `toggleHeartTickSource()` **не** пишет `tickSource` напрямую — это гарантирует, что и ручное переключение, и автоматический откат отражаются в состоянии через один и тот же канал.

## Границы владения

```
BreathModule.buildSession()
  ├─ ClockTickService    создаётся здесь
  ├─ HeartRateTickService создаётся здесь
  └─ SwitchableTickService(clock, heart) — владеет dispose() обоих; инжектируется в BreathViewModel

BreathViewModel
  └─ tickService.tickStream → BreathSessionStateMachine (каждый тик продвигает фазу)
  └─ tickService.sourceChanges → BreathSessionState.tickSource (единая точка)
  └─ tickService.dispose() вызывается при ref.onDispose
```

`BreathViewModel` не управляет жизненным циклом источника тиков: он получает готовый экземпляр `ITickService` и вызывает `dispose()` при уничтожении.
