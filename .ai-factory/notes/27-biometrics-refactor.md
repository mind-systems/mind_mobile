# Biometrics Refactor — `CardioData` + Capability Mixins

**Date:** 2026-05-24
**Used by:** ROADMAP Phase 21 milestones 1–3
**Architecture contract:** [26-biometric-stream-architecture.md](26-biometric-stream-architecture.md)

This note specs three sequential atomic milestones. Each one compiles and ships independently. Together they prepare the data layer for the upload pipeline (note 28).

---

## Milestone 1 — `CardioData` + `RrInterval` value objects

Four new files under `lib/Biometrics/Models/`. Pure additive — no existing code touched.

### `lib/Biometrics/Models/SensorSource.dart`

```dart
enum SensorSource { neiry, garmin, polar, appleHealth }
```

Only `neiry` is used today. Other values exist so consumers can pattern-match exhaustively without future churn.

### `lib/Biometrics/Models/CardioHrvIndices.dart`

```dart
final class CardioHrvIndices {
  final double? rmssd;
  final double? sdnn;
  final double? pnn50;
  final double? lf;
  final double? hf;
  final double? lfhf;

  const CardioHrvIndices({
    this.rmssd,
    this.sdnn,
    this.pnn50,
    this.lf,
    this.hf,
    this.lfhf,
  });
}
```

All nullable — sources fill what they can.

### `lib/Biometrics/Models/CardioData.dart`

```dart
import 'CardioHrvIndices.dart';
import 'SensorSource.dart';

final class CardioData {
  final double heartRate;
  final bool metricsAvailable;
  final bool hasArtifacts;
  final SensorSource source;
  final CardioHrvIndices? hrv;

  const CardioData({
    required this.heartRate,
    required this.metricsAvailable,
    required this.hasArtifacts,
    required this.source,
    this.hrv,
  });
}
```

`source` is **required** — every cardio sample must identify its hardware.

### `lib/Biometrics/Models/RrInterval.dart`

```dart
import 'SensorSource.dart';

final class RrInterval {
  final int intervalMs;
  final DateTime timestamp;
  final bool isArtifact;
  final SensorSource source;

  const RrInterval({
    required this.intervalMs,
    required this.timestamp,
    required this.isArtifact,
    required this.source,
  });
}
```

RR-интервал — длительность одного сердечного удара (от пика к пику в PPG). Это сырьё, из которого ретроспективно восстанавливается **любая** HRV-метрика (RMSSD, SDNN, pNN50, LF/HF, Baevsky) одним и тем же серверным алгоритмом для всех источников. Готовые индексы от прошивки (например, Neiry's Kaplan / stress) не сравнимы между вендорами — отказываемся в пользу единого расчёта на сервере из RR.

`timestamp` — момент удара, **завершившего** интервал (приходит от SDK, не `DateTime.now()`). Сохраняем как `DateTime` — на уровне `BioSample` конвертируем в `millisecondsSinceEpoch`.

`isArtifact` — флаг от SDK (физиологическая проверка + медианная фильтрация). Сохраняем **все** интервалы, в том числе артефакты; решение, использовать ли — за сервером.

### `lib/Biometrics/Models/MotionData.dart`

```dart
import 'SensorSource.dart';

final class MotionData {
  final ({double x, double y, double z}) accelerometer;
  final ({double x, double y, double z}) gyroscope;
  final DateTime timestamp;
  final SensorSource source;

  const MotionData({
    required this.accelerometer,
    required this.gyroscope,
    required this.timestamp,
    required this.source,
  });
}
```

`accelerometer` и `gyroscope` — Dart records, зеркалят форму SDK-овского `MemsSample` (тройки x/y/z). Сохраняем единицы устройства как есть — единая нормировка происходит серверной аналитикой, чтобы данные с шлема и часов сравнивались на одной шкале.

`timestamp` — приходит **от SDK per-sample** (нативный слой стампит каждый сэмпл на источнике), не `DateTime.now()`. Это критично: MEMSClassifier батчит сэмплы пакетами для удешевления platform-channel вызовов, и без SDK-timestamp'ов мы бы потеряли реальную шкалу движения внутри батча. Сохраняем как `DateTime` — конверсия в `millisecondsSinceEpoch` происходит на уровне `BioSample`.

`source` — тот же `SensorSource`, что у `CardioData` и `RrInterval`. Сегодня единственный поставщик — `SensorSource.neiry` (шлем). Будущие источники (часы, кольцо) добавятся как новые значения enum.

`BciCardioData` стоит нетронутым. Миграция — следующий milestone.

---

## Milestone 2 — Migrate `BciCardioData` → `CardioData`

Single rename concern, all in one milestone (split would leave broken intermediate states).

### Files to change

1. **`lib/Bci/Models/BciCardioData.dart`** — delete.

2. **`lib/Bci/Models/BciNotifierEvent.dart`** — `BciCardioUpdated(BciCardioData data)` becomes `BciCardioUpdated(CardioData data)`. Update the import.

3. **`lib/Bci/IBciDeviceProvider.dart`** — `Stream<BciCardioData> get cardioStream` becomes `Stream<CardioData> get cardioStream`. Update the import. (The capability split that removes this getter is the next milestone — keep it here for now.)

4. **`lib/Bci/BciDeviceManager.dart`** — `Stream<BciCardioData> get cardioStream` becomes `Stream<CardioData>`. Update the import.

5. **`lib/Bci/NeiryBciProvider.dart`** — three changes:
   - `StreamController<BciCardioData>` field becomes `StreamController<CardioData>`.
   - The cardio stream getter return type changes accordingly.
   - `_onCardioState(CardioData c)` body — construct the new `CardioData` with tags:
     ```dart
     _cardioController.add(CardioData(
       heartRate: c.heartRate,
       metricsAvailable: c.metricsAvailable,
       hasArtifacts: c.hasArtifacts,
       source: SensorSource.neiry,
       hrv: null,
     ));
     ```
   - Note: `CardioData` is now an ambiguous name — both `neiry_kit`'s `CardioData` and our new `lib/Biometrics/Models/CardioData.dart` exist. Resolve by import alias: `import 'package:neiry_kit/neiry_kit.dart' as neiry;` and refer to the SDK type as `neiry.CardioData` inside `_onCardioState`. Our type is the unqualified `CardioData`.

6. **`lib/Bci/BciNotifier.dart`** — no source change. Subscriptions are typed `StreamSubscription<dynamic>`; payload type widening flows transparently.

7. **`lib/BciModule/BciDataService.dart`** — import path only changes (the pattern-match payload type is inferred). Existing reducer body reads `data.heartRate`, `data.metricsAvailable`, `data.hasArtifacts` — all three fields exist on `CardioData` with the same shapes. No behavior change.

### Guard

The `neiry_kit` SDK exports `CardioData` too. Wherever a file uses both — currently only `NeiryBciProvider.dart` — use a prefix alias on the `neiry_kit` import to disambiguate. Do not rename our `CardioData`.

---

## Milestone 3 — Extract capability mixins + clean `IBciDeviceProvider`

Splits "device-class" concerns (scan/connect/calibration/impedance/battery/connectionState) from per-stream "capabilities" (HR, RR, EEG bands, emotions). Forward-compatible with non-Neiry sources.

### New interfaces in `lib/Biometrics/`

**`lib/Biometrics/IHeartRateSource.dart`:**
```dart
import 'Models/CardioData.dart';

abstract interface class IHeartRateSource {
  Stream<CardioData> get cardioStream;
}
```

**`lib/Biometrics/IRrIntervalSource.dart`:**
```dart
import 'Models/RrInterval.dart';

abstract interface class IRrIntervalSource {
  Stream<RrInterval> get rrStream;
}
```

Кept separate from `IHeartRateSource` because some HR sources (e.g. Apple Health aggregated data, summary-only watches) never expose RR. A source can implement one without the other.

**`lib/Biometrics/IEegBandsSource.dart`:**
```dart
import 'package:mind/Bci/Models/BciNfbData.dart';

abstract interface class IEegBandsSource {
  Stream<BciNfbData> get nfbStream;
}
```

**`lib/Biometrics/IEmotionsSource.dart`:**
```dart
import 'package:mind/Bci/Models/BciEmotionsData.dart';

abstract interface class IEmotionsSource {
  Stream<BciEmotionsData> get emotionsStream;
}
```

**`lib/Biometrics/IMotionSource.dart`:**
```dart
import 'Models/MotionData.dart';

abstract interface class IMotionSource {
  Stream<MotionData> get motionStream;
}
```

Один сэмпл на эмиссию — провайдер сам разворачивает SDK-батч `List<MemsSample>` в отдельные `MotionData`-эмиссии (см. `NeiryBciProvider` ниже).

`BciNfbData` and `BciEmotionsData` keep their `Bci` prefix and stay under `lib/Bci/Models/` — they are EEG-classifier outputs by definition.

### `lib/Bci/IBciDeviceProvider.dart`

Remove three getters: `cardioStream`, `nfbStream`, `emotionsStream`. Remove their imports (`BciCardioData` is already gone after milestone 2; remove `BciNfbData` and `BciEmotionsData` imports too). Interface now exposes only device-class concerns: `scan`, `connect`, `disconnect`, `connectionStateStream`, `signalQualityStream`, `batteryStream`, `calibrationStream`, `startCalibration`, `dispose`.

### `lib/Bci/NeiryBciProvider.dart`

Class declaration gains all five capability interfaces:

```dart
class NeiryBciProvider
    implements IBciDeviceProvider,
        IHeartRateSource,
        IRrIntervalSource,
        IEegBandsSource,
        IEmotionsSource,
        IMotionSource {
```

Three of the five getter bodies (`cardioStream`, `nfbStream`, `emotionsStream`) are already present from Phase 19 and satisfy the new interfaces — no logic change there.

**RR-интервал — новая подписка** (этого ещё нет в коде):

1. Add a new broadcast controller field next to the others:
   ```dart
   final _rrController = StreamController<RrInterval>.broadcast();
   ```
2. Add a subscription field next to the other `_cardioSub` / `_nfbSub`:
   ```dart
   StreamSubscription<neiry.RRInterval>? _rrSub;
   ```
   (uses the same `neiry` import alias adopted in Milestone 2)
3. Add the getter:
   ```dart
   @override
   Stream<RrInterval> get rrStream => _rrController.stream;
   ```
4. In `_subscribeDeviceStreams()`, after the existing `_cardioSub` block:
   ```dart
   _rrSub = _cardioClassifier!.rrStream.listen(
     _onRrInterval,
     onError: (Object e) =>
         logPrint('NeiryBciProvider: rrStream error: $e'),
   );
   ```
5. Add the handler:
   ```dart
   void _onRrInterval(neiry.RRInterval rr) {
     _rrController.add(RrInterval(
       intervalMs: rr.intervalMs,
       timestamp: rr.timestamp,
       isArtifact: rr.isArtifact,
       source: SensorSource.neiry,
     ));
   }
   ```
   Артефакты тоже передаём (`isArtifact: rr.isArtifact`) — фильтрация это решение сервера.
6. In `_cancelDeviceSubscriptions()`, cancel and null `_rrSub` alongside `_cardioSub`.
7. In `_doDispose()`, close `_rrController` alongside the other controllers.

**MEMS (motion) — ещё одна новая подписка**:

1. Add a broadcast controller field:
   ```dart
   final _motionController = StreamController<MotionData>.broadcast();
   ```
2. Add a classifier field — MEMS, в отличие от других классификаторов, **требует явного `dispose()`** на стороне SDK, поэтому держим ссылку:
   ```dart
   MEMSClassifier? _memsClassifier;
   StreamSubscription<List<neiry.MemsSample>>? _memsSub;
   ```
3. Add the getter:
   ```dart
   @override
   Stream<MotionData> get motionStream => _motionController.stream;
   ```
4. In `_subscribeDeviceStreams()`, after the existing classifier-construction block:
   ```dart
   _memsClassifier = MEMSClassifier(_device!);
   _memsSub = _memsClassifier!.memsStream.listen(
     _onMemsBatch,
     onError: (Object e) =>
         logPrint('NeiryBciProvider: memsStream error: $e'),
   );
   ```
5. Add the handler — **разворачивает пакет в per-sample эмиссии**, сохраняя SDK-овский timestamp каждого сэмпла:
   ```dart
   void _onMemsBatch(List<neiry.MemsSample> batch) {
     for (final s in batch) {
       _motionController.add(MotionData(
         accelerometer: s.accelerometer,
         gyroscope: s.gyroscope,
         timestamp: s.timestamp,
         source: SensorSource.neiry,
       ));
     }
   }
   ```
   Артефакт-флага у `MemsSample` нет — SDK заявляет «все поля всегда заполнены, sentinel-значений нет».
6. In `_cancelDeviceSubscriptions()`, cancel and null `_memsSub`; **дополнительно** вызвать `await _memsClassifier?.dispose()` и обнулить `_memsClassifier` — иначе native-side держит ресурсы до перезапуска приложения.
7. In `_doDispose()`, close `_motionController` alongside the other controllers.

Add the five new imports to the import block (`IHeartRateSource`, `IRrIntervalSource`, `IEegBandsSource`, `IEmotionsSource`, `IMotionSource`, plus `Models/RrInterval.dart` and `Models/MotionData.dart`). `MEMSClassifier` приходит через тот же `package:neiry_kit/neiry_kit.dart` как остальные нативные типы (с `neiry` alias).

### `lib/Bci/BciDeviceManager.dart`

Constructor signature gains three required parameters:

```dart
BciDeviceManager({
  required IBciDeviceProvider provider,
  required IHeartRateSource cardioSource,
  required IEegBandsSource eegBandsSource,
  required IEmotionsSource emotionsSource,
  required BciDeviceRepository repository,
}) : _provider = provider,
     _cardioSource = cardioSource,
     _eegBandsSource = eegBandsSource,
     _emotionsSource = emotionsSource,
     _repository = repository {
  _subscribeProviderStreams();
}
```

Add the three fields. Update the existing three getters:

```dart
Stream<CardioData> get cardioStream => _cardioSource.cardioStream;
Stream<BciNfbData> get nfbStream => _eegBandsSource.nfbStream;
Stream<BciEmotionsData> get emotionsStream => _emotionsSource.emotionsStream;
```

Update imports — drop `BciCardioData` (already gone); add `CardioData`, `IHeartRateSource`, `IEegBandsSource`, `IEmotionsSource`.

**Why `IRrIntervalSource` and `IMotionSource` are NOT routed through `BciDeviceManager`.** The three "UI-facing" capabilities (HR / EEG bands / emotions) flow through the manager because Phase 19 `BciDataScreen` needs them — HR for the heart-rate indicator, NFB bands and emotions for the bar charts. RR and MEMS are **only** consumed by `BioStreamRouter` (server-side analytics fodder); no UI surface displays per-beat intervals or per-sample motion. Skipping the manager + `BciNotifier` for both keeps the existing UI plumbing unchanged and avoids polluting the `BciNotifierEvent` sealed union with events no screen handles. `BioStreamRouter` will register the `NeiryBciProvider` directly as `IRrIntervalSource` and `IMotionSource` in Phase 21 Milestone 9. When a future "stillness" / "movement" UI lands, the right answer is a separate `ActiveMotionSource` aggregator (symmetric with `ActiveRrSource` planned for the breath tick) — not retrofitting motion into the manager.

### `lib/Core/App.dart`

In `initialize()`, the existing line `final bciProvider = NeiryBciProvider();` stays. Update the `BciDeviceManager` construction:

```dart
final bciDeviceManager = BciDeviceManager(
  provider: bciProvider,
  cardioSource: bciProvider,
  eegBandsSource: bciProvider,
  emotionsSource: bciProvider,
  repository: bciRepository,
);
```

Same instance, four interface roles. No new fields on `App` — the provider is already a local in `initialize()` and only `bciNotifier` is exposed as a field today.

### Why this milestone is atomic

Removing the three getters from `IBciDeviceProvider` immediately breaks `BciDeviceManager`'s `_provider.cardioStream` references unless the manager constructor change ships at the same time. Splitting "add interfaces" from "remove from base + wire manager" would leave the codebase in a non-compiling intermediate state — so they ship together.
