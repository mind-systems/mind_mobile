!TBD!

# Источники тиков (тайминг-движок дыхательной сессии)

Стейт-машина дыхательной сессии управляется потоком тиков — каждый тик продвигает время вперёд на указанное в нём количество миллисекунд. Источник тиков хранится в модели сессии и может быть переключён прямо в процессе выполнения.

## Контракты

```
ITickService          — эмитит TickData(durationMs); принадлежит BreathViewModel
ITickServiceFactory   — создаёт ITickService по TickSourceType; инжектируется в BreathViewModel
BLEDeviceManager      — управляет жизненным циклом BLE-соединения; живёт в App.shared
```

## Типы источников тиков

```
TickSourceType.clock      → ClockTickService: Timer.periodic(1000 мс)
TickSourceType.heartRate  → HeartRateTickService: подписывается на поток BLEDeviceManager,
                            разбирает RR-интервалы (мс между ударами);
                            если устройство не отдаёт RR-интервалы — рассчитывает по формуле 60000/bpm
```

## Границы владения

```
App.shared
  └─ BLEDeviceManager
       ├─ сканирование / подключение / переподключение / сохранение устройства
       └─ Stream<HRPacket>  ← всегда активен при подключённом устройстве

BreathModule.buildSession()
  └─ ITickServiceFactory инжектируется в BreathViewModel

BreathViewModel._setupEngine(dto)
  ├─ уничтожает предыдущий ITickService
  ├─ factory.create(dto.tickSource)  → новый ITickService
  └─ HeartRateTickService только подписывается на поток BLEDeviceManager
     — он НЕ владеет BLE-соединением; dispose() отменяет только подписку
```

## Переключение источника тиков во время сессии

Пользователь может переключить источник тиков прямо в экране сессии. Это запускает мутацию в домене (сохраняется в БД), нотифайер эмитит `SessionUpdated`, `BreathViewModel` получает его через `service.observeSession()` и вызывает `_setupEngine(dto)` — который уничтожает старый `ITickService` и создаёт новый через фабрику. Отдельный механизм для этого не нужен.

## Потеря BLE-сигнала в середине сессии

Когда BLE-устройство выходит из зоны покрытия, `HeartRateTickService` перестаёт получать пакеты. Рекомендуемое поведение — автоматический переход на тактовый источник с индикатором в UI. Стейт-машина никогда не ставится на паузу из-за потери сигнала. Это решение на уровне UX; домен о состоянии соединения не знает.
