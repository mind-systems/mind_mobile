# Источники тиков (тайминг-движок дыхательной сессии)

Стейт-машина дыхательной сессии управляется потоком тиков — каждый тик продвигает время вперёд на указанное в нём количество миллисекунд. Источник тиков абстрагирован за интерфейсом `ITickService`, что позволяет подменять его в тестах без изменения стейт-машины.

## Контракты

```
ITickService  — эмитит TickData(durationMs); принадлежит BreathViewModel
               source: TickSource  — идентификатор источника, передаётся в BreathSessionState
```

`TickSource` — перечисление: `timer` (таймер) и `heartbeat` (сердечный ритм). Текущее значение хранится в `BreathSessionState.tickSource` и используется в `BreathSoundCoordinator` для выбора звука тика.

## Текущая реализация

Единственная реализованная реализация — `ClockTickService`:

```
TickSource.timer → ClockTickService: Timer.periodic(1000 мс)
```

`ClockTickService` создаётся в `BreathModule.buildSession()` и передаётся в `BreathViewModel` через конструктор. Первый тик вызывается немедленно через `simulateTick()` для инициализации начального состояния стейт-машины.

## Границы владения

```
BreathModule.buildSession()
  └─ ClockTickService создаётся здесь и инжектируется в BreathViewModel

BreathViewModel
  └─ tickService.ticks → BreathSessionStateMachine (каждый тик продвигает фазу)
  └─ tickService.source → BreathSessionState.tickSource (стабильно на протяжении сессии)
  └─ tickService.dispose() вызывается при ref.onDispose
```

`BreathViewModel` не управляет жизненным циклом источника тиков: он получает готовый экземпляр `ITickService` и вызывает `dispose()` при уничтожении.
