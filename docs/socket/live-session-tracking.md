# Трекинг жизненного цикла активности

Мобильное приложение отправляет на сервер два типа сигналов: lifecycle-события (`activity:start`, `activity:pause`, `activity:resume`, `activity:end`) и сэмплы телеметрии фаз дыхания. Lifecycle-события создают временну́ю рамку — когда именно пользователь работал. Телеметрия заполняет эту рамку содержимым — что в каждый момент происходило на экране. Вместе они образуют инструкционный лог сессии, без которого биометрические данные датчиков теряют контекст: числа есть, но неизвестно, что в этот момент говорило приложение.

## Жизненный цикл активности

Активность привязана к действиям пользователя, а не к навигации. Открытие экрана сессии не создаёт активность.

```
idle ──(activity:start)──▶ active ──(activity:pause)──▶ paused
                              ▲                               │
                              └───────(activity:resume)───────┘
                              │
                         (activity:end)
                              │
                              ▼
                            idle
```

`activity:start` отправляется в момент первого нажатия Play. Сервер фиксирует `startedAt` именно по этому событию, и от точности этой метки зависит корректность time-join с биометрическими данными.

`activity:pause` и `activity:resume` отправляются синхронно с паузой анимационного движка — пользователь нажал паузу, и оба слоя (визуальный и серверный) реагируют на одно и то же действие. `activity:end` уходит при завершении последнего упражнения, когда `BreathSessionStateMachine` вызывает `complete`.

## Слои реализации

Вызов проходит через всю цепочку от UI до gRPC live stream:

```
BreathModuleStateChannel
  ├─▶ ModuleStateChannel  ──▶  gRPC live stream  (lifecycle-команды)
  └─▶ BreathModuleInstructionStream              (телеметрия фаз)
```

`BreathModuleStateChannel` подписывается на `BreathViewModel.stream` напрямую в своём конструкторе — не через Riverpod-слушатель. Он создаётся в `BreathModule.buildSession()` в момент сборки провайдера ViewModel, получает `vm.stream` и `App.shared.moduleStateChannel` при создании, и держит их в течение всего жизненного цикла экрана. `BreathViewModel` не содержит никакой логики работы с lifecycle или телеметрией.

При первом переходе из паузы в `breath`/`rest` (если сессия ещё не запускалась) `BreathModuleStateChannel` вызывает `channel.start(type: breath, refId: sessionId)`. При последующих переходах `pause → breath/rest` он вызывает `channel.unpause()`. При переходе `breath/rest → pause` — `channel.pause()`. При статусе `complete` — `channel.end()`. Все переходы идемпотентны: флаги `_started` и `_ended` гарантируют, что каждая lifecycle-команда отправляется ровно один раз.

`ModuleStateChannel` — это доменная стейт-машина, которая хранит `ModuleState` (`status: idle | active`, `isPaused`, `liveSessionId`). Он держит pending-флаги (`_isPendingStart`, `_isPendingPause`) — защита от двойного emit при случайном двойном вызове. Канал эмитирует типизированные события: `ModuleSessionStarted`, `ModuleSessionPaused`, `ModuleSessionUnpaused`, `ModuleSessionEnded`, `ModuleSessionAbandoned`. При логауте он автоматически сбрасывается в idle.

`ModuleStateChannel` управляет gRPC-соединением с live stream. Он отправляет `activity:*`-команды и получает ответ `session:state` — в нём сервер возвращает `liveSessionId`, который канал сохраняет в своём состоянии. Именно `liveSessionId` используется как ключ для всех последующих обращений: телеметрия, переподключение, будущая биометрия.

## Телеметрия фаз дыхания

Каждая смена фазы дыхания во время активной сессии порождает сэмпл, который уходит через namespace `/telemetry`:

```json
{
  "sessionId": "uuid",
  "phase": "exhale",
  "durationMs": 6000,
  "timestamp": 1710532800000
}
```

`BreathModuleStateChannel._handleTelemetry` перехватывает обновления `BreathSessionState`. Если `state.phase` или `state.exerciseIndex` изменились и сессия активна, он вызывает `_instructionStream.sendSample(liveId, phase, durationMs)`. Timestamp выставляется на клиенте — это момент выдачи инструкции, то есть когда движок перешёл в эту фазу.

Если `liveSessionId` ещё не пришёл от сервера (ответ на `activity:start` не вернулся), сэмпл сохраняется в `_pendingTelemetry`. Как только `ModuleStateChannel` получает `liveSessionId` от сервера, `BreathModuleStateChannel` сбрасывает накопленный pending-сэмпл через `_flushPending`.

Когда сессия поставлена на паузу, `TelemetryGateway` на сервере блокирует входящие сэмплы `breath_phase` и возвращает `data:ack { error: 'session_paused' }`. Lifecycle-события (`paused`, `resumed`) при этом проходят всегда — они пишутся сервером самостоятельно при обработке `activity:pause` и `activity:resume`. В результате за маркером `paused` возникает чистый пробел в сэмплах, а маркер `resumed` его закрывает. Когда придут биометрические данные, этот пробел будет точно соответствовать времени паузы.

## Буферизация и обратное давление

`BreathModuleInstructionStream` не отправляет сэмплы напрямую — между ним и gRPC-каналом стоит `InstructionBuffer`, кольцевой буфер на 500 сэмплов. Если соединение оборвалось, сэмплы накапливаются в буфере. Когда сокет восстанавливается, буфер сбрасывается полностью. Если буфер переполнился до переподключения, новые сэмплы вытесняют старые, а счётчик `droppedCount` фиксирует потери.

Сервер управляет частотой через `data:ack`:

```json
{
  "receivedCount": 10,
  "droppedCount": 0,
  "maxSamplesPerSecond": 5
}
```

Клиент обязан соблюдать `maxSamplesPerSecond`. Для фаз дыхания это некритично — фаза меняется раз в несколько секунд. Но механизм уже реализован: когда появятся высокочастотные биометрические потоки (например, 256 Hz ЭЭГ), они пройдут через ту же инфраструктуру с той же логикой обратного давления.

## Подключение и переподключение

`GrpcConnectionManager` управляет жизненным циклом gRPC-канала. Он подписан на `UserNotifier`: когда пользователь аутентифицирован, соединение устанавливается; при логауте — разрывается. Параллельно он слушает состояние сети через Connectivity plugin и автоматически переподключается при восстановлении интернета.

Сервер держит grace period (по умолчанию 30 секунд) после обрыва соединения. Если переподключение произошло в этом окне, сессия продолжается — сервер отвечает `session:state { resumed: true }` и возвращает тот же `liveSessionId`. `ModuleStateChannel` получает обновлённое состояние и продолжает работу. Если grace period истёк, сервер закрывает сессию со статусом `abandoned`, и при следующем `activity:start` создаётся новая.

## Связь с биометрическими данными

Телеметрия — это инструкционный лог, а не самостоятельные биометрические данные. Две временны́е шкалы хранятся раздельно:

```
Шкала сессии (телеметрия / инструкции)
──────────────────────────────────────
session_started → breath_phase → … → paused → resumed → … → session_ended

Биометрическая шкала (будущее)
──────────────────────────────
HR → HR → SpO2 → respiration → …
```

Обе шкалы привязаны к одному `liveSessionId`. Аналитика выполняет time-join по `sessionId + timestamp`:

```
T+6000ms: инструкция — exhale 6s
T+6000–T+12000ms: биосигнал дыхания → совпадает ли реальный паттерн?
```

Это позволит давать пользователю объективный фидбэк — насколько его реальное дыхание соответствовало инструкции в каждой фазе. Будущие биометрические потоки пойдут через отдельный namespace `/biometric` и отдельную таблицу, но будут привязываться к той же `LiveSession` по `sessionId`. Подробнее о модели данных на стороне сервера — в `telemetry-model.md` в репозитории API.

## See Also

- [Sync Engine](../core/sync-engine.md) — синхронизация данных через `sync:changed` события
- [session-lifecycle.md](../breath/session/session-lifecycle.md) — завершение сессии, рестарт и режим ожидания
- [view-model.md](../breath/session/view-model.md) — BreathSessionStateMachine и BreathViewModel
- [notifier-pattern.md](../core/notifier-pattern.md) — паттерн нотификатора и типизированные события
