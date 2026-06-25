# Источники тиков (тайминг-движок дыхательной сессии)

Стейт-машина дыхательной сессии управляется потоком тиков — каждый тик продвигает время вперёд на указанное в нём количество миллисекунд. Источник тиков абстрагирован за интерфейсом `ITickService`, что позволяет подменять его в тестах без изменения стейт-машины.

## Контракты

```
ITickService  — эмитит TickData(intervalMs); принадлежит BreathViewModel
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

Метроном на основе `Timer.periodic`, запускаемый через `simulateTick()`. Первый тик наступает через 1000 мс — нет мгновенного/prime-тика при старте.

### HeartRateTickService

```
TickSource.heartbeat → HeartRateTickService: свободный метроном со сглаженным периодом
```

Тикает как свободный метроном с периодом, равным скользящему среднему (SMA) последних RR-интервалов, которое вычисляет `SmoothedRrSource`. Реальные удары сердца **не** порождают тики — они только обновляют период и сбрасывают таймер паузы. Это исключает двойной счёт: поздно прибывший удар не накладывается на уже выбитый метрономом тик.

**Окно паузы (grace window):** если ни один реальный удар не поступил в течение 10 секунд, `HeartRateTickService` снимает флаг активности — `SwitchableTickService` реагирует и автоматически откатывается на `ClockTickService`. Откат односторонний: вернуться к источнику сердечного ритма можно только вручную. Метроном при этом не останавливается — он продолжает работать на последнем известном периоде, чтобы при восстановлении сенсора каденс подхватился без паузы.

**Холодный старт:** до получения первого реального удара метроном работает с заглушкой 1000 мс, но `hasActiveSource` остаётся `false` — `trySwitchTo(heartbeat)` до первого удара отклоняется. Поведение совпадает с предыдущей реализацией.

Подробнее о слое сглаживания: [docs/biometrics/active-rr-source.md](../../biometrics/active-rr-source.md).

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
