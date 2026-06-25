# Трекинг медитационных сессий

`MeditationModuleStateChannel` адаптирует жизненный цикл медитации под общую gRPC-инфраструктуру (`ModuleStateChannel`). Контракт идентичен дыхательному трекингу — `activity:start` / `activity:end` — но адаптер намеренно проще: нет инструкций фаз, нет паузы/возобновления, нет автоматического приостановки в фоне.

## Жизненный цикл

```
idle ──(active)──▶ active ──(idle)──▶ idle
```

Переход `idle → active` (нажатие Start) вызывает `channel.start(type: ActivityType.meditation, refId: poseUuid, clientTimestampMs: DateTime.now().millisecondsSinceEpoch)`. Переход `active → idle` (нажатие Stop) вызывает `channel.end(clientTimestampMs: DateTime.now().millisecondsSinceEpoch)`. Флаги `_started` и `_ended` гарантируют единственный вызов каждой команды за жизнь объекта. После каждого `active → idle` канал ре-армируется — следующее нажатие Start создаёт новую активность.

Если сервер прислал событие `ABANDONED` (grace-период истёк), `MeditationModuleStateChannel` ре-армируется автоматически: сбрасывает `_started`, `_ended`, `_moduleSessionId` и `_previousStatus` без уничтожения объекта. Глобальный снекбар отображается через `GlobalListeners` — это общая реакция уровня приложения, не специфичная для медитации.

`refId` — UUID позы из серверного каталога `meditation_poses`, не slug. `MeditationModule.buildSession()` разрешает slug в UUID через `App.shared.meditationPoseUuids` перед передачей в канал. UUID кэш заполняется при открытии списка поз через `MeditationListService.refresh()`.

`moduleSessionId` приходит от сервера в ответе `session:state`. Канал подписывается на `channel.state` и сохраняет `moduleSessionId` — координатор читает его после `active → idle`, чтобы передать в `MeditationNoteService` при сохранении заметки.

## Сессионный таймер

`MeditationSessionViewModel` держит `ValueNotifier<int> elapsedSeconds`. Таймер стартует при `start()`, сбрасывается при каждом `start()`, останавливается при `stop()`. Экран отображает прошедшее время в формате `HH:MM:SS` цветом `AppColors.warmAccentDark` (золото) с табличными цифрами (`FontFeature.tabularFigures`) — без перестройки Riverpod-стейта на каждую секунду (`ValueListenableBuilder`, не `ref.watch`).

## Заметка после сессии

По завершении сессии (`active → idle`) координатор открывает `MeditationNoteScreen`. Экран предлагает мультистрочное поле для свободного текста. Нажатие «OK» сохраняет заметку; «Отмена» или пустой текст — нет.

Заметка сохраняется локально в таблицу `meditation_notes` (Drift) и синхронизируется на сервер через `MeditationNotesServiceClient`:

| Поле | Описание |
|------|----------|
| `id` | UUID, генерируется на клиенте |
| `poseId` | UUID позы (`meditation_poses.id`) — не slug |
| `noteText` | Свободный текст |
| `createdAt` | Unix ms |
| `serverSessionId` | `moduleSessionId` текущей сессии (nullable) |

Серверный `createNote` — идемпотентный; `ALREADY_EXISTS` не считается ошибкой.

## Чего нет по сравнению с BreathModuleStateChannel

| Возможность | Breath | Meditation |
|-------------|--------|-----------|
| Инструкции фаз (breath_phase) | ✅ | ❌ |
| `activity:pause` / `activity:resume` | ✅ | ❌ |
| Автопауза при уходе в фон | ✅ | ❌ — запись биометрики продолжается в фоне намеренно |
| Ожидание `moduleSessionId` для flush инструкций | ✅ | ❌ |
| `clientTimestampMs` в `start` / `end` | ✅ | ✅ |
| Сброс при `ABANDONED` | ✅ | ✅ |

Биометрический pipeline гейтируется теми же событиями `ModuleStateChannel` — дополнительной настройки не требуется.

## Реализация

```
MeditationSessionScreen
  └─ MeditationSessionViewModel.stream (idle / active)
        ↓ подписка в конструкторе
MeditationModuleStateChannel
  ├─ channel.start(type: meditation, refId: poseUuid, clientTimestampMs: now)  ← при idle → active
  ├─ channel.end(clientTimestampMs: now)                                        ← при active → idle (+ ре-арм)
  ├─ _moduleSessionId ← из channel.state subscription
  └─ reset() при ModuleSessionAbandoned ← из channel.events subscription

MeditationModule.buildSession()
  ├─ создаёт канал, подписывает на vm.stream
  ├─ передаёт getSessionId: () => channel.moduleSessionId в координатор
  └─ onDispose → channel.dispose()

MeditationSessionCoordinator.onSessionStopped()
  ├─ открывает MeditationNoteScreen
  └─ при non-empty text → MeditationNoteService.saveNote(text, sessionId: moduleSessionId)
```

`dispose()` вызывает `channel.stop()` если сессия начата, но не завершена.

## Связь с биометрическим конвейером

Подробности о гейтинге по `moduleSessionId` и соотношении с биосигналами — в [docs/biometrics/stream-pipeline.md](../biometrics/stream-pipeline.md) и [docs/realtime/live-session-tracking.md](live-session-tracking.md).
