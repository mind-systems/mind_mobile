# Синхронизация данных

Приложение синхронизирует данные с сервером через два gRPC-пути: унарный вызов на старте (cold start) и серверный стриминг для получения изменений в реальном времени. Оба пути сходятся в `SyncEngine`, который поддерживает локальный кэш Drift в согласованном состоянии с сервером.

## Общая схема

```
SyncApi (gRPC unary)              SyncGrpcListener (gRPC server-streaming)
  SyncService/GetChanges            SyncService/WatchChanges
         │                                 │
         │                          maps SyncEventDto → ChangeEvent
         │                                 │
         ▼                                 ▼
       ┌─────────────────────────────────────┐
       │            SyncEngine               │
       │  fetchChanges → group → batch → DB  │
       └─────────────────────────────────────┘
                       │
                       ▼
           BreathSessionNotifier.invalidate()
```

## SyncEngine

`SyncEngine` — чистый Dart-класс без Flutter-зависимостей. У него две точки входа.

`sync()` запускается при cold start или логине. Он обращается к `syncApi.fetchChanges(lastEventId)`, который оборачивает унарный вызов `SyncService/GetChanges`. Если сервер вернул флаг `fullResync`, движок переходит в режим полного сброса (см. ниже). Иначе — события уходят в общий пайплайн обработки.

`processEvents(events)` вызывается из `SyncGrpcListener`. Перед обработкой он проверяет, не выполняется ли в данный момент `sync()`: если да — ждёт его завершения, чтобы записи не пересеклись в Drift. Это поведение контролируется полем `_activeSyncOp`.

Общий пайплайн работает одинаково для обоих путей:

1. **Сортировка и группировка** — события сортируются по `id` и группируются по типу сущности (`entity`).
2. **Разделение на upserts и deletes** — если одна и та же сущность фигурирует в обоих списках, побеждает удаление.
3. **Batch-рефетч** — upserts загружаются пачками по 50 через `SyncApi.fetchSessionsBatch()`, который вызывает `BreathSessionService/BatchGetSessions`.
4. **Запись в Drift** — загруженные записи upsert'ятся, удалённые — удаляются.
5. **Курсор** — `lastEventId` обновляется до максимального `id` среди обработанных событий (только если он больше текущего).
6. **Инвалидация** — `breathSessionNotifier.invalidate()` перечитывает Drift и немедленно публикует обновлённое состояние в потоке нотифаера.

## Cold Start Sync

При запуске приложения вызывается `syncEngine.waitForColdStart(isAuthenticated)`. Если пользователь аутентифицирован, метод запускает `sync()` с таймаутом 5 секунд — приложение стартует даже при отсутствии сети.

Помимо этого, `SyncEngine` подписывается на `authStream` в конструкторе: каждый раз, когда поток переходит в `AuthenticatedState` (то есть при логине), автоматически вызывается `sync()`. Первое событие потока пропускается через `.skip(1)` — чтобы не дублировать cold-start синк, уже запущенный при инициализации.

## Full Resync

Иногда сервер отвечает на `GetChanges` флагом `fullResync: true`. Это означает, что курсор клиента устарел и локальный кэш нужно сбросить. `SyncEngine` при этом:

1. Проверяет, что `lastEventId != 0` — если курсор равен нулю, сброс был бы бесконечным циклом, и движок просто выходит.
2. Удаляет все сессии из Drift.
3. Сбрасывает курсор до нуля.
4. Инвалидирует `breathSessionNotifier`.

Повторный рефетч не запускается автоматически — список сессий останется пустым до тех пор, пока UI не запросит `BreathSessionNotifier.refresh()`, который выполнит полный write-through синк с сервером и заново заполнит Drift.

## SyncGrpcListener

`SyncGrpcListener` — мост между gRPC-стримингом и доменным `SyncEngine`. Он принимает `SyncServiceClient`, `SyncEngine`, `ISyncStateDao` и `Stream<AuthState>` и подписывается на поток аутентификации в конструкторе. При переходе в `AuthenticatedState` запускается `_startWatching()`, при `GuestState` — `_stopWatching()`.

`_startWatching()` считывает `lastEventId` из DAO и открывает серверный стрим: `syncService.watchChanges(WatchChangesRequest(afterId: lastEventId))`. Сервер сначала отдаёт догоняющий пакет — все события после сохранённого курсора, — а затем продолжает стримить новые события по мере их появления. Каждое сообщение стрима — это proto-конверт `ChangeEvent`, содержащий `repeated SyncEventDto`. Листенер преобразует каждый `SyncEventDto` в доменный `ChangeEvent` (поле `createdAt` при этом отбрасывается) и передаёт список в `syncEngine.processEvents()`.

Между чтением `lastEventId` и открытием стрима существует асинхронный зазор. Чтобы закрыть окно гонки при быстром логауте, `_startWatching()` проверяет флаг `_isAuthenticated` до и после `await`.

Если стрим завершается — с ошибкой или штатно — вызывается `_scheduleReconnect()`. Он ставит таймер на 3 секунды и снова вызывает `_startWatching()`, если пользователь всё ещё аутентифицирован. `_stopWatching()` отменяет как активную подписку на стрим, так и любой ожидающий таймер переподключения.

## Модели данных

**ChangeEvent** — доменная единица синхронизации. Содержит монотонно растущий `id` события, строковый тип сущности `entity` (например, `breath_session`), UUID сущности `refId` и строковое действие `action` (`created`, `updated`, `deleted`). Модель маппится из proto-типа `SyncEventDto`, который дополнительно несёт поле `createdAt` — оно не используется в доменном слое и отбрасывается при конвертации.

На стороне стриминга сервер может коалесцировать несколько быстро следующих друг за другом изменений в один proto-конверт `ChangeEvent` с полем `repeated SyncEventDto`. Листенер разворачивает конверт в список доменных событий перед передачей в движок.

**Курсор** хранится в таблице `SyncState` в Drift (singleton-запись). `ISyncStateDao` предоставляет три операции: прочитать курсор (возвращает 0 при отсутствии записи), обновить его (upsert) и сбросить (удаление строки для full resync).

## Оптимизация запросов

| Сценарий | gRPC-вызовы | Детали |
|----------|-------------|--------|
| Реальное время (стриминг) | 1 | Только batch-рефетч (unary) |
| Cold start | 2 | `GetChanges` (unary) + batch-рефетч (unary) |
| Нет изменений | 1 (cold start) / 0 (стриминг) | Пустой список событий — рефетч не запускается |

## Wiring в App.dart

```
SyncApi(grpcClient.syncService, grpcClient.breathSessionService)
  → BreathSessionNotifier.loadLocal()   ← seeds UI from Drift before any network call
  → SyncEngine(syncApi, syncStateDao, breathSessionDao, breathSessionNotifier, authStream: userNotifier.stream)
    → waitForColdStart (блокирует до 5 сек, если аутентифицирован)
  → SyncGrpcListener(syncService, syncEngine, syncStateDao, authStream: userNotifier.stream)
```

`BreathSessionNotifier.loadLocal()` вызывается до запуска `SyncEngine`, поэтому список сессий заполняется из локального Drift-кэша немедленно — пользователь видит данные ещё до завершения сетевого синка. `SyncGrpcListener` создаётся после завершения cold-start, поэтому стриминговая подписка открывается только тогда, когда начальный курсор уже установлен. Оба объекта живут всё время жизни приложения — явный dispose не требуется.
