# NFB-калибровка: история и синхронизация

Каждый прогон калибровки — успешный или нет — записывается в историю, привязанную к серийному номеру устройства, и синхронизируется на сервер. Калибровка выполняется пользователем вручную при каждом подключении: аппаратные данные от нейроинтерфейса зависят от текущего состояния (усталость, время суток, качество контакта), поэтому каждая сессия требует свежего замера.

## Модель данных

`NfbCalibrationData` — immutable value object:

| Поле | Тип | Описание |
|------|-----|----------|
| `calibratedAt` | `DateTime` | Момент завершения калибровки |
| `isValid` | `bool` | `true` если калибровка прошла успешно |
| `failReason` | `String` | `"none"` / `"tooManyArtifacts"` / `"peakFrequencyAtBorder"` |
| `individualFrequency` | `double` | Персональная пиковая частота альфа-ритма |
| `individualPeakFrequency` | `double` | Уточнённое значение пиковой частоты (отдельно от bandwidth) |
| `individualPeakFrequencyPower` | `double` | Мощность на пиковой частоте |
| `individualPeakFrequencySuppression` | `double` | Подавление на пиковой частоте |
| `individualBandwidth` | `double` | Ширина индивидуальной полосы |
| `individualNormalizedPower` | `double` | Нормализованная мощность |
| `lowerFrequency` | `double` | Нижняя граница полосы |
| `upperFrequency` | `double` | Верхняя граница полосы |

`individualPeakFrequency` хранится с backward-compatible `fromJson` (fallback на `individualFrequency` если ключ отсутствует).

## Локальный кэш

`NfbCalibrationRepository` хранит историю в SharedPreferences. Ключ: `bci_nfb_cal_history_<serial>`. Значение: JSON-массив `NfbCalibrationData.toJson()`.

**Правила кэша:**
- Новая запись prepend-ится в начало списка (новые — первые)
- Максимум 20 записей на серийник; при превышении самые старые отбрасываются
- `latestValid(serial)` — синхронный запрос из памяти, возвращает первую запись с `isValid == true`; доступен для аналитики и будущих опциональных сценариев, при подключении не вызывается
- Запись в SharedPreferences всегда awaited перед возвратом из `record()`

## Сохранение результата

По завершении калибровки `BciDeviceManager._subscribeCalibration` перехватывает `BciCalibrationCompleted(data: final data)` и вызывает `_nfbCalibrationRepository.record(_connectedSerial!, data)`. Неудачные калибровки (`isValid == false`) тоже записываются — для диагностики и аналитики.

## Серверная синхронизация

`NfbCalibrationGrpcApi` оборачивает `NfbCalibrationServiceClient` с двумя методами:

- `record(serial, data)` — идемпотентная запись на сервер; вызывается fire-and-forget после локальной записи; ошибки логируются, не бросаются
- `list(serial, {limit: 50})` — загрузка истории с сервера

`refreshFromServer(serial)` — полная перезапись локального кэша данными с сервера (сервер — источник истины для истории). Вызывается lazy при открытии BCI-экрана через `BciDeviceManager.startScan()` — по одному вызову на каждый известный серийник из кэша.

## Граница

```
App.initialize()
  └─ NfbCalibrationRepository(prefs:, api:)   ← создаётся один раз
        ↓ передаётся в
BciDeviceManager
  └─ record() при каждом BciCalibrationCompleted

NfbCalibrationRepository
  ├─ SharedPreferences (синхронный read, async write)
  └─ NfbCalibrationGrpcApi (fire-and-forget sync)
```
