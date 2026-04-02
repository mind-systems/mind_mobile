# Трекинг жизненного цикла активности

Мобильное приложение отправляет на сервер два типа сигналов: lifecycle-команды (`activity:start/pause/resume/end`) и сэмплы инструкций. Lifecycle-команды создают временну́ю рамку — когда именно пользователь работал. Инструкции заполняют эту рамку содержимым — что в каждый момент показывало приложение. Вместе они образуют инструкционный лог сессии, без которого биометрические данные датчиков теряют контекст.

## Жизненный цикл активности

Активность привязана к действиям пользователя, а не к навигации. Открытие экрана сессии не создаёт активность.

```
idle ──(activity:start)──▶ active ──(activity:pause)──▶ paused
                               ▲                              │
                               └──────(activity:resume)───────┘
                               │
                          (activity:end)
                               │
                               ▼
                             idle
```

`activity:start` отправляется в момент первого нажатия Play. Сервер фиксирует `startedAt` именно по этому событию, и от точности этой метки зависит корректность time-join с биометрическими данными.

## Слои реализации

```
BreathModuleStateChannel
  ├─▶ ModuleStateChannel        ──▶  gRPC ModuleStateService    (lifecycle-команды)
  └─▶ BreathModuleInstructionStream ──▶  gRPC ModuleInstructionService  (инструкции фаз)
```

Полная цепь от нажатия Play до записи в базу — [e2e-flow.mmd](e2e-flow.mmd).

`BreathModuleStateChannel` подписывается на `BreathViewModel.stream` напрямую в конструкторе — не через Riverpod-слушатель. Создаётся в `BreathModule.buildSession()`, получает `vm.stream` и `App.shared.moduleStateChannel` при создании и держит их весь жизненный цикл экрана. `BreathViewModel` не содержит никакой логики работы с lifecycle или инструкциями.

При первом переходе из паузы в `breath`/`rest` (если сессия ещё не запускалась) `BreathModuleStateChannel` вызывает `channel.start(type: breath, refId: sessionId)`. При последующих `pause → breath/rest` — `channel.unpause()`. При `breath/rest → pause` — `channel.pause()`. При статусе `complete` — `channel.end()`. Флаги `_started` и `_ended` гарантируют, что каждая команда отправляется ровно один раз.

`ModuleStateChannel` — доменная стейт-машина: хранит `ModuleState` (`status: idle | active`, `isPaused`, `moduleSessionId`), держит pending-флаги (`_isPendingStart`, `_isPendingPause`) и эмитирует типизированные события: `ModuleSessionStarted`, `ModuleSessionPaused`, `ModuleSessionUnpaused`, `ModuleSessionEnded`, `ModuleSessionAbandoned`. При логауте автоматически сбрасывается в idle.

`moduleSessionId` приходит от сервера в ответе `session:state` после `activity:start`. Это корреляционный ключ — под ним записываются все инструкции и в будущем биометрия.

## Инструкции фаз дыхания

Каждая смена фазы во время активной сессии порождает сэмпл:

```json
{
  "session_id": "uuid",
  "module_id": "breath",
  "instruction_type": "breath_phase",
  "data": { "phase": "exhale", "durationMs": 6000 },
  "timestamp": 1710532800000
}
```

`BreathModuleStateChannel._handleInstruction` перехватывает обновления `BreathSessionState`. Если `state.phase` или `state.exerciseIndex` изменились и сессия активна — вызывает `_instructionStream.sendSample(sessionId, phase, durationMs)`. Timestamp выставляется на клиенте: это момент перехода движка в эту фазу.

Если `moduleSessionId` ещё не пришёл (ответ на `activity:start` не вернулся), сэмпл сохраняется в `_pendingInstruction`. Как только канал получает `moduleSessionId`, `BreathModuleStateChannel` сбрасывает pending-сэмпл через `_flushPending`.

Когда сессия на паузе, сервер блокирует входящие сэмплы `breath_phase`. Lifecycle-события (`paused`, `resumed`) сервер пишет самостоятельно — они проходят всегда. За маркером `paused` возникает чистый пробел в сэмплах, `resumed` его закрывает.

## Буферизация и обратное давление

`BreathModuleInstructionStream` не отправляет сэмплы напрямую — между ним и gRPC-каналом стоит `InstructionBuffer`, кольцевой буфер на 500 сэмплов. При обрыве сэмплы накапливаются; после восстановления буфер сбрасывается. При переполнении новые сэмплы вытесняют старые, `dropped_count` фиксирует потери.

Сервер управляет частотой через `max_samples_per_second` в подтверждении — клиент обязан его соблюдать.

## Подключение и переподключение

`GrpcConnectionManager` управляет жизненным циклом gRPC-канала. Подписан на `UserNotifier`: при аутентификации соединение устанавливается, при логауте — разрывается. Параллельно слушает состояние сети и автоматически переподключается при восстановлении интернета.

Сервер держит grace period (по умолчанию 30 секунд) после обрыва. При переподключении в этом окне сервер отвечает `session:state { status: resumed }` с тем же `moduleSessionId` — `ModuleStateChannel` продолжает работу без разрыва. Если grace period истёк, сессия закрывается как `abandoned` и при следующем `activity:start` создаётся новая.

## Связь с биометрическими данными

Инструкции — это инструкционный лог, а не самостоятельные биометрические данные. Две шкалы хранятся раздельно:

```
Шкала инструкций
──────────────────────────────────────────
session_started → breath_phase → … → paused → resumed → … → session_ended

Биометрическая шкала (будущее)
──────────────────────────────
HR → HR → SpO2 → respiration → …
```

Обе шкалы привязаны к одному `moduleSessionId`. Аналитика выполняет time-join по `moduleSessionId + timestamp`:

```
T+6000ms: инструкция — exhale 6s
T+6000–T+12000ms: биосигнал дыхания → совпадает ли реальный паттерн?
```

Биометрические потоки пойдут через отдельный gRPC-сервис и отдельную таблицу, но привязываться к той же `ModuleSession` по `moduleSessionId`.
