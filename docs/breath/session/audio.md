# Звук дыхательной сессии

`BreathSoundCoordinator` — единственный объект, управляющий звуком в дыхательной сессии. Он подписывается на `BreathViewModel.stream` (сырой поток, каждый тик) и принимает два примитива из пакета `mind_audio`: `AudioLooper` для непрерывных петель и `AudioOneShot` для одиночных тиков.

## Пакет mind_audio

`packages/mind_audio` — отдельный Flutter-пакет без доменных зависимостей. Предоставляет три примитива:

| Класс | Назначение |
|-------|-----------|
| `AudioLooper` | Ping-pong пара `AudioPlayer`-ов для бесшовного кроссфейда между петлями |
| `AudioOneShot` | Одиночный буферизованный звук: загружается один раз, воспроизводится через seek+play |
| `AudioCatalog` / `AssetAudioCatalog` | Строит `AudioSource` из пути к ассету |

`AudioTrack` — value object с путём к ассету. `BreathSoundCoordinator` конструируется в `BreathModule.buildSession()` и получает `AudioLooper` и `AudioOneShot` снаружи — никаких аудио-зависимостей в самом координаторе.

## Петли фаз дыхания

Для каждой фазы — отдельный FLAC-файл:

```
assets/audio/ohm_inhale.flac
assets/audio/ohm_exhale.flac
assets/audio/ohm_hold.flac
```

### Почему FLAC, а не OGG/Opus

Lossy-кодеки (OGG/Vorbis, Opus) добавляют в начало потока ~1024 priming-сэмпла — **encoder delay**. Этот артефакт смещает точку зацикливания от исходного сэмпла: `just_audio` при `LoopMode.one` переходит к началу файла, где стоят эти лишние сэмплы, и на каждой границе петли слышен щелчок — фазовый разрыв.

FLAC — lossless: после декодирования сэмплы побитово идентичны исходнику. Encoder delay отсутствует, `LoopMode.one` возвращается ровно к тому сэмплу, которым начинается файл — петля бесшовна. Одиночные тик-звуки (`tick_clock.ogg`, `tick_heartbeat.ogg`) остаются в OGG — они воспроизводятся один раз, и encoder delay на них не влияет.

## Кроссфейд

Два `AudioPlayer`-а внутри `AudioLooper` работают в ping-pong. Последовательность при смене фазы:

1. Fade out `_activeLoop` запускается **немедленно** при получении события — до `seek()` нового плеера, чтобы перекрыть его латентность
2. `_inactiveLoop.seek(index)` + `unawaited(_inactiveLoop.play())`
3. Fade in `_inactiveLoop` запускается параллельно
4. Swap: `_activeLoop ↔ _inactiveLoop`

Оба плеера инициализируются единым `Future.wait([playerA.setAudioSources(...), playerB.setAudioSources(...)])` в `initialize()`. Это гарантирует, что при первом фейде оба плеера уже готовы.

**Gen-guard.** `_switchToPhase` — async и вызывается fire-and-forget. Параллельный вызов может наступить на тот же `_inactiveLoop` пока он ещё в `seek()`. Каждый вызов получает номер поколения; если при продолжении обнаруживается более свежее поколение — вызов выходит без swap и без fade.

### Длительность кроссфейда

Адаптируется к длине входящей фазы по степенной кривой:

```
fadeDurationMs = clamp(k × nextPhaseMs^0.65, minFadeMs, maxFadeMs)
```

Константы: `k = 3.83`, `minFadeMs = 150`, `maxFadeMs = 1500`.  
Ориентиры: 1 с → ≈341 мс, 2 с → ≈536 мс, 4 с → ≈843 мс, 8 с → ≈1320 мс, ~10.5 с+ → 1500 мс (кап).

## Тик-звуки

На каждый тик в разрешённых статусах воспроизводится одиночный звук через `AudioOneShot`. Тип зависит от `BreathSessionState.tickSource`:

```
TickSource.timer     → assets/audio/tick_clock.ogg
TickSource.heartbeat → assets/audio/tick_heartbeat.ogg
```

Ассет буферизуется один раз при `initialize()` через `setAudioSource()` — каждый тик только `seek(Duration.zero)` + `play()`. Тик воспроизводится при статусах `pause`, `rest`, и `breath + BreathPhase.rest`.

Смена `tickSource` в середине сессии подхватывается координатором: он перегружает ассет через `_loadTickAsset()` fire-and-forget, чтобы следующий тик уже использовал новый звук.

## Фоновый режим

`_BreathSessionScreenState` не реализует `WidgetsBindingObserver` и не реагирует на события жизненного цикла приложения. Дыхательный цикл продолжает работать при переходе в фон: на iOS аудио-сессия удерживает процесс активным, на Android работает foreground service. Пауза возможна только по явному действию пользователя.

## Граница владения

```
BreathModule.buildSession()
  ├─ AudioLooper()    ┐
  ├─ AudioOneShot()   ├─ создаются здесь, передаются снаружи
  └─ BreathSoundCoordinator(looper:, oneShot:)

BreathSoundCoordinator
  ├─ подписан на BreathViewModel.stream (сырой поток, каждый тик)
  └─ подписан на tickService.tickStream (через ViewModel)
```
