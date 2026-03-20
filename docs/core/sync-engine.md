[← Module System](module-system.md) · [Back to README](../../README.md) · [Testing →](testing.md)

# Синхронизация данных

Приложение синхронизирует данные с сервером через два канала: REST-поллинг при запуске (cold start) и WebSocket-события в реальном времени. Оба канала проходят через единый пайплайн `SyncEngine`, который гарантирует консистентность локального кэша Drift с серверным состоянием.

## Общая схема

```
SyncApi (REST)                    LiveSocketService (Socket.IO)
  GET /sync/changes                  sync:changed event
  GET /breath_sessions/batch              │
        │                                 ▼
        │                        SyncSocketListener
        │                          (десериализация)
        │                                 │
        ▼                                 ▼
      ┌─────────────────────────────────────┐
      │            SyncEngine               │
      │  fetchChanges → group → batch → DB  │
      └─────────────────────────────────────┘
                      │
                      ▼
          BreathSessionNotifier.invalidate()
          (ViewModels перечитывают из Drift)
```

## SyncEngine

`SyncEngine` — чистый Dart-класс без Flutter-зависимостей. Две точки входа:

| Метод | Когда вызывается | REST-запросы |
|-------|-------------------|-------------|
| `sync()` | Cold start, логин | `/sync/changes` + `/batch` |
| `processEvents(events)` | Socket-событие | только `/batch` |

Оба пути сходятся в общую `_processEvents()` логику:

1. **Группировка** — события сортируются по `entity` типу (например, `breath_session`)
2. **Разделение** — для каждого типа выделяются upserts (`created`/`updated`) и deletes (`deleted`). Если элемент есть в обоих списках — побеждает удаление
3. **Batch-рефетч** — upserts загружаются пакетом: `GET /breath_sessions/batch?ids=id1,id2,id3`
4. **Применение к Drift** — загруженные записи upsert'ятся, удалённые — удаляются
5. **Курсор** — `lastEventId` обновляется до максимального `id` из обработанных событий
6. **Инвалидация** — `breathSessionNotifier.invalidate()` сбрасывает in-memory кэш, ViewModels перечитывают данные из Drift

Защита от параллельных синков: `_activeSyncOp` гарантирует, что одновременно выполняется только одна операция. Socket-события ждут завершения REST-поллинга.

## Cold Start Sync

При запуске приложения, если пользователь аутентифицирован:

```dart
await syncEngine.sync().timeout(const Duration(seconds: 5), onTimeout: () {});
```

- Запрашивает `lastEventId` из Drift (0, если первый запуск)
- `GET /sync/changes?after=lastEventId` — получает пропущенные события
- Применяет через общий пайплайн
- Таймаут 5 секунд — приложение запускается даже без сети

Дополнительно, при переходе в `AuthenticatedState` (логин) автоматически триггерится `syncEngine.sync()` через подписку на `userNotifier.stream`.

## Full Resync

Если сервер отвечает `fullResync: true`, SyncEngine:

1. Проверяет, что `lastEventId != 0` (защита от бесконечного цикла при первом запуске)
2. Очищает весь кэш Drift (`deleteAllSessions()`)
3. Сбрасывает `lastEventId` в 0
4. Не рефетчит повторно — обычная пагинация подгрузит данные по мере необходимости

## SyncSocketListener

Мост между WebSocket-инфраструктурой и доменным SyncEngine:

- Подписывается на `liveSocketService.syncChangedEvents`
- Слушает событие `sync:changed` с payload `{ events: [...] }`
- Десериализует `ChangeEvent` из JSON
- Вызывает `syncEngine.processEvents(events)` напрямую — без REST-запроса к `/sync/changes`

Вынесен в отдельный класс, потому что связан с Socket.IO-инфраструктурой, а SyncEngine остаётся чистым доменным кодом.

## Модели данных

**ChangeEvent** — единица синхронизации:

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | `int` | Глобальный ID события (монотонно растущий) |
| `entity` | `String` | Тип сущности (`breath_session`) |
| `refId` | `String` | ID сущности (UUID) |
| `action` | `String` | `created`, `updated`, `deleted` |

**SyncResponse** — ответ `/sync/changes`:

| Поле | Тип | Описание |
|------|-----|----------|
| `events` | `List<ChangeEvent>` | Список событий после указанного курсора |
| `fullResync` | `bool` | Клиент должен сбросить кэш и начать заново |

**BatchSessionsResponse** — ответ `/breath_sessions/batch`:

| Поле | Тип | Описание |
|------|-----|----------|
| `data` | `List<BreathSession>` | Полные объекты сессий |

## Хранение курсора

Таблица `SyncState` в Drift (singleton-паттерн):

| Столбец | Тип | Описание |
|---------|-----|----------|
| `key` | `TEXT PK` | Всегда `"lastEventId"` |
| `value` | `TEXT` | Строковое представление числа (например, `"130"`) |

`ISyncStateDao` предоставляет три метода: `getLastEventId()` (возвращает 0, если нет записи), `setLastEventId(id)` (upsert), `reset()` (удаление для full resync).

## Оптимизация запросов

| Сценарий | HTTP-запросов | Детали |
|----------|---------------|--------|
| Online (socket) | 1 | Только batch-рефетч |
| Cold start | 2 | `/sync/changes` + batch-рефетч |
| Нет изменений | 1 (cold start) / 0 (socket) | Пустой список событий — нет рефетча |

## Wiring в App.dart

```
SyncApi(httpClient)
  → SyncEngine(syncApi, syncStateDao, breathSessionDao, breathSessionNotifier)
    → cold-start sync (если не гость)
    → подписка на AuthenticatedState → sync()
  → SyncSocketListener(liveSocketService, syncEngine)
    → подписка на syncChangedEvents (в конструкторе)
```

Оба объекта живут всё время жизни приложения — explicit dispose не требуется.

## See Also

- [Live Session Tracking](../socket/live-session-tracking.md) — WebSocket-инфраструктура, на которой работает sync:changed
- [Notifier Pattern](notifier-pattern.md) — паттерн типизированных событий, используемый для инвалидации
- [Global Listeners](global-listeners.md) — координация глобальных событий, включая реакцию на логин
